-- ============================================================================
-- Zones = the 25 districts of Sri Lanka (Oct 2026)
--
-- The zones table was an ad-hoc list (10 towns + 3 test zones) that left most
-- of the country uncovered, so "My zone alerts only" and the map's area label
-- only worked near those towns. This replaces it with one zone per district.
--
--   1. Inserts the 25 districts (centroid = the district capital).
--   2. Moves every reference (profiles, alerts, caches, tasks, feedback,
--      preparedness content, location shares, "I'm Safe" marks) from each old
--      zone to its district, using the district named in the old zone's
--      `region`; the three test zones near Ampara go to Ampara District.
--   3. Deletes the old zones once nothing points at them.
--
-- Alerts keep their own centre point and radius, so targeting by distance is
-- unchanged. Idempotent: safe to re-run.
-- ============================================================================

begin;

create temp table _districts (name text primary key, province text, lat double precision, lng double precision)
on commit drop;

insert into _districts values
  ('Colombo',      'Western',        6.9271, 79.8612),
  ('Gampaha',      'Western',        7.0873, 79.9990),
  ('Kalutara',     'Western',        6.5854, 79.9607),
  ('Kandy',        'Central',        7.2906, 80.6337),
  ('Matale',       'Central',        7.4675, 80.6234),
  ('Nuwara Eliya', 'Central',        6.9497, 80.7891),
  ('Galle',        'Southern',       6.0535, 80.2210),
  ('Matara',       'Southern',       5.9549, 80.5550),
  ('Hambantota',   'Southern',       6.1241, 81.1185),
  ('Jaffna',       'Northern',       9.6615, 80.0255),
  ('Kilinochchi',  'Northern',       9.3803, 80.3770),
  ('Mannar',       'Northern',       8.9810, 79.9044),
  ('Vavuniya',     'Northern',       8.7514, 80.4971),
  ('Mullaitivu',   'Northern',       9.2671, 80.8142),
  ('Batticaloa',   'Eastern',        7.7310, 81.6747),
  ('Ampara',       'Eastern',        7.2975, 81.6820),
  ('Trincomalee',  'Eastern',        8.5874, 81.2152),
  ('Kurunegala',   'North Western',  7.4863, 80.3647),
  ('Puttalam',     'North Western',  8.0362, 79.8283),
  ('Anuradhapura', 'North Central',  8.3114, 80.4037),
  ('Polonnaruwa',  'North Central',  7.9403, 81.0188),
  ('Badulla',      'Uva',            6.9934, 81.0550),
  ('Monaragala',   'Uva',            6.8728, 81.3507),
  ('Ratnapura',    'Sabaragamuwa',   6.6828, 80.3992),
  ('Kegalle',      'Sabaragamuwa',   7.2513, 80.3464);

-- 1. District zones
insert into zones (name, region, centroid)
select d.name || ' District', d.province || ' Province',
       st_setsrid(st_makepoint(d.lng, d.lat), 4326)
from _districts d
where not exists (select 1 from zones z where z.name = d.name || ' District');

-- 2. Old zone -> district
create temp table _zone_map on commit drop as
select old.id as old_id, dz.id as new_id
from zones old
join _districts d
  on old.region = d.name || ' District'
  or (old.name like 'Zone _ - %' and d.name = 'Ampara')
join zones dz on dz.name = d.name || ' District'
where old.name not like '% District';

do $$
declare
  ref record;
  unmapped int;
begin
  select count(*) into unmapped
  from zones z
  where z.name not like '% District'
    and not exists (select 1 from _zone_map m where m.old_id = z.id);
  if unmapped > 0 then
    raise exception '% old zone(s) have no district mapping — check their region before re-running', unmapped;
  end if;

  -- One cache row per zone: several old zones can merge into one district,
  -- so drop their cached copies (regenerated from alerts) instead of moving.
  delete from alert_offline_cache c using _zone_map m where c.zone_id = m.old_id;

  for ref in
    select c.conrelid::regclass::text as tbl, a.attname as col
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    where c.contype = 'f' and c.confrelid = 'public.zones'::regclass
  loop
    execute format(
      'update %s t set %I = m.new_id from _zone_map m where t.%I = m.old_id',
      ref.tbl, ref.col, ref.col
    );
  end loop;
end $$;

-- 3. Remove the old zones
delete from zones z using _zone_map m where z.id = m.old_id;

commit;
