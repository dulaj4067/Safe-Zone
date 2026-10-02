-- Shared preparedness content plus user-owned risk profiles and checklist progress.
-- Run this once in the Supabase SQL Editor before enabling repository sync.

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

create table if not exists preparedness_content (
  content_type text not null check (
    content_type in ('guide', 'route', 'history', 'checklist_item', 'reminder')
  ),
  id text not null,
  zone_id text,
  payload jsonb not null,
  updated_by uuid references profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (content_type, id)
);

create index if not exists idx_preparedness_content_type_zone
  on preparedness_content (content_type, zone_id);

alter table preparedness_content enable row level security;

drop policy if exists "Authenticated can view preparedness content" on preparedness_content;
create policy "Authenticated can view preparedness content"
  on preparedness_content for select to authenticated using (true);

drop policy if exists "Authorities manage preparedness content" on preparedness_content;
create policy "Authorities manage preparedness content"
  on preparedness_content for all to authenticated
  using (is_authority())
  with check (is_authority());

grant select, insert, update, delete on preparedness_content to authenticated;

create table if not exists preparedness_risk_profiles (
  user_id uuid primary key references profiles(id) on delete cascade,
  profile jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table preparedness_risk_profiles enable row level security;

drop policy if exists "Members manage their own preparedness profile" on preparedness_risk_profiles;
create policy "Members manage their own preparedness profile"
  on preparedness_risk_profiles for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on preparedness_risk_profiles to authenticated;

create table if not exists preparedness_user_checklists (
  user_id uuid primary key references profiles(id) on delete cascade,
  items jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table preparedness_user_checklists enable row level security;

drop policy if exists "Members manage their own preparedness checklist" on preparedness_user_checklists;
create policy "Members manage their own preparedness checklist"
  on preparedness_user_checklists for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on preparedness_user_checklists to authenticated;
