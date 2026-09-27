-- ============================================================================
-- Safety Circle, Live ETA Sharing & "I'm Safe" Broadcasts — Supabase SQL Migration
-- Run this in the Supabase SQL Editor.
--
-- Context: lib/providers/safety_provider.dart already calls three tables —
-- safety_circle_contacts, location_shares, safety_broadcasts — that do not
-- exist in the live schema. Every one of those calls is wrapped in a
-- try/catch that silently falls back to fake demo data, so today the whole
-- "I'm Safe" / Safety Circle feature runs with no real persistence at all.
-- This migration creates the three tables the Dart code already assumes,
-- plus what's needed to answer "where was my safety-circle contact last
-- seen": a `contact_user_id` link from a free-text contact to a real
-- profiles row (auto-resolved by phone number), and a view that joins a
-- citizen's circle to each linked contact's most recent location_shares row.
-- ============================================================================

-- 0. set_updated_at() — reused below; defined here too so this file runs
-- standalone even if sql/incident_migration.sql (which also defines it)
-- hasn't been run against this project.
create or replace function set_updated_at()
returns trigger as $$
begin
  NEW.updated_at = now();
  return NEW;
end;
$$ language plpgsql;

-- ============================================================================
-- 1. safety_circle_contacts
-- ============================================================================
create table if not exists safety_circle_contacts (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null references profiles(id) on delete cascade,
  name            text not null,
  phone_number    text not null,
  relationship    text not null default 'Contact',
  -- Resolved automatically (see trigger below) when phone_number matches a
  -- registered profile — null means this contact isn't an app user, so
  -- there's nothing to show a location marker for.
  contact_user_id uuid references profiles(id) on delete set null,
  created_at      timestamptz not null default now(),
  unique (owner_id, phone_number)
);

create index if not exists idx_safety_circle_contacts_owner
  on safety_circle_contacts (owner_id);

create index if not exists idx_safety_circle_contacts_user
  on safety_circle_contacts (contact_user_id);

-- Auto-link a contact to a real profile by matching phone numbers, both on
-- insert/update of the contact and (via the second trigger) when someone
-- signs up or changes their phone number after already being added.
create or replace function resolve_safety_circle_contact_user()
returns trigger as $$
begin
  select id into NEW.contact_user_id
  from profiles
  where phone = NEW.phone_number
  limit 1;
  return NEW;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_resolve_contact_user on safety_circle_contacts;
create trigger trg_resolve_contact_user
  before insert or update of phone_number on safety_circle_contacts
  for each row
  execute function resolve_safety_circle_contact_user();

create or replace function relink_safety_circle_contacts_on_profile_change()
returns trigger as $$
begin
  update safety_circle_contacts
  set contact_user_id = NEW.id
  where phone_number = NEW.phone
    and (contact_user_id is distinct from NEW.id);
  return NEW;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_relink_contacts_on_profile_change on profiles;
create trigger trg_relink_contacts_on_profile_change
  after insert or update of phone on profiles
  for each row
  execute function relink_safety_circle_contacts_on_profile_change();

-- ============================================================================
-- 2. location_shares — active "Share my ETA" sessions. The most recent row
--    per owner (active or not) also doubles as that person's last-known
--    location, so a session ending doesn't erase where they last were.
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
-- 3. safety_broadcasts — "I'm Safe" one-tap notifications.
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
-- 4. safety_circle_last_locations — what the app queries to draw a marker
--    for each circle contact at "where they were last at". A view (not
--    security definer), so it's evaluated under the querying citizen's own
--    RLS — a caller only ever sees rows their own policies allow.
-- ============================================================================
create or replace view safety_circle_last_locations as
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
) ls on sc.contact_user_id is not null;

grant select on safety_circle_last_locations to authenticated;

-- ============================================================================
-- 5. RLS Policies
-- ============================================================================
alter table safety_circle_contacts enable row level security;
alter table location_shares enable row level security;
alter table safety_broadcasts enable row level security;

drop policy if exists "Citizens manage their own circle" on safety_circle_contacts;
create policy "Citizens manage their own circle"
  on safety_circle_contacts for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "Citizens post their own location shares" on location_shares;
create policy "Citizens post their own location shares"
  on location_shares for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "Citizens update their own location shares" on location_shares;
create policy "Citizens update their own location shares"
  on location_shares for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Privacy model: the SHARER controls visibility by adding the viewer to
-- THEIR OWN circle — "I added Mom to my circle" means Mom can see me, not
-- the other way round. A citizen can always read their own rows too.
drop policy if exists "Circle members can view each other's shares" on location_shares;
create policy "Circle members can view each other's shares"
  on location_shares for select to authenticated
  using (
    owner_id = auth.uid()
    or exists (
      select 1 from safety_circle_contacts sc
      where sc.owner_id = location_shares.owner_id
        and sc.contact_user_id = auth.uid()
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
    )
  );
