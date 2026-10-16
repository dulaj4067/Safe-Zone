-- ============================================================================
-- Demo data for a live walkthrough
-- Run in the Supabase SQL Editor. Safe to re-run: it removes its own rows first.
--
-- Fills the parts of the app that are empty on a fresh project so every screen
-- has something real to show:
--   Alerts ........ 3 active (green, yellow, orange) + 1 resolved. No red one by
--                   default: a red alert takes over the screen with a siren.
--                   Uncomment the red block below to demo that on purpose.
--   Shelters ...... 7 approved places across the country with capacity,
--                   occupancy, open/full/closed and supplies.
--   Volunteering .. 8 tasks (open, in progress, completed) with some sign-ups.
--   Feedback ...... 8 ratings with "what do you still need" notes.
--   Prep Hub ...... disaster history for three districts and an evacuation
--                   route plus a reminder for Colombo.
--
-- Incidents and the heatmap come from sql/heatmap_demo_data.sql (run that too).
-- Run after the other migrations. Needs at least one profile (an admin if
-- possible: shelters are assigned to it so you can show "manage your shelter").
-- Everything is removable with the CLEANUP block at the bottom.
-- ============================================================================

-- 0. Remove any earlier run.
delete from alerts where source = 'demo';
delete from volunteer_tasks where title in (
  'Sort and pack donated food', 'Evening meal service', 'Set up bedding and mats',
  'Medical point registration desk', 'Clear debris from the access road',
  'Translate announcements into Sinhala and Tamil', 'Drive supplies to Kalutara',
  'Shelter cleaning and sanitation');
delete from shelter_resources where shelter_id in (select id from shelters where name in (
  'Kelaniya Vidyalaya Relief Camp', 'Colombo Central Community Hall',
  'Gampaha District Hospital Medical Point', 'Kalutara Temple Shelter',
  'Kandy Town Hall Shelter', 'Galle Fort Community Centre', 'Matara Sports Complex Camp'));
delete from shelters where name in (
  'Kelaniya Vidyalaya Relief Camp', 'Colombo Central Community Hall',
  'Gampaha District Hospital Medical Point', 'Kalutara Temple Shelter',
  'Kandy Town Hall Shelter', 'Galle Fort Community Centre', 'Matara Sports Complex Camp');
delete from feedback_forms where needs in (
  'More drinking water and baby formula', 'Blankets, it gets cold at night',
  'Wheelchair access to the toilets', 'Medicine for diabetes', 'Mobile phone charging points',
  'Nothing urgent, thank you to the volunteers', 'Clearer signs showing where to register',
  'Sinhala and Tamil speaking staff');
delete from preparedness_content where id like 'demo-%';

do $$
declare
  admin_id   uuid;
  others     uuid[];
  z          record;
  zid        uuid;
  s_ids      uuid[] := '{}';
  sid        uuid;
  tid        uuid;
  i          int;
  rec        record;
  shelter_type_t   text;
  shelter_status_t text;
  task_status_t    text;
begin
  select format_type(atttypid, atttypmod) into shelter_type_t   from pg_attribute where attrelid = 'public.shelters'::regclass and attname = 'type';
  select format_type(atttypid, atttypmod) into shelter_status_t from pg_attribute where attrelid = 'public.shelters'::regclass and attname = 'status';
  select format_type(atttypid, atttypmod) into task_status_t    from pg_attribute where attrelid = 'public.volunteer_tasks'::regclass and attname = 'status';
  select id into admin_id from profiles order by (role = 'admin') desc, created_at limit 1;
  if admin_id is null then
    raise exception 'Create at least one account in the app first, then run this again.';
  end if;
  select coalesce(array_agg(id), '{}') into others
  from (select id from profiles where id <> admin_id order by created_at limit 6) o;

  -- ------------------------------------------------------------------ alerts
  -- affected_zone_id is looked up by district name (zones are called e.g.
  -- 'Colombo District', so the match is a prefix); centre points are the
  -- district capitals, radius in metres.
  insert into alerts (title, alert_type, severity, status, affected_zone_id, center_point,
                      radius_meters, instructions, source, created_by, created_at, updated_at)
  values
    ('Heavy rain advisory: Colombo District', 'flood', 'yellow', 'active',
     (select id from zones where name ilike 'Colombo%' limit 1),
     'SRID=4326;POINT(79.8612 6.9271)', 9000,
     'Heavy rain expected through the evening. Avoid low-lying roads and keep drains clear. Charge your phone and keep documents in a dry bag.',
     'demo', admin_id, now() - interval '50 minutes', now() - interval '50 minutes'),
    ('Flood warning: Kelaniya river basin', 'flood', 'orange', 'active',
     (select id from zones where name ilike 'Gampaha%' limit 1),
     'SRID=4326;POINT(79.9220 6.9553)', 6000,
     'The Kelani river is rising. Residents near the river should move valuables upstairs and prepare to leave. Shelters at Kelaniya Vidyalaya and Colombo Central Hall are open.',
     'demo', admin_id, now() - interval '25 minutes', now() - interval '25 minutes'),
    ('Water levels normal: Kalutara', 'flood', 'green', 'active',
     (select id from zones where name ilike 'Kalutara%' limit 1),
     'SRID=4326;POINT(79.9607 6.5854)', 7000,
     'River levels have dropped to normal. No action needed; stay tuned for updates.',
     'demo', admin_id, now() - interval '3 hours', now() - interval '3 hours');

  insert into alerts (title, alert_type, severity, status, affected_zone_id, center_point,
                      radius_meters, instructions, source, created_by, created_at, updated_at, resolved_at)
  values
    ('Landslide warning: Kandy hills (lifted)', 'landslide', 'orange', 'de_escalated',
     (select id from zones where name ilike 'Kandy%' limit 1),
     'SRID=4326;POINT(80.6337 7.2906)', 5000,
     'Warning lifted: slopes are stable after the rain stopped.',
     'demo', admin_id, now() - interval '2 days', now() - interval '1 day', now() - interval '1 day');

  -- To demo the full-screen red takeover with siren, uncomment and run only
  -- this statement, then resolve it from the Dashboard when finished:
  -- insert into alerts (title, alert_type, severity, status, affected_zone_id, center_point,
  --                     radius_meters, instructions, source, created_by)
  -- values ('Evacuate now: Kelaniya flood', 'flood', 'red', 'active',
  --         (select id from zones where name ilike 'Gampaha%' limit 1),
  --         'SRID=4326;POINT(79.9220 6.9553)', 5000,
  --         'Water is entering homes. Leave now for Kelaniya Vidyalaya Relief Camp. Do not walk or drive through floodwater.',
  --         'demo', admin_id);

  -- ---------------------------------------------------------------- shelters
  for rec in
    select * from (values
      ('Kelaniya Vidyalaya Relief Camp',          'relief_camp',   6.9553, 79.9220, 300, 182, 'open',   'Kelaniya Vidyalaya, Kelaniya',          '0112 911 234', 'School hall and grounds. Separate family and elderly areas.'),
      ('Colombo Central Community Hall',          'shelter',       6.9271, 79.8612, 200, 200, 'full',   'Town Hall Road, Colombo 07',            '0112 686 868', 'Large hall with kitchen. Currently full: please use another shelter.'),
      ('Gampaha District Hospital Medical Point', 'medical_point', 7.0917, 79.9999,  60,  24, 'open',   'Hospital Road, Gampaha',                '0332 222 261', 'First aid, medicine and nurse on duty around the clock.'),
      ('Kalutara Temple Shelter',                 'shelter',       6.5854, 79.9607, 250,  90, 'open',   'Temple Road, Kalutara South',           '0342 222 500', 'Temple grounds with covered area, water tank and kitchen.'),
      ('Kandy Town Hall Shelter',                 'shelter',       7.2906, 80.6337, 150,  20, 'open',   'Dalada Veediya, Kandy',                 '0812 222 224', 'Hall on high ground, well above flood level.'),
      ('Galle Fort Community Centre',             'shelter',       6.0535, 80.2210, 180,   0, 'closed', 'Church Street, Galle Fort',             '0912 234 000', 'Closed for maintenance; reopens if the weather worsens.'),
      ('Matara Sports Complex Camp',              'relief_camp',   5.9549, 80.5550, 400, 150, 'open',   'Stadium Road, Matara',                  '0412 222 345', 'Indoor courts used as dormitories. Toilets and showers on site.')
    ) as t(name, type, lat, lng, capacity, occupancy, status, address, phone, description)
  loop
    -- type / status may be enums or plain text depending on the database, so
    -- cast each value to the column's real type (same trick as heatmap_demo_data).
    execute format(
      'insert into shelters (name, type, location, capacity, occupancy, status, address,
                             description, contact_phone, approval_status, submitted_by, managed_by)
       values ($1, $2::%s, ST_SetSRID(ST_MakePoint($3, $4), 4326), $5, $6, $7::%s, $8, $9, $10,
               ''approved'', $11, $11)
       returning id', shelter_type_t, shelter_status_t)
    into sid
    using rec.name, rec.type, rec.lng, rec.lat, rec.capacity, rec.occupancy, rec.status,
          rec.address, rec.description, rec.phone, admin_id;
    s_ids := s_ids || sid;

    -- Supplies scaled to how busy the shelter is; Colombo is nearly out of water.
    -- Plain insert: the shelter is brand new (its old rows were deleted above), and
    -- some databases lack the (shelter_id, resource_type) unique constraint.
    insert into shelter_resources (shelter_id, resource_type, quantity, unit) values
      (sid, 'water',    case when rec.name like 'Colombo%' then 40   else greatest(300, rec.capacity * 6) end, 'liters'),
      (sid, 'food',     case when rec.name like 'Colombo%' then 120  else greatest(400, rec.capacity * 4) end, 'meals'),
      (sid, 'medicine', case when rec.type = 'medical_point' then 80 else 12 end,                          'kits'),
      (sid, 'bedding',  greatest(60, rec.capacity - rec.occupancy),                                       'mats'),
      (sid, 'other',    25,                                                                              'units');
  end loop;

  -- ------------------------------------------------------------ volunteering
  -- shelter order: 1 Kelaniya, 2 Colombo, 3 Gampaha, 4 Kalutara, 5 Kandy, 6 Galle, 7 Matara
  for rec in
    select * from (values
      ('Sort and pack donated food',                    'Sort donations by type and pack family food parcels. No experience needed.',                  1, 6, 'open',        2),
      ('Evening meal service',                          'Help serve and clean up the evening meal for about 180 people.',                              1, 4, 'in_progress', 4),
      ('Set up bedding and mats',                       'Unpack and lay out mats and blankets in the hall before nightfall.',                          4, 5, 'open',        1),
      ('Medical point registration desk',               'Register arrivals and note medical needs. Basic first aid training preferred.',               3, 3, 'open',        3),
      ('Clear debris from the access road',             'Clear branches and mud so ambulances can reach the camp. Gloves and boots provided.',         7, 8, 'in_progress', 5),
      ('Translate announcements into Sinhala and Tamil','Translate shelter announcements and help families who do not speak English.',                  2, 2, 'open',        0),
      ('Drive supplies to Kalutara',                    'Drive a van of water and food from the Colombo depot. Licence and own phone required.',        4, 2, 'completed',   2),
      ('Shelter cleaning and sanitation',               'Clean toilets and common areas twice a day. Supplies on site.',                                7, 6, 'open',        2)
    ) as t(title, descr, shelter_no, needed, status, signed)
  loop
    execute format(
      'insert into volunteer_tasks (title, description, shelter_id, volunteers_needed, status, created_by)
       values ($1, $2, $3, $4, $5::%s, $6) returning id', task_status_t)
    into tid
    using rec.title, rec.descr, s_ids[rec.shelter_no], rec.needed, rec.status, admin_id;

    -- Sign-ups from other accounts (if there are any); the admin joins one.
    i := 0;
    while i < rec.signed and i < coalesce(array_length(others, 1), 0) loop
      insert into volunteer_assignments (task_id, volunteer_id)
      values (tid, others[i + 1]) on conflict do nothing;
      i := i + 1;
    end loop;
  end loop;

  -- ---------------------------------------------------------------- feedback
  select id into zid from zones where name ilike 'Gampaha%' limit 1;
  for rec in
    select * from (values
      (5, 'Nothing urgent, thank you to the volunteers',      'Gampaha'),
      (4, 'Clearer signs showing where to register',          'Colombo'),
      (2, 'More drinking water and baby formula',             'Gampaha'),
      (3, 'Blankets, it gets cold at night',                  'Kalutara'),
      (2, 'Wheelchair access to the toilets',                 'Colombo'),
      (3, 'Medicine for diabetes',                            'Gampaha'),
      (4, 'Mobile phone charging points',                     'Kandy'),
      (3, 'Sinhala and Tamil speaking staff',                 'Colombo')
    ) as t(rating, needs, district)
  loop
    insert into feedback_forms (submitted_by, rating, needs, zone_id)
    values (coalesce(others[1 + (rec.rating % greatest(coalesce(array_length(others, 1), 1), 1))], admin_id),
            rec.rating, rec.needs,
            (select id from zones where name ilike rec.district || '%' limit 1));
  end loop;

  -- --------------------------------------------------------- preparedness hub
  -- Content rows are keyed (content_type, id); zoneId in the payload is text.
  for z in select id, name from zones where name ilike any (array['Colombo%', 'Gampaha%', 'Kalutara%']) loop
    insert into preparedness_content (content_type, id, zone_id, payload, updated_by) values
      ('history', 'demo-history-' || split_part(lower(z.name), ' ', 1) || '-2024', z.id::text,
       jsonb_build_object(
         'id', 'demo-history-' || split_part(lower(z.name), ' ', 1) || '-2024',
         'zoneId', z.id::text,
         'disasterType', 'Flood',
         'date', '2024-06-03T00:00:00.000Z',
         'severity', case split_part(z.name, ' ', 1) when 'Colombo' then 'high' when 'Gampaha' then 'severe' else 'moderate' end,
         'summary', 'Monsoon floods after several days of heavy rain. Low-lying roads closed and families moved to relief camps in ' || z.name || '.'),
       admin_id),
      ('history', 'demo-history-' || split_part(lower(z.name), ' ', 1) || '-2017', z.id::text,
       jsonb_build_object(
         'id', 'demo-history-' || split_part(lower(z.name), ' ', 1) || '-2017',
         'zoneId', z.id::text,
         'disasterType', 'Flood and landslide',
         'date', '2017-05-26T00:00:00.000Z',
         'severity', 'severe',
         'summary', 'One of the worst floods in a generation. Rivers broke their banks; thousands were evacuated across the Western Province.'),
       admin_id);
  end loop;

  select id into zid from zones where name ilike 'Colombo%' limit 1;
  if zid is not null then
    insert into preparedness_content (content_type, id, zone_id, payload, updated_by) values
      ('route', 'demo-route-colombo', zid::text,
       jsonb_build_object(
         'id', 'demo-route-colombo',
         'zoneId', zid::text,
         'startPoint', jsonb_build_object('latitude', 6.9344, 'longitude', 79.8428),
         'safeZonePoint', jsonb_build_object('latitude', 6.9022, 'longitude', 79.8610),
         'routePolyline', jsonb_build_array(
           jsonb_build_object('latitude', 6.9344, 'longitude', 79.8428),
           jsonb_build_object('latitude', 6.9290, 'longitude', 79.8480),
           jsonb_build_object('latitude', 6.9180, 'longitude', 79.8530),
           jsonb_build_object('latitude', 6.9100, 'longitude', 79.8580),
           jsonb_build_object('latitude', 6.9022, 'longitude', 79.8610)),
         'instructions', jsonb_build_array(
           'Leave Pettah on Main Street heading south.',
           'Turn onto Galle Road and keep to the higher inland side.',
           'Avoid the canal-side roads, which flood first.',
           'Continue to the community hall at Bambalapitiya and register at the desk.'),
         'lastUpdated', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS".000Z"')),
       admin_id),
      ('reminder', 'demo-reminder-monsoon', zid::text,
       jsonb_build_object(
         'id', 'demo-reminder-monsoon',
         'title', 'Check your emergency kit before the monsoon',
         'message', 'Refresh drinking water, test your torch batteries and make sure documents are in a waterproof bag.',
         'scheduledDate', to_char((now() + interval '14 days') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS".000Z"'),
         'recurrence', 'seasonal',
         'zoneTags', jsonb_build_array(zid::text)),
       admin_id);
  end if;
end $$;

-- Check what was added.
select 'alerts' as what, count(*) from alerts where source = 'demo'
union all select 'shelters', count(*) from shelters where name like any (array[
  'Kelaniya Vidyalaya%', 'Colombo Central%', 'Gampaha District%', 'Kalutara Temple%',
  'Kandy Town%', 'Galle Fort%', 'Matara Sports%'])
union all select 'volunteer tasks', count(*) from volunteer_tasks
  where title in ('Sort and pack donated food', 'Evening meal service', 'Drive supplies to Kalutara')
union all select 'hub content', count(*) from preparedness_content where id like 'demo-%';

-- ============================================================================
-- CLEANUP (run when you are done):
--   delete from alerts where source = 'demo';
--   delete from preparedness_content where id like 'demo-%';
--   delete from volunteer_tasks where title in ('Sort and pack donated food', 'Evening meal service',
--     'Set up bedding and mats', 'Medical point registration desk', 'Clear debris from the access road',
--     'Translate announcements into Sinhala and Tamil', 'Drive supplies to Kalutara', 'Shelter cleaning and sanitation');
--   (then re-run section 0 above for shelters, supplies and feedback)
-- ============================================================================
