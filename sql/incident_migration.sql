-- ============================================================================
-- Incident Reporting & Management — Supabase SQL Migration
-- Run this in the Supabase SQL Editor.
-- ============================================================================

-- 0. Enable PostGIS if not already enabled
create extension if not exists postgis;

-- ============================================================================
-- 1. Ensure the incidents table exists with all required columns.
-- ============================================================================
create table if not exists incidents (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id) on delete cascade,
  category    text not null check (category in (
                'waterlogging','blocked_road','power_outage',
                'trapped_person','structural_damage','other'
              )),
  description text,
  photo_url   text,
  video_url   text,
  location    geography(Point, 4326) not null,
  status      text not null default 'pending' check (status in (
                'pending','verified','rejected','resolved'
              )),
  credibility_score integer not null default 0,
  is_sos      boolean not null default false,
  verified_by uuid references profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- If the table already existed but was missing columns, add them:
do $$
begin
  if not exists (select 1 from information_schema.columns where table_name='incidents' and column_name='video_url') then
    alter table incidents add column video_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_name='incidents' and column_name='verified_by') then
    alter table incidents add column verified_by uuid references profiles(id);
  end if;
end$$;

-- ============================================================================
-- 2. Indices
-- ============================================================================

-- GiST index for efficient spatial queries (nearby, radius, map filtering)
create index if not exists idx_incidents_location_gist
  on incidents using gist (location);

-- Partial index for active SOS incidents — fast emergency lookups
create index if not exists idx_incidents_active_sos
  on incidents (created_at desc)
  where is_sos = true and status in ('pending', 'verified');

-- Status filter index
create index if not exists idx_incidents_status
  on incidents (status, created_at desc);

-- ============================================================================
-- 3. incidents_with_latlon view
-- ============================================================================
create or replace view incidents_with_latlon as
select *,
       ST_Y(location::geometry) as lat,
       ST_X(location::geometry) as lng
from incidents;

grant select on incidents_with_latlon to anon, authenticated;

-- ============================================================================
-- 4. incident_confirmations table
-- ============================================================================
create table if not exists incident_confirmations (
  id          uuid primary key default gen_random_uuid(),
  incident_id uuid not null references incidents(id) on delete cascade,
  member_id   uuid not null references profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (incident_id, member_id)
);

create index if not exists idx_confirmations_incident
  on incident_confirmations (incident_id);

-- ============================================================================
-- 5. Trigger: auto-update credibility_score
-- ============================================================================
create or replace function update_credibility_score()
returns trigger as $$
begin
  update incidents
  set credibility_score = (
    select count(*) from incident_confirmations
    where incident_id = NEW.incident_id
  ),
  updated_at = now()
  where id = NEW.incident_id;
  return NEW;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_update_credibility on incident_confirmations;
create trigger trg_update_credibility
  after insert on incident_confirmations
  for each row
  execute function update_credibility_score();

-- ============================================================================
-- 6. Trigger: auto-set updated_at on incidents
-- ============================================================================
create or replace function set_updated_at()
returns trigger as $$
begin
  NEW.updated_at = now();
  return NEW;
end;
$$ language plpgsql;

drop trigger if exists trg_incidents_updated_at on incidents;
create trigger trg_incidents_updated_at
  before update on incidents
  for each row
  execute function set_updated_at();

-- ============================================================================
-- 7. RLS Policies
-- ============================================================================
alter table incidents enable row level security;
alter table incident_confirmations enable row level security;

drop policy if exists "Authenticated can view incidents" on incidents;
create policy "Authenticated can view incidents"
  on incidents for select to authenticated using (true);

drop policy if exists "Authenticated can report incidents" on incidents;
create policy "Authenticated can report incidents"
  on incidents for insert to authenticated
  with check (
    reporter_id = auth.uid()
    and status = 'pending'
    and credibility_score = 0
    and verified_by is null
  );

create or replace function is_authority()
returns boolean as $$
begin
  return exists (
    select 1 from profiles
    where id = auth.uid()
    and role in ('authority', 'admin', 'volunteer_org')
  );
end;
$$ language plpgsql security definer;

drop policy if exists "Authority can update incidents" on incidents;
create policy "Authority can update incidents"
  on incidents for update to authenticated
  using (is_authority())
  with check (is_authority());

drop policy if exists "Citizens can update their own incidents" on incidents;
create policy "Citizens can update their own incidents"
  on incidents for update to authenticated
  using (reporter_id = auth.uid())
  with check (reporter_id = auth.uid());

drop policy if exists "Authority can delete incidents" on incidents;
create policy "Authority can delete incidents"
  on incidents for delete to authenticated
  using (is_authority());

drop policy if exists "Citizens can delete their own incidents" on incidents;
create policy "Citizens can delete their own incidents"
  on incidents for delete to authenticated
  using (reporter_id = auth.uid());

drop policy if exists "Authenticated can confirm incidents" on incident_confirmations;
create policy "Authenticated can confirm incidents"
  on incident_confirmations for insert to authenticated
  with check (member_id = auth.uid());

drop policy if exists "Authenticated can view confirmations" on incident_confirmations;
create policy "Authenticated can view confirmations"
  on incident_confirmations for select to authenticated using (true);

-- ============================================================================
-- 8. Storage bucket for incident media & RLS policies
-- ============================================================================
insert into storage.buckets (id, name, public)
values ('incident-media', 'incident-media', true)
on conflict (id) do update set public = true;

-- Drop any conflicting old policies on storage.objects for incident-media
drop policy if exists "Allow authenticated uploads to incident media" on storage.objects;
drop policy if exists "Allow all uploads to incident media" on storage.objects;
drop policy if exists "Allow public read access to incident media" on storage.objects;
drop policy if exists "Allow users to delete their own incident media" on storage.objects;
drop policy if exists "Allow updates to incident media" on storage.objects;
drop policy if exists "Allow deletes to incident media" on storage.objects;

-- Allow uploads (INSERT)
create policy "Allow all uploads to incident media"
  on storage.objects for insert
  with check (bucket_id = 'incident-media');

-- Allow public read (SELECT)
create policy "Allow public read access to incident media"
  on storage.objects for select
  using (bucket_id = 'incident-media');

-- Allow update
create policy "Allow updates to incident media"
  on storage.objects for update
  using (bucket_id = 'incident-media');

-- Allow delete
create policy "Allow deletes to incident media"
  on storage.objects for delete
  using (bucket_id = 'incident-media');


