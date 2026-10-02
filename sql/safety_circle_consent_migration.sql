-- ============================================================================
-- Safety Circle, Live ETA Sharing & "I'm Safe" Broadcasts
-- + consent-to-be-added flow (status: pending/confirmed/declined)
-- + cleanup of leftover test/placeholder rows
--
-- Supersedes sql/safety_circle_migration.sql for fresh deployments — run
-- this one instead (it creates the same tables/views plus the consent
-- additions). If safety_circle_migration.sql was already run, this is safe
-- to run on top of it: every statement is create-or-replace / if-not-exists.
--
-- Run this once in the Safe-Zone Supabase project's SQL Editor.
-- ============================================================================

create or replace function set_updated_at()
returns trigger as $$
begin
  NEW.updated_at = now();
  return NEW;
end;
$$ language plpgsql set search_path = public;

-- ============================================================================
-- 1. safety_circle_contacts
-- ============================================================================
create table if not exists safety_circle_contacts (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null references profiles(id) on delete cascade,
  name            text not null,
  phone_number    text not null,
  relationship    text not null default 'Contact',
  contact_user_id uuid references profiles(id) on delete set null,
  -- 'pending' until the linked person confirms. Only matters when
  -- contact_user_id is set — that's the only case where this row could
  -- expose someone's real location. See the view/RLS below: a location is
  -- never returned for anything but a 'confirmed' row, no matter what the
  -- client sends.
  status          text not null default 'pending'
                    check (status in ('pending', 'confirmed', 'declined')),
  created_at      timestamptz not null default now(),
  unique (owner_id, phone_number)
);

-- In case safety_circle_migration.sql already ran without this column.
alter table safety_circle_contacts
  add column if not exists status text not null default 'pending';
alter table safety_circle_contacts
  drop constraint if exists safety_circle_contacts_status_check;
alter table safety_circle_contacts
  add constraint safety_circle_contacts_status_check
  check (status in ('pending', 'confirmed', 'declined'));

create index if not exists idx_safety_circle_contacts_owner
  on safety_circle_contacts (owner_id);

create index if not exists idx_safety_circle_contacts_user
  on safety_circle_contacts (contact_user_id);

create or replace function resolve_safety_circle_contact_user()
returns trigger as $$
begin
  select id into NEW.contact_user_id
  from profiles
  where phone = NEW.phone_number
  limit 1;
  return NEW;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_resolve_contact_user on safety_circle_contacts;
create trigger trg_resolve_contact_user
  before insert or update of phone_number on safety_circle_contacts
  for each row
  execute function resolve_safety_circle_contact_user();

-- When a profile's phone changes/arrives and it newly matches a contact row,
-- link it AND reset status to 'pending' — a fresh link is a fresh consent
-- requirement, even if some other link on this row was confirmed before.
create or replace function relink_safety_circle_contacts_on_profile_change()
returns trigger as $$
begin
  update safety_circle_contacts
  set contact_user_id = NEW.id,
      status = 'pending'
  where phone_number = NEW.phone
    and (contact_user_id is distinct from NEW.id);
  return NEW;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_relink_contacts_on_profile_change on profiles;
create trigger trg_relink_contacts_on_profile_change
  after insert or update of phone on profiles
  for each row
  execute function relink_safety_circle_contacts_on_profile_change();

-- ============================================================================
-- 2. location_shares
-- ============================================================================
create table if not exists location_shares (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null references profiles(id) on delete cascade,
  zone_id       uuid references zones(id),
  lat           double precision not null,
  lng           double precision not null,
  eta_seconds   integer not null default 0,
  distance_km   numeric not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_location_shares_owner
  on location_shares (owner_id, updated_at desc);

drop trigger if exists trg_location_shares_updated_at on location_shares;
create trigger trg_location_shares_updated_at
  before update on location_shares
  for each row
  execute function set_updated_at();

-- ============================================================================
-- 3. safety_broadcasts
-- ============================================================================
create table if not exists safety_broadcasts (
  id       uuid primary key default gen_random_uuid(),
  user_id  uuid not null references profiles(id) on delete cascade,
  zone_id  uuid references zones(id),
  sent_at  timestamptz not null default now()
);

create index if not exists idx_safety_broadcasts_user
  on safety_broadcasts (user_id, sent_at desc);

-- ============================================================================
-- 4. safety_circle_last_locations — only ever returns a location for a
--    CONFIRMED link. A pending or declined contact shows no location,
--    regardless of what the client asks for.
--
--    security_invoker = true is load-bearing here, not cosmetic: a plain
--    view defaults to running with its CREATOR's rights, which bypasses
--    the RLS on safety_circle_contacts/location_shares entirely and lets
--    ANY authenticated caller read EVERY row — verified live against this
--    project (an unrelated account could read another user's contacts and
--    raw GPS coordinates with an unfiltered select before this was set).
--    With security_invoker, the view runs as the CALLING user, so the
--    underlying tables' RLS policies apply exactly as if queried directly.
-- ============================================================================
create or replace view safety_circle_last_locations
with (security_invoker = true)
as
select
  sc.id as contact_id,
  sc.owner_id,
  sc.name,
  sc.relationship,
  sc.contact_user_id,
  ls.lat,
  ls.lng,
  ls.is_active,
  ls.updated_at as last_seen_at
from safety_circle_contacts sc
left join lateral (
  select lat, lng, is_active, updated_at
  from location_shares
  where owner_id = sc.contact_user_id
  order by updated_at desc
  limit 1
) ls on sc.contact_user_id is not null and sc.status = 'confirmed';

grant select on safety_circle_last_locations to authenticated;

-- ============================================================================
-- 5. my_pending_safety_circle_requests — what a user sees was added them,
--    and by whom, so they can confirm/decline. A plain view defaults to
--    creator-rights (definer-like) unless security_invoker is set, which
--    is required here: the contact being added usually cannot read the
--    owner's profiles row directly, so this join needs elevated rights to
--    resolve owner_name. It's safe because the WHERE clause hard-scopes
--    every row to auth.uid() — a caller can only ever see requests about
--    themselves, never anyone else's.
-- ============================================================================
create or replace view my_pending_safety_circle_requests as
select sc.id, sc.owner_id, p.full_name as owner_name, sc.relationship, sc.created_at
from safety_circle_contacts sc
join profiles p on p.id = sc.owner_id
where sc.contact_user_id = auth.uid()
  and sc.status = 'pending';

grant select on my_pending_safety_circle_requests to authenticated;

-- Lets the targeted contact flip their OWN request to confirmed/declined —
-- a SECURITY DEFINER function instead of an open UPDATE policy, so a client
-- can only ever change status on a row about them, never touch anything
-- else on it (name, phone, relationship stay the owner's alone).
create or replace function respond_to_safety_circle_request(request_id uuid, accept boolean)
returns void as $$
begin
  update safety_circle_contacts
  set status = case when accept then 'confirmed' else 'declined' end
  where id = request_id
    and contact_user_id = auth.uid()
    and status = 'pending';
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function respond_to_safety_circle_request(uuid, boolean) to authenticated;

-- ============================================================================
-- 6. RLS Policies
-- ============================================================================
alter table safety_circle_contacts enable row level security;
alter table location_shares enable row level security;
alter table safety_broadcasts enable row level security;

drop policy if exists "Citizens manage their own circle" on safety_circle_contacts;
create policy "Citizens manage their own circle"
  on safety_circle_contacts for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Lets a targeted contact SEE the pending row naming them (so the app can
-- render "X wants to add you"), without letting them edit it directly —
-- the only mutation path for them is the RPC above.
drop policy if exists "Linked contacts can see requests about them" on safety_circle_contacts;
create policy "Linked contacts can see requests about them"
  on safety_circle_contacts for select to authenticated
  using (contact_user_id = auth.uid());

drop policy if exists "Citizens post their own location shares" on location_shares;
create policy "Citizens post their own location shares"
  on location_shares for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "Citizens update their own location shares" on location_shares;
create policy "Citizens update their own location shares"
  on location_shares for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Only a CONFIRMED circle link can read someone else's location rows.
drop policy if exists "Circle members can view each other's shares" on location_shares;
create policy "Circle members can view each other's shares"
  on location_shares for select to authenticated
  using (
    owner_id = auth.uid()
    or exists (
      select 1 from safety_circle_contacts sc
      where sc.owner_id = location_shares.owner_id
        and sc.contact_user_id = auth.uid()
        and sc.status = 'confirmed'
    )
  );

drop policy if exists "Citizens post their own safety broadcasts" on safety_broadcasts;
create policy "Citizens post their own safety broadcasts"
  on safety_broadcasts for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Circle members can view each other's broadcasts" on safety_broadcasts;
create policy "Circle members can view each other's broadcasts"
  on safety_broadcasts for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from safety_circle_contacts sc
      where sc.owner_id = safety_broadcasts.user_id
        and sc.contact_user_id = auth.uid()
        and sc.status = 'confirmed'
    )
  );

-- ============================================================================
-- 7. Cleanup — leftover test/placeholder rows found during the account fix
--    (generic "Zone B/C" names, a test alert, and three "Explain"/
--    "Description"/"help wanted" incidents created while manually testing
--    the report-incident form). Safe to skip this section if you'd rather
--    review them yourself first.
-- ============================================================================
delete from incident_confirmations where incident_id in (
  'c12ad7fb-68f9-47c9-9b60-474bbb658c01',
  '0bfb20e3-ed23-432c-897f-fa42ba72f7fd',
  '8574f5d5-65f2-4bd7-90dc-936acc908274'
);
delete from volunteer_assignments where task_id = 'eeeeeeee-0000-0000-0000-000000000001';
delete from volunteer_tasks where id = 'eeeeeeee-0000-0000-0000-000000000001';
delete from incidents where id in (
  'c12ad7fb-68f9-47c9-9b60-474bbb658c01',
  '0bfb20e3-ed23-432c-897f-fa42ba72f7fd',
  '8574f5d5-65f2-4bd7-90dc-936acc908274'
);
delete from shelters where id in (
  'dddddddd-0000-0000-0000-000000000001',
  'dddddddd-0000-0000-0000-000000000002'
);
delete from alerts where id = 'decc134b-574f-4329-9bbd-83f395fb4e33';
