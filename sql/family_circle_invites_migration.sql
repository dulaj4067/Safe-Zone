-- ============================================================================
-- Family circle — Google-family-style invite links.
-- Run this in the Supabase SQL Editor, after
-- sql/safety_circle_consent_migration.sql and
-- sql/safety_circle_notify_trigger.sql.
--
-- How it works:
--   1. A user creates an invite (create_family_invite) and shares the link.
--      Invites are single-use and expire after 7 days.
--   2. Whoever opens the link calls accept_family_invite(code). That adds a
--      'pending' safety_circle_contacts row linking the two of them, which
--      fires the existing notify trigger (email) and shows up in
--      my_pending_safety_circle_requests (in-app prompt).
--   3. They confirm via the existing respond_to_safety_circle_request RPC.
--      Only then can either of them see the other's location.
--
-- A confirmed link is now MUTUAL, like a family group: the inviter chose
-- to invite, the invitee chose to confirm, so both see each other. Before
-- this, a link only let one side see the other.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Invites
-- ----------------------------------------------------------------------------
create table if not exists family_invites (
  code        text primary key,
  owner_id    uuid not null references profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '7 days',
  used_by     uuid references profiles(id) on delete set null,
  used_at     timestamptz
);

create index if not exists idx_family_invites_owner on family_invites (owner_id);

alter table family_invites enable row level security;

-- Owners can list and revoke their own invites. Creating and accepting go
-- through the RPCs below, so there's no insert/update policy at all.
drop policy if exists "Owners read their invites" on family_invites;
create policy "Owners read their invites"
  on family_invites for select to authenticated
  using (owner_id = auth.uid());

drop policy if exists "Owners revoke their invites" on family_invites;
create policy "Owners revoke their invites"
  on family_invites for delete to authenticated
  using (owner_id = auth.uid());

create or replace function create_family_invite()
returns text as $$
declare
  new_code text;
begin
  if auth.uid() is null then
    raise exception 'Sign in to invite family members';
  end if;
  if (select count(*) from family_invites
      where owner_id = auth.uid() and used_by is null and expires_at > now()) >= 10 then
    raise exception 'You already have 10 open invites. Revoke one first.';
  end if;

  -- 12 hex chars from a random UUID: unguessable enough for a single-use,
  -- 7-day code, and still short enough to type in by hand.
  new_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
  insert into family_invites (code, owner_id) values (new_code, auth.uid());
  return new_code;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function create_family_invite() to authenticated;

-- ----------------------------------------------------------------------------
-- 2. Keep an explicitly linked user. The phone-matching trigger used to
--    overwrite contact_user_id on every insert, which would wipe the link
--    an invite sets when the invitee has no phone on file.
-- ----------------------------------------------------------------------------
create or replace function resolve_safety_circle_contact_user()
returns trigger as $$
begin
  if NEW.contact_user_id is null then
    select id into NEW.contact_user_id
    from profiles
    where phone = NEW.phone_number
    limit 1;
  end if;
  return NEW;
end;
$$ language plpgsql security definer set search_path = public;

-- ----------------------------------------------------------------------------
-- 3. Accepting an invite
-- ----------------------------------------------------------------------------
create or replace function accept_family_invite(invite_code text)
returns json as $$
declare
  inv      family_invites%rowtype;
  me       profiles%rowtype;
  inviter  text;
  link_id  uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in to accept a family invite';
  end if;

  select * into inv from family_invites
  where code = upper(trim(invite_code))
  for update;

  if not found then
    raise exception 'This invite link is not valid.';
  end if;
  if inv.used_by is not null then
    raise exception 'This invite link has already been used.';
  end if;
  if inv.expires_at < now() then
    raise exception 'This invite link has expired. Ask for a new one.';
  end if;
  if inv.owner_id = auth.uid() then
    raise exception 'This is your own invite link — share it with a family member.';
  end if;

  select full_name into inviter from profiles where id = inv.owner_id;

  -- Already linked in either direction? Don't create a second link.
  if exists (
    select 1 from safety_circle_contacts
    where status in ('pending', 'confirmed')
      and ((owner_id = inv.owner_id and contact_user_id = auth.uid())
        or (owner_id = auth.uid() and contact_user_id = inv.owner_id))
  ) then
    raise exception 'You are already in % family circle.',
      coalesce(inviter || '''s', 'this');
  end if;

  select * into me from profiles where id = auth.uid();

  insert into safety_circle_contacts
    (owner_id, name, phone_number, relationship, contact_user_id, status)
  values (
    inv.owner_id,
    coalesce(me.full_name, 'Family member'),
    coalesce(nullif(me.phone, ''), 'user:' || auth.uid()),
    'Family',
    auth.uid(),
    'pending'
  )
  on conflict (owner_id, phone_number) do update
    set contact_user_id = excluded.contact_user_id,
        name = excluded.name,
        status = 'pending'
  returning id into link_id;

  update family_invites
  set used_by = auth.uid(), used_at = now()
  where code = inv.code;

  return json_build_object('link_id', link_id, 'inviter_name', inviter);
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function accept_family_invite(text) to authenticated;

-- ----------------------------------------------------------------------------
-- 4. My family circle — both directions, with each confirmed member's
--    last-known location. Locations are only ever returned for confirmed
--    links. Scoped to auth.uid(), so a caller only sees their own circle.
-- ----------------------------------------------------------------------------
create or replace function my_family_circle()
returns table (
  link_id        uuid,
  member_id      uuid,
  name           text,
  status         text,
  invited_by_me  boolean,
  lat            double precision,
  lng            double precision,
  is_active      boolean,
  last_seen_at   timestamptz
) as $$
  with links as (
    select sc.id, sc.contact_user_id as member, sc.status, true as by_me
    from safety_circle_contacts sc
    where sc.owner_id = auth.uid() and sc.contact_user_id is not null
    union all
    select sc.id, sc.owner_id, sc.status, false
    from safety_circle_contacts sc
    where sc.contact_user_id = auth.uid() and sc.status = 'confirmed'
  )
  select l.id, l.member, coalesce(p.full_name, 'Family member'), l.status, l.by_me,
         ls.lat, ls.lng, ls.is_active, ls.updated_at
  from links l
  join profiles p on p.id = l.member
  left join lateral (
    select s.lat, s.lng, s.is_active, s.updated_at
    from location_shares s
    where s.owner_id = l.member
    order by s.updated_at desc
    limit 1
  ) ls on l.status = 'confirmed'
  where l.status in ('pending', 'confirmed')
  order by l.status = 'confirmed' desc, p.full_name;
$$ language sql stable security definer set search_path = public;

grant execute on function my_family_circle() to authenticated;

-- Either side can leave or remove a link.
create or replace function remove_family_member(target_link_id uuid)
returns void as $$
begin
  delete from safety_circle_contacts
  where id = target_link_id
    and (owner_id = auth.uid() or contact_user_id = auth.uid());
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function remove_family_member(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 5. Make confirmed links mutual for locations and "I'm safe" broadcasts.
-- ----------------------------------------------------------------------------
create or replace function is_confirmed_family(other uuid)
returns boolean as $$
  select exists (
    select 1 from safety_circle_contacts sc
    where sc.status = 'confirmed'
      and ((sc.owner_id = other and sc.contact_user_id = auth.uid())
        or (sc.owner_id = auth.uid() and sc.contact_user_id = other))
  );
$$ language sql stable security definer set search_path = public;

grant execute on function is_confirmed_family(uuid) to authenticated;

drop policy if exists "Circle members can view each other's shares" on location_shares;
create policy "Circle members can view each other's shares"
  on location_shares for select to authenticated
  using (owner_id = auth.uid() or is_confirmed_family(owner_id));

drop policy if exists "Circle members can view each other's broadcasts" on safety_broadcasts;
create policy "Circle members can view each other's broadcasts"
  on safety_broadcasts for select to authenticated
  using (user_id = auth.uid() or is_confirmed_family(user_id));
