-- ============================================================================
-- Account deletion: confirm with an emailed code before an administrator sees it
-- Supabase SQL Migration — run this in the Supabase SQL Editor.
--
-- Flow
--   1. A citizen asks to delete their account in the app. The request is saved
--      as 'awaiting_email' and a 6-digit code is emailed to them.
--   2. They type the code into the app. confirm_account_deletion() checks it;
--      the request becomes 'received' and only NOW appears in the
--      administrators' Account Deletion Requests list.
--   3. An administrator deletes the account (process-account-deletion).
--
-- A request nobody confirms never reaches an administrator, so a stranger who
-- borrows an unlocked phone cannot get an account deleted. A typed code (not a
-- link) also cannot be confirmed by an email scanner that opens links.
--
-- Run after sql/privacy_consent_onboarding_migration.sql and
-- sql/account_deletion_and_notifications_migration.sql. Idempotent.
-- ============================================================================

-- 1. Columns. The code itself is never stored, only a salted SHA-256 of it.
alter table account_deletion_requests add column if not exists email_confirmed_at     timestamptz;
alter table account_deletion_requests add column if not exists confirm_code_hash      text;
alter table account_deletion_requests add column if not exists confirm_expires_at     timestamptz;
alter table account_deletion_requests add column if not exists confirm_email_sent_at  timestamptz;
alter table account_deletion_requests add column if not exists confirm_attempts       integer not null default 0;

-- (An earlier draft used an emailed link and a token column; not needed now.)
alter table account_deletion_requests drop column if exists confirm_token_hash;

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
      confirm_code_hash = null,
      confirm_expires_at = null,
      updated_at = now()
  where user_id = auth.uid() and status in ('awaiting_email', 'received');
end;
$$ language plpgsql security definer set search_path = public;

-- 6. The typed code. The Edge Function stores sha256(request_id || ':' || code)
--    when it emails the code; this recomputes it. It RETURNS a result instead of
--    raising an error for a wrong code, because raising would roll back the
--    attempt counter: five wrong tries burn the code (ask for a new email), and
--    a code expires after 30 minutes.
--    Result: 'confirmed' | 'wrong' | 'expired' | 'too_many' | 'no_code' | 'no_request'
create or replace function public.confirm_account_deletion(code text)
returns text as $$
declare
  req    account_deletion_requests%rowtype;
  wanted text;
begin
  if auth.uid() is null then
    raise exception 'Sign in to confirm account deletion.' using errcode = '42501';
  end if;

  select * into req from account_deletion_requests
  where user_id = auth.uid() and status = 'awaiting_email'
  for update;
  if not found then
    return 'no_request';
  end if;

  if req.confirm_code_hash is null or req.confirm_expires_at is null then
    return 'no_code';
  end if;
  if req.confirm_expires_at < now() then
    return 'expired';
  end if;
  if req.confirm_attempts >= 5 then
    return 'too_many';
  end if;

  wanted := encode(
    digest(convert_to(req.id::text || ':' || trim(coalesce(code, '')), 'UTF8'), 'sha256'),
    'hex'
  );
  if wanted <> req.confirm_code_hash then
    update account_deletion_requests
    set confirm_attempts = confirm_attempts + 1, updated_at = now()
    where id = req.id;
    return 'wrong';
  end if;

  update account_deletion_requests
  set status = 'received',
      email_confirmed_at = now(),
      confirm_code_hash = null,
      confirm_expires_at = null,
      confirm_attempts = 0,
      updated_at = now()
  where id = req.id;
  return 'confirmed';
end;
$$ language plpgsql security definer set search_path = public, extensions;

revoke all on function public.request_account_deletion(text) from public, anon;
revoke all on function public.cancel_account_deletion() from public, anon;
revoke all on function public.confirm_account_deletion(text) from public, anon;
grant execute on function public.request_account_deletion(text) to authenticated;
grant execute on function public.cancel_account_deletion() to authenticated;
grant execute on function public.confirm_account_deletion(text) to authenticated;

-- 7. Administrators only see email-confirmed requests (received / processing);
--    awaiting_email ones stay invisible to them.
create or replace view public.open_deletion_requests
with (security_invoker = true) as
select r.id, r.user_id, p.full_name, r.status, r.reason, r.requested_at,
       r.email_confirmed_at
from account_deletion_requests r
left join profiles p on p.id = r.user_id
where r.status in ('received', 'processing');

revoke all on public.open_deletion_requests from anon;
grant select on public.open_deletion_requests to authenticated;
