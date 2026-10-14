-- ============================================================================
-- Account deletion processing, duplicate-phone signups, "I'm Safe" emails
-- (audit follow-up, Oct 2026)
--
-- Run AFTER sql/privacy_consent_onboarding_migration.sql. Idempotent.
--
--   1. Webhook secret moves into Supabase Vault (was hard-coded in the
--      notify trigger's source). Copied from the existing trigger, so it never
--      appears in this file.
--   2. Deletion requests keep an audit row after the account is gone
--      (user_id is cleared, not cascaded away) and record completed_at.
--   3. purge_user_data(): removes/detaches everything that would otherwise
--      block deleting the auth user. Called only by the
--      process-account-deletion Edge Function (service role).
--   4. handle_new_user(): a phone number that's already registered now fails
--      the sign-up clearly instead of silently creating an account with no
--      profile.
--   5. "I'm Safe" broadcasts email confirmed family (notify-im-safe Edge
--      Function), at most once per 10 minutes per sender.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Webhook secret in Vault
-- ----------------------------------------------------------------------------
do $$
declare
  existing text;
begin
  if not exists (select 1 from vault.secrets where name = 'safety_circle_webhook_secret') then
    select substring(p.prosrc from 'x-webhook-secret'', ''([^'']+)''')
      into existing
    from pg_proc p
    where p.proname = 'notify_safety_circle_pending';

    if existing is null or existing like '<%' then
      raise exception
        'No webhook secret found. Create it first: select vault.create_secret(''<value of SAFETY_CIRCLE_WEBHOOK_SECRET>'', ''safety_circle_webhook_secret'');';
    end if;
    perform vault.create_secret(existing, 'safety_circle_webhook_secret',
      'Shared secret for pg_net -> notify Edge Functions');
  end if;
end $$;

create or replace function public.webhook_secret()
returns text as $$
  select decrypted_secret from vault.decrypted_secrets
  where name = 'safety_circle_webhook_secret' limit 1;
$$ language sql stable security definer set search_path = public;

revoke all on function public.webhook_secret() from public, anon, authenticated;

create or replace function public.notify_safety_circle_pending()
returns trigger as $$
begin
  if NEW.status = 'pending' and NEW.contact_user_id is not null then
    perform net.http_post(
      url := 'https://frkwsgriwdezkvrmgsgf.supabase.co/functions/v1/notify-safety-circle-request',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', public.webhook_secret()
      ),
      body := jsonb_build_object('contact_id', NEW.id)
    );
  end if;
  return NEW;
end;
$$ language plpgsql security definer set search_path = public, net;

-- ----------------------------------------------------------------------------
-- 2. Deletion requests outlive the account (as an anonymous audit record)
-- ----------------------------------------------------------------------------
alter table account_deletion_requests add column if not exists completed_at timestamptz;
alter table account_deletion_requests add column if not exists processed_by uuid;
alter table account_deletion_requests alter column user_id drop not null;
alter table account_deletion_requests
  drop constraint if exists account_deletion_requests_user_id_fkey;
alter table account_deletion_requests
  add constraint account_deletion_requests_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;

-- Authorities see open requests with the requester's name; the Edge
-- Function does the actual deletion.
create or replace view public.open_deletion_requests
with (security_invoker = true) as
select r.id, r.user_id, p.full_name, r.status, r.reason, r.requested_at
from account_deletion_requests r
left join profiles p on p.id = r.user_id
where r.status in ('received', 'processing');

revoke all on public.open_deletion_requests from anon;
grant select on public.open_deletion_requests to authenticated;

-- ----------------------------------------------------------------------------
-- 3. Purge a user's data so the auth user can be deleted
-- ----------------------------------------------------------------------------
-- What happens to each kind of data (also stated in the Privacy Policy):
--   deleted:   their incident reports (+ confirmations), messages they sent,
--              feedback they submitted; profile, family links, location
--              shares, "I'm Safe" marks, alert receipts, policy acceptances
--              cascade when the auth user is deleted
--   detached:  records that must stay for others — alerts they created,
--              incidents they verified, shelters they manage, tasks/content
--              they authored, messages others sent them — keep the record
--              but no longer point at the person
create or replace function public.purge_user_data(target uuid)
returns void as $$
begin
  delete from incidents where reporter_id = target;
  delete from coordination_messages where sender_id = target;
  update coordination_messages set recipient_id = null where recipient_id = target;
  delete from feedback_forms where submitted_by = target;

  update alerts set created_by = null where created_by = target;
  update incidents set verified_by = null where verified_by = target;
  update shelters set managed_by = null where managed_by = target;
  update volunteer_tasks set created_by = null where created_by = target;
  update preparedness_content set created_by = null where created_by = target;
end;
$$ language plpgsql security definer set search_path = public;

-- Paths of the user's uploaded incident media, so the Edge Function can
-- remove the files through the Storage API (deleting storage.objects rows
-- directly would leave the files behind).
create or replace function public.user_media_paths(target uuid)
returns table (bucket text, path text) as $$
  select bucket_id, name from storage.objects
  where owner = target and bucket_id = 'incident-media';
$$ language sql stable security definer set search_path = public, storage;

revoke all on function public.purge_user_data(uuid) from public, anon, authenticated;
revoke all on function public.user_media_paths(uuid) from public, anon, authenticated;
grant execute on function public.purge_user_data(uuid) to service_role;
grant execute on function public.user_media_paths(uuid) to service_role;

-- ----------------------------------------------------------------------------
-- 4. Duplicate phone numbers fail the sign-up clearly
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'New User'),
    coalesce(new.raw_user_meta_data->>'phone', new.id::text),
    'member'
  )
  on conflict (id) do nothing;
  return new;
exception
  when unique_violation then
    -- Previously swallowed, leaving an account with no profile. The app
    -- shows "this mobile number may already be registered".
    raise exception 'phone_already_registered' using errcode = '23505';
  when others then
    raise warning 'handle_new_user failed for user %: %', new.id, sqlerrm;
    return new;
end;
$$ language plpgsql security definer set search_path = public;

revoke all on function public.handle_new_user() from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 5. "I'm Safe" -> email confirmed family
-- ----------------------------------------------------------------------------
create or replace function public.notify_im_safe()
returns trigger as $$
begin
  -- One email burst per sender per 10 minutes, so repeated taps can't spam
  -- their family.
  if exists (
    select 1 from safety_broadcasts
    where user_id = NEW.user_id
      and id <> NEW.id
      and sent_at > now() - interval '10 minutes'
  ) then
    return NEW;
  end if;

  perform net.http_post(
    url := 'https://frkwsgriwdezkvrmgsgf.supabase.co/functions/v1/notify-im-safe',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', public.webhook_secret()
    ),
    body := jsonb_build_object('broadcast_id', NEW.id)
  );
  return NEW;
end;
$$ language plpgsql security definer set search_path = public, net;

revoke all on function public.notify_im_safe() from public, anon, authenticated;

drop trigger if exists trg_notify_im_safe on safety_broadcasts;
create trigger trg_notify_im_safe
  after insert on safety_broadcasts
  for each row execute function public.notify_im_safe();
