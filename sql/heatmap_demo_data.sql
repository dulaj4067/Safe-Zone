-- ============================================================================
-- Incident heatmap: demo data to check it works
-- Run in the Supabase SQL Editor. Safe to re-run (it clears its own rows first).
--
-- HOW THE HEATMAP COUNTS REPORTS (see lib/widgets/heatmap_layer.dart)
--   Each report heats a circle about 1.5 km around it; nearby reports add up.
--   How much one report adds depends on whether it is confirmed:
--     verified by an authority ....... 1.0  (+0.1 per community confirmation, max +0.5)
--     pending, no confirmations ...... 0.2  (barely there)
--     pending + community confirms ... 0.2 + 0.2 per confirmation, up to 1.0
--                                      (4 neighbours confirming = as strong as verified)
--     rejected or resolved ........... 0    (no heat at all)
--     SOS / trapped person ........... x1.5
--   Colour from the total at a spot (weights above summed over nearby reports):
--   under 2.5 green · 2.5 yellow · 5.5 orange · 8+ red (full red at 10).
--   So about 3 confirmed reports start to show yellow, 6 orange, 8-10 red.
--
-- WHAT THIS SCRIPT ADDS (all descriptions start with "[heatmap-demo]")
--   Kelaniya   16 reports: 10 verified (2 SOS, some community-confirmed),
--              3 pending with 2/3/4 community confirmations,
--              2 resolved + 1 rejected (should add NO heat)        -> RED hotspot
--   Kolonnawa   5 pending, NOT yet verified but community-confirmed 2-4 times
--                                                                  -> amber (community-only)
--   Kalutara    6 pending with ZERO confirmations                  -> stays GREEN
--   Gampaha     4 verified                                         -> amber/yellow
--   Kandy, Galle, Matara, Jaffna, Kegalle: 1 verified each         -> green (isolated)
--
-- Community confirmations are inserted into incident_confirmations using other
-- existing profiles (never the reporter). The credibility_score is then set by
-- the database trigger. If you have fewer than 4 other profiles, each report
-- gets as many confirmations as there are profiles (a NOTICE says so).
-- ============================================================================

-- 0. Remove any earlier run (confirmations go with their incidents).
delete from incidents where description like '[heatmap-demo]%';

-- 1. Insert incidents and their community confirmations.
do $$
declare
  rep       uuid;
  members   uuid[];
  n_members int;
  inc       uuid;
  rec       record;
  k         int;
  want      int;
  capped    boolean := false;
begin
  -- The reporter: an admin profile if there is one.
  select id into rep from profiles order by (role = 'admin') desc, created_at limit 1;
  -- Up to 6 other profiles to act as confirming community members.
  select coalesce(array_agg(id), '{}') into members
  from (select id from profiles where id <> rep order by created_at limit 6) m;
  n_members := coalesce(array_length(members, 1), 0);

  for rec in
    with clusters (name, clat, clng, n, spread_deg) as (
      values
        ('Kelaniya',  6.9553, 79.9220, 16, 0.0065),
        ('Kolonnawa', 6.9340, 79.8860,  5, 0.0055),
        ('Kalutara',  6.5854, 79.9607,  6, 0.0045),
        ('Gampaha',   7.0917, 79.9999,  4, 0.0045),
        ('Kandy',     7.2906, 80.6337,  1, 0.0),
        ('Galle',     6.0535, 80.2210,  1, 0.0),
        ('Matara',    5.9549, 80.5550,  1, 0.0),
        ('Jaffna',    9.6615, 80.0255,  1, 0.0),
        ('Kegalle',   7.2513, 80.3464,  1, 0.0)
    ),
    pts as (
      select
        c.name, g.i,
        -- deterministic golden-angle spiral: same layout every run
        c.clat + c.spread_deg * sqrt(g.i::float / c.n) * sin(g.i * 2.399963) as lat,
        c.clng + c.spread_deg * sqrt(g.i::float / c.n) * cos(g.i * 2.399963)
                 / cos(radians(c.clat)) as lng
      from clusters c
      cross join lateral generate_series(1, c.n) as g(i)
    )
    select
      p.name, p.i, p.lat, p.lng,
      -- status
      case
        when p.name = 'Kelaniya' and p.i <= 10 then 'verified'
        when p.name = 'Kelaniya' and p.i <= 13 then 'pending'
        when p.name = 'Kelaniya' and p.i <= 15 then 'resolved'
        when p.name = 'Kelaniya'                then 'rejected'
        when p.name in ('Kolonnawa', 'Kalutara') then 'pending'
        else 'verified'
      end as status,
      -- SOS reports at Kelaniya
      (p.name = 'Kelaniya' and p.i in (5, 9)) as is_sos,
      -- community confirmations wanted for this report
      case
        when p.name = 'Kelaniya' and p.i between 11 and 13 then p.i - 9      -- 2, 3, 4
        when p.name = 'Kelaniya' and p.i <= 10 and p.i % 4 = 0 then 2        -- a few verified ones too
        when p.name = 'Kolonnawa' then (array[3, 4, 3, 4, 2])[p.i]
        else 0
      end as confirms
    from pts p
    order by p.name, p.i
  loop
    insert into incidents
      (reporter_id, category, description, location, status, is_sos,
       credibility_score, created_at, updated_at)
    values (
      rep,
      case
        when rec.is_sos then 'trapped_person'
        else (array['waterlogging', 'waterlogging', 'blocked_road',
                    'power_outage', 'structural_damage'])[1 + (rec.i % 5)]
      end,
      '[heatmap-demo] ' || rec.name || ' report ' || rec.i || ' (' || rec.status ||
        case when rec.confirms > 0 then ', ' || rec.confirms || ' community confirmations' else '' end || ')',
      ST_SetSRID(ST_MakePoint(rec.lng, rec.lat), 4326)::geography,
      rec.status,
      rec.is_sos,
      0,
      now() - (rec.i || ' hours')::interval,
      now() - (rec.i || ' hours')::interval
    )
    returning id into inc;

    -- Community confirmations; the trigger keeps credibility_score in step.
    want := least(rec.confirms, n_members);
    if want < rec.confirms then capped := true; end if;
    for k in 1..want loop
      insert into incident_confirmations (incident_id, member_id) values (inc, members[k]);
    end loop;
  end loop;

  if capped then
    raise notice 'Only % other profiles exist, so some reports got fewer confirmations than planned.', n_members;
  end if;
end $$;

-- Make credibility_score exactly the number of confirmations, whatever other
-- triggers the database has (one of them may also bump it).
update incidents i
set credibility_score = (select count(*) from incident_confirmations c where c.incident_id = i.id)
where i.description like '[heatmap-demo]%';

-- 2. Check what was inserted: reports per cluster by status, with the
--    confirmation counts the heatmap will see.
select
  split_part(substring(description from '\[heatmap-demo\] (\w+)'), ' ', 1) as cluster,
  status,
  count(*)                       as reports,
  coalesce(sum(credibility_score), 0) as community_confirmations,
  count(*) filter (where is_sos) as sos
from incidents
where description like '[heatmap-demo]%'
group by 1, 2
order by 1, 2;

-- ============================================================================
-- CLEANUP: run this when you are done checking.
--   delete from incidents where description like '[heatmap-demo]%';
-- ============================================================================
