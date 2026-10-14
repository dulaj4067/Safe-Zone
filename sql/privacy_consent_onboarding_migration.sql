-- ============================================================================
-- Privacy, consent, onboarding and real alert engagement (audit, Oct 2026)
--
-- Run AFTER sql/security_hardening_migration.sql. Idempotent.
--
--   policy_acceptances         append-only record of which Terms / Privacy
--                              Policy version each user accepted, and when
--   account_deletion_requests  real, auditable deletion requests (the app
--                              shows "received", not "deleted")
--   profiles.onboarding_completed_at
--                              so onboarding follows the account across
--                              devices; existing accounts are backfilled
--   alert_engagements          per-resident "seen" / "acknowledged" marks,
--                              replacing per-device SharedPreferences that
--                              authorities could never actually see
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Policy acceptances (audit trail)
-- ----------------------------------------------------------------------------
create table if not exists policy_acceptances (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  document     text not null check (document in ('terms', 'privacy')),
  version      text not null check (length(version) between 1 and 32),
  accepted_at  timestamptz not null default now(),
  app_version  text check (app_version is null or length(app_version) <= 32),
  unique (user_id, document, version)
);

create index if not exists idx_policy_acceptances_user
  on policy_acceptances (user_id, document, accepted_at desc);

alter table policy_acceptances enable row level security;

drop policy if exists "Users record their own acceptance" on policy_acceptances;
create policy "Users record their own acceptance"
  on policy_acceptances for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users read their own acceptances" on policy_acceptances;
create policy "Users read their own acceptances"
  on policy_acceptances for select to authenticated
  using (user_id = auth.uid() or public.is_authority());

-- No update/delete policies: rows are an audit trail. Server time is the
-- record of when acceptance happened, whatever the client sends.
create or replace function public.stamp_policy_acceptance()
returns trigger as $$
begin
  new.accepted_at := now();
  return new;
end;
$$ language plpgsql set search_path = public;

drop trigger if exists trg_stamp_policy_acceptance on policy_acceptances;
create trigger trg_stamp_policy_acceptance
  before insert on policy_acceptances
  for each row execute function public.stamp_policy_acceptance();

revoke all on function public.stamp_policy_acceptance() from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2. Account / data deletion requests
-- ----------------------------------------------------------------------------
create table if not exists account_deletion_requests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  status        text not null default 'received'
                check (status in ('received', 'processing', 'completed', 'cancelled')),
  reason        text check (reason is null or length(reason) <= 500),
  requested_at  timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- At most one open request per user, so repeated taps can't pile up rows.
create unique index if not exists uq_open_deletion_request
  on account_deletion_requests (user_id)
  where status in ('received', 'processing');

alter table account_deletion_requests enable row level security;

drop policy if exists "Users see their own deletion requests" on account_deletion_requests;
create policy "Users see their own deletion requests"
  on account_deletion_requests for select to authenticated
  using (user_id = auth.uid() or public.is_authority());

drop policy if exists "Authorities process deletion requests" on account_deletion_requests;
create policy "Authorities process deletion requests"
  on account_deletion_requests for update to authenticated
  using (public.is_authority())
  with check (public.is_authority());

-- Users create/cancel only through these functions (idempotent).
create or replace function public.request_account_deletion(reason text default null)
returns account_deletion_requests as $$
declare
  req account_deletion_requests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Sign in to request account deletion.' using errcode = '42501';
  end if;

  select * into req from account_deletion_requests
  where user_id = auth.uid() and status in ('received', 'processing');
  if found then
    return req;  -- already open: repeated requests are a no-op
  end if;

  insert into account_deletion_requests (user_id, reason)
  values (auth.uid(), nullif(left(trim(coalesce(reason, '')), 500), ''))
  returning * into req;
  return req;
end;
$$ language plpgsql security definer set search_path = public;

create or replace function public.cancel_account_deletion()
returns void as $$
begin
  update account_deletion_requests
  set status = 'cancelled', updated_at = now()
  where user_id = auth.uid() and status = 'received';
end;
$$ language plpgsql security definer set search_path = public;

revoke all on function public.request_account_deletion(text) from public, anon;
revoke all on function public.cancel_account_deletion() from public, anon;
grant execute on function public.request_account_deletion(text) to authenticated;
grant execute on function public.cancel_account_deletion() to authenticated;

-- ----------------------------------------------------------------------------
-- 3. Onboarding state on the profile
-- ----------------------------------------------------------------------------
alter table profiles add column if not exists onboarding_completed_at timestamptz;

-- Accounts that existed before onboarding shipped have been using the app
-- already: don't make them sit through the intro (they still see the policy
-- acceptance prompt, which is separate).
update profiles
set onboarding_completed_at = coalesce(created_at, now())
where onboarding_completed_at is null
  and created_at < '2026-10-15'::timestamptz;

-- ----------------------------------------------------------------------------
-- 4. Alert engagement (seen / acknowledged) per resident
-- ----------------------------------------------------------------------------
create table if not exists alert_engagements (
  alert_id         uuid not null references alerts(id) on delete cascade,
  user_id          uuid not null references auth.users(id) on delete cascade,
  seen_at          timestamptz not null default now(),
  acknowledged_at  timestamptz,
  primary key (alert_id, user_id)
);

create index if not exists idx_alert_engagements_alert
  on alert_engagements (alert_id);

alter table alert_engagements enable row level security;

drop policy if exists "Residents record their own engagement" on alert_engagements;
create policy "Residents record their own engagement"
  on alert_engagements for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Residents update their own engagement" on alert_engagements;
create policy "Residents update their own engagement"
  on alert_engagements for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Residents and authorities read engagement" on alert_engagements;
create policy "Residents and authorities read engagement"
  on alert_engagements for select to authenticated
  using (user_id = auth.uid() or public.is_authority());
