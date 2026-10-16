-- ============================================================================
-- Incident heatmap: demo data to check it works
-- Run in the Supabase SQL Editor. Safe to re-run (it clears its own rows first).
--
-- The heatmap adds up nearby reports, so it only shows a hotspot where reports
-- are CLOSE TOGETHER. Scattered single reports are drawn as small green
-- circles with no link between them, which is what you see with random data.
-- This script adds clusters of different sizes plus a few lone reports, so you
-- can confirm the colours step up from green to red as reports pile up:
--
--   Kelaniya (flood zone)   14 reports, within ~700 m, 2 SOS  -> RED hotspot
--   Kolonnawa                8 reports, within ~600 m, 1 SOS  -> deep orange
--   Kalutara                 6 reports, within ~500 m         -> orange
--   Gampaha                  4 reports, within ~500 m         -> yellow-orange
--   Kandy, Galle, Matara,
--   Jaffna, Kegalle          1 report each, far apart         -> GREEN (isolated)
--
-- Every row's description starts with "[heatmap-demo]" so the cleanup at the
-- bottom removes exactly these and nothing else.
-- ============================================================================

-- 0. Remove any earlier run of this demo.
delete from incidents where description like '[heatmap-demo]%';

-- 1. Insert the clusters. Points are spread in a deterministic spiral (golden
--    angle), so the result is the same every time and clusters look natural.
with reporter as (
  select id
  from profiles
  order by (role = 'admin') desc, created_at
  limit 1
),
clusters (name, clat, clng, n, spread_deg, sos_every) as (
  values
    ('Kelaniya',  6.9553, 79.9220, 14, 0.0065, 7),
    ('Kolonnawa', 6.9340, 79.8860,  8, 0.0055, 8),
    ('Kalutara',  6.5854, 79.9607,  6, 0.0045, 0),
    ('Gampaha',   7.0917, 79.9999,  4, 0.0045, 0),
    ('Kandy',     7.2906, 80.6337,  1, 0.0,    0),
    ('Galle',     6.0535, 80.2210,  1, 0.0,    0),
    ('Matara',    5.9549, 80.5550,  1, 0.0,    0),
    ('Jaffna',    9.6615, 80.0255,  1, 0.0,    0),
    ('Kegalle',   7.2513, 80.3464,  1, 0.0,    0)
),
points as (
  select
    c.name,
    g.i,
    c.clat + c.spread_deg * sqrt(g.i::float / c.n) * sin(g.i * 2.399963) as lat,
    c.clng + c.spread_deg * sqrt(g.i::float / c.n) * cos(g.i * 2.399963)
             / cos(radians(c.clat)) as lng,
    (c.sos_every > 0 and g.i % c.sos_every = 0) as is_sos
  from clusters c
  cross join lateral generate_series(1, c.n) as g(i)
)
insert into incidents
  (reporter_id, category, description, location, status, is_sos,
   credibility_score, created_at, updated_at)
select
  (select id from reporter),
  case
    when p.is_sos then 'trapped_person'
    else (array['waterlogging', 'waterlogging', 'blocked_road',
                'power_outage', 'structural_damage'])[1 + (p.i % 5)]
  end,
  '[heatmap-demo] ' || p.name || ' report ' || p.i,
  ST_SetSRID(ST_MakePoint(p.lng, p.lat), 4326)::geography,
  case when p.i % 3 = 0 then 'pending' else 'verified' end,
  p.is_sos,
  (p.i * 2) % 11,
  now() - (p.i || ' hours')::interval,
  now() - (p.i || ' hours')::interval
from points p;

-- 2. Check: how many demo reports are within 1.5 km of each cluster centre.
--    The app's heatmap uses a 1.5 km reach, so these counts are what drive the
--    colour: about 10 ordinary reports overlapping reads as full red.
select
  c.name,
  count(i.*) as reports_within_1_5_km,
  count(i.*) filter (where i.is_sos) as sos
from (values
  ('Kelaniya',  6.9553, 79.9220),
  ('Kolonnawa', 6.9340, 79.8860),
  ('Kalutara',  6.5854, 79.9607),
  ('Gampaha',   7.0917, 79.9999),
  ('Kandy',     7.2906, 80.6337)
) as c(name, clat, clng)
left join incidents i
  on i.description like '[heatmap-demo]%'
 and ST_DWithin(i.location, ST_SetSRID(ST_MakePoint(c.clng, c.clat), 4326)::geography, 1500)
group by c.name
order by reports_within_1_5_km desc;

-- ============================================================================
-- CLEANUP: run this when you are done checking.
--   delete from incidents where description like '[heatmap-demo]%';
-- ============================================================================
