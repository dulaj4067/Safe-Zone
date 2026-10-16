-- ============================================================================
-- Account deletion: confirm by email before an administrator sees the request
-- Supabase SQL Migration — run this in the Supabase SQL Editor.
--
-- New flow
--   1. A citizen asks to delete their account in the app. The request is saved
--      as 'awaiting_email' and an email with a confirmation link is sent.
--   2. They open the link. The request becomes 'received' and only NOW appears
--      in the administrators' Account Deletion Requests list.
--   3. An administrator deletes the account (process-account-deletion).
--
-- A request nobody confirms by email never reaches an administrator, so a
-- stranger who borrows an unlocked phone cannot get an account deleted.
--
-- Run after sql/privacy_consent_onboarding_migration.sql and
-- sql/account_deletion_and_notifications_migration.sql. Idempotent.
-- ============================================================================

-- 1. Confirmation columns. The token itself is never stored, only its SHA-256.
alter table account_deletion_requests add column if not exists email_confirmed_at     timestamptz;
alter table account_deletion_requests add column if not exists confirm_token_hash     text;
alter table account_deletion_requests add column if not exists confirm_expires_at     timestamptz;
alter table account_deletion_requests add column if not exists confirm_email_sent_at  timestamptz;

-- 2. Allow the new status. Drop whichever check constraint covers status
--    (its generated name can differ) and put back one that includes it.
do $$
declare c text;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.account_deletion_requests'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%status%'
  loop
    execute format('alter table account_deletion_requests drop constraint %I', c);
  end loop;

  alter table account_deletion_requests
    add constraint account_deletion_requests_status_check
    check (status in ('awaiting_email', 'received', 'processing', 'completed', 'cancelled'));
end $$;

-- 3. Still at most one open request per user (now including awaiting_email).
drop index if exists uq_open_deletion_request;
create unique index uq_open_deletion_request
  on account_deletion_requests (user_id)
  where status in ('awaiting_email', 'received', 'processing');

-- 4. Asking for deletion starts at awaiting_email. Idempotent as before: an
--    already-open request is returned unchanged.
create or replace function public.request_account_deletion(reason text default null)
returns account_deletion_requests as $$
declare
  req account_deletion_requests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Sign in to request account deletion.' using errcode = '42501';
  end if;

  select * into req from account_deletion_requests
  where user_id = auth.uid() and status in ('awaiting_email', 'received', 'processing');
  if found then
    return req;
  end if;

  insert into account_deletion_requests (user_id, reason, status)
  values (auth.uid(), nullif(left(trim(coalesce(reason, '')), 500), ''), 'awaiting_email')
  returning * into req;
  return req;
end;
$$ language plpgsql security definer set search_path = public;

-- 5. Cancelling works until an administrator starts processing.
create or replace function public.cancel_account_deletion()
returns void as $$
begin
  update account_deletion_requests
  set status = 'cancelled',
      confirm_token_hash = null,
      confirm_expires_at = null,
      updated_at = now()
  where user_id = auth.uid() and status in ('awaiting_email', 'received');
end;
$$ language plpgsql security definer set search_path = public;

revoke all on function public.request_account_deletion(text) from public, anon;
revoke all on function public.cancel_account_deletion() from public, anon;
grant execute on function public.request_account_deletion(text) to authenticated;
grant execute on function public.cancel_account_deletion() to authenticated;

-- 6. Administrators only see email-confirmed requests (received / processing);
--    awaiting_email ones stay invisible to them. Adds when the email was
--    confirmed as a last column.
create or replace view public.open_deletion_requests
with (security_invoker = true) as
select r.id, r.user_id, p.full_name, r.status, r.reason, r.requested_at,
       r.email_confirmed_at
from account_deletion_requests r
left join profiles p on p.id = r.user_id
where r.status in ('received', 'processing');

revoke all on public.open_deletion_requests from anon;
grant select on public.open_deletion_requests to authenticated;
