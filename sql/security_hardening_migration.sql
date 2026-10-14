-- ============================================================================
-- Security hardening (audit, Oct 2026)
--
-- Fixes found while auditing RLS and the Supabase security advisor:
--   1. Any signed-in user could change their own profiles.role (e.g. to
--      'authority') because the update policy didn't restrict columns.
--   2. profiles (names, phone numbers, roles, zones) was readable by anyone
--      holding the publishable key — including signed-out clients.
--   3. active_sos_view (SECURITY DEFINER, granted to anon) exposed every SOS
--      reporter's name, phone and location.
--   4. Citizens could insert/update their own incidents as 'verified', set
--      verified_by, or edit credibility_score.
--   5. bump_credibility ran as the confirming citizen, so RLS silently
--      blocked the credibility update on other people's incidents.
--   6. Advisor warnings: SECURITY DEFINER views, anon-executable RPCs and
--      trigger functions, mutable search_path.
--
-- Idempotent: safe to re-run.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. profiles.role is server-managed
-- ----------------------------------------------------------------------------
-- SECURITY INVOKER on purpose: current_user must be the caller's role so the
-- check only applies to API clients (anon/authenticated), not to the
-- handle_new_user trigger, the dashboard, or service-role jobs.
create or replace function public.guard_profile_role()
returns trigger as $$
begin
  if current_user in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      new.role := 'member';
    elsif new.role is distinct from old.role then
      raise exception 'Only an administrator can change account roles.'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$ language plpgsql set search_path = public;

drop trigger if exists trg_guard_profile_role on profiles;
create trigger trg_guard_profile_role
  before insert or update on profiles
  for each row execute function public.guard_profile_role();

-- ----------------------------------------------------------------------------
-- 2. profiles visibility: own row, or everything for authorities
-- ----------------------------------------------------------------------------
drop policy if exists "Users can view all profiles" on profiles;
drop policy if exists "Users read own profile; authorities read all" on profiles;
create policy "Users read own profile; authorities read all"
  on profiles for select to authenticated
  using (id = auth.uid() or public.is_authority());

drop policy if exists "Users can update own profile" on profiles;
create policy "Users can update own profile"
  on profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists "Users can insert own profile" on profiles;
create policy "Users can insert own profile"
  on profiles for insert to authenticated
  with check (id = auth.uid());

revoke all on public.profiles from anon;

-- Other people's display names (message threads, shelter managers) without
-- exposing their phone, role or zone.
create or replace function public.profile_display_names(ids uuid[])
returns table (id uuid, full_name text) as $$
  select p.id, p.full_name
  from profiles p
  where auth.uid() is not null
    and p.id = any(ids[1:200]);
$$ language sql stable security definer set search_path = public;

revoke all on function public.profile_display_names(uuid[]) from public, anon;
grant execute on function public.profile_display_names(uuid[]) to authenticated;

-- ----------------------------------------------------------------------------
-- 3. Views run with the caller's permissions
-- ----------------------------------------------------------------------------
alter view public.active_sos_view set (security_invoker = true);
alter view public.dashboard_map_view set (security_invoker = true);
alter view public.incidents_with_latlon set (security_invoker = true);
revoke all on public.active_sos_view from anon;

-- my_pending_safety_circle_requests must stay SECURITY DEFINER: it shows the
-- requester's name before the two people are linked. It is already scoped to
-- auth.uid(), so only signed-out access is removed.
revoke all on public.my_pending_safety_circle_requests from anon;

-- ----------------------------------------------------------------------------
-- 4. Incident review fields are authority-only
-- ----------------------------------------------------------------------------
create or replace function public.guard_incident_fields()
returns trigger as $$
begin
  -- Triggers/jobs running as the table owner (e.g. bump_credibility) and
  -- authorities are trusted; only plain API clients are restricted.
  if current_user not in ('anon', 'authenticated') or public.is_authority() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.status := 'pending';
    new.credibility_score := 0;
    new.verified_by := null;
  else
    new.reporter_id := old.reporter_id;
    new.credibility_score := old.credibility_score;
    new.verified_by := old.verified_by;
    -- Reporters may close their own report, nothing else.
    if new.status is distinct from old.status and new.status <> 'resolved' then
      raise exception 'Only authorities can change an incident''s review status.'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$ language plpgsql set search_path = public;

drop trigger if exists trg_guard_incident_fields on incidents;
create trigger trg_guard_incident_fields
  before insert or update on incidents
  for each row execute function public.guard_incident_fields();

-- ----------------------------------------------------------------------------
-- 5. Community confirmations actually raise credibility
-- ----------------------------------------------------------------------------
alter function public.bump_credibility() security definer;
alter function public.bump_credibility() set search_path = public;

drop policy if exists "Members can confirm incidents" on incident_confirmations;
create policy "Members can confirm incidents"
  on incident_confirmations for insert to authenticated
  with check (
    auth.uid() = member_id
    and not exists (
      select 1 from incidents i
      where i.id = incident_id and i.reporter_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 6. Function hygiene (advisor)
-- ----------------------------------------------------------------------------
alter function public.is_authority() set search_path = public;
alter function public.check_shelter_capacity() set search_path = public;

-- RPCs the app calls only while signed in.
do $$
declare f text;
begin
  foreach f in array array[
    'public.accept_family_invite(text)',
    'public.create_family_invite()',
    'public.is_confirmed_family(uuid)',
    'public.my_family_circle()',
    'public.remove_family_member(uuid)',
    'public.respond_to_safety_circle_request(uuid, boolean)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;

  -- Trigger functions are never meant to be called over the API. Revoking
  -- EXECUTE doesn't affect them firing as triggers.
  foreach f in array array[
    'public.handle_new_user()',
    'public.notify_safety_circle_pending()',
    'public.relink_safety_circle_contacts_on_profile_change()',
    'public.resolve_safety_circle_contact_user()',
    'public.bump_credibility()',
    'public.check_shelter_capacity()',
    'public.guard_profile_role()',
    'public.guard_incident_fields()'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $$;

-- is_authority() stays executable by anon: policies on public-readable tables
-- (e.g. preparedness_content) evaluate it for signed-out reads too.
