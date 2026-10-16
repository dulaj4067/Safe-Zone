-- Run after preparedness_hub_migration.sql to seed editable, shared starter guides.
-- Existing guides are not overwritten, including authority edits and archives.

insert into preparedness_content (content_type, id, payload)
select
  'guide',
  guide.id,
  jsonb_build_object(
    'id', guide.id,
    'title', guide.title,
    'category', guide.category,
    'bodyContent', guide.body_content,
    'coverImageUrl', '',
    'zoneTags', '[]'::jsonb,
    'createdBy', 'preparedness-team',
    'createdAt', '2026-01-01T00:00:00.000Z',
    'updatedAt', '2026-01-01T00:00:00.000Z',
    'isArchived', false
  )
from (
  values
    (
      'starter-guide-flood',
      'Flood safety: before, during, and after',
      'flood',
      $guide$# Flood safety

## Before flooding
- Follow local weather and authority alerts. Know your evacuation route and where higher ground is.
- Keep medicines, drinking water, a flashlight, a phone charger, and important documents ready to take with you.
- Move valuables and electrical items above expected flood levels if it is safe to do so.

## During flooding
- Evacuate promptly when authorities advise it. Move to higher ground and follow official routes.
- Never walk, swim, or drive through floodwater. It can hide hazards and move people or vehicles.
- If water is entering your home, move to a higher level and contact emergency services when safe.
- Do not touch electrical equipment while standing in water.

## After flooding
- Return only when authorities say it is safe. Avoid floodwater and damaged buildings.
- Treat water and food exposed to floodwater as unsafe until official guidance says otherwise.$guide$
    ),
    (
      'starter-guide-fire',
      'Fire safety and evacuation',
      'fire',
      $guide$# Fire safety

## Be ready
- Identify two ways out of rooms where possible and agree on a meeting place outside.
- Keep exits clear and make sure everyone knows how to raise the alarm.
- Store matches, lighters, and flammable materials safely.

## If there is a fire
- Raise the alarm, leave immediately, and call the fire service from a safe place.
- Stay low under smoke. Use stairs, not lifts, and do not stop to collect belongings.
- If a door is hot or smoke is coming through it, use another exit. If trapped, close the door, block smoke gaps if possible, and signal for help.
- Never re-enter a burning building.

Follow emergency-service instructions and do not attempt to fight a fire that is spreading or blocking your exit.$guide$
    ),
    (
      'starter-guide-earthquake',
      'Earthquake safety',
      'earthquake',
      $guide$# Earthquake safety

## During shaking
- Drop, cover, and hold on. Get under sturdy furniture if available and protect your head and neck.
- Stay indoors away from windows until shaking stops. Do not use lifts.
- If outdoors, move to an open area away from buildings, trees, and power lines.
- If in a vehicle, stop in a clear place and remain inside until shaking stops.

## After shaking
- Expect aftershocks. Check for injuries and provide help only when it is safe.
- Leave damaged buildings carefully and move away from walls and overhead hazards.
- If you smell gas or see damaged electrical lines, move away and report the danger; do not operate switches or use flames.
- Follow official updates and use text messages where possible to keep phone networks available.$guide$
    ),
    (
      'starter-guide-landslide',
      'Landslide awareness and response',
      'landslide',
      $guide$# Landslide safety

## Be alert
- Pay attention to official warnings, especially during and after prolonged or heavy rain.
- Watch for new ground cracks, leaning trees or poles, unusual water flow, or rumbling sounds near slopes.
- Know safer places and evacuation routes away from steep slopes and drainage channels.

## If a slide may be happening
- Move away from the path of the slide immediately, following local emergency guidance.
- Do not cross an active slide area. If escape is not possible, protect your head and curl into a ball.
- Warn others only if doing so does not delay your escape, then contact emergency services from a safe location.

Do not return until authorities have assessed the area and said it is safe.$guide$
    ),
    (
      'starter-guide-tsunami',
      'Tsunami warning and evacuation',
      'tsunami',
      $guide$# Tsunami safety

## Know when to move
- A strong or long earthquake near the coast, unusual sea-level changes, or a loud ocean roar can be natural warning signs.
- If you are near the coast and notice these signs, move immediately to higher ground or inland. Do not wait to see a wave.
- Follow marked evacuation routes and official tsunami alerts.

## During a warning
- Stay away from beaches, river mouths, and low-lying coastal areas.
- If you are on a boat, follow advice from maritime and emergency authorities; do not return to shore during a warning.
- Help children and people needing assistance if you can do so without delaying evacuation.

Remain in a safe location until authorities issue an all-clear. The first wave may not be the largest.$guide$
    ),
    (
      'starter-guide-cyclone',
      'Cyclone and severe weather readiness',
      'cyclone',
      $guide$# Cyclone and severe weather safety

## Before severe weather
- Monitor official forecasts and evacuation instructions.
- Secure loose outdoor objects if it is safe and prepare water, medicines, a flashlight, and charged devices.
- Identify a sturdy shelter away from windows and know how to reach it.

## During severe weather
- Stay inside, away from windows and glass. Do not go outside during a temporary lull; conditions may worsen again.
- If authorities order evacuation, leave promptly using the recommended route.
- Avoid flooded roads, fallen power lines, and damaged structures.

## After the weather passes
- Wait for the official all-clear. Report hazards to authorities and keep clear of downed lines.
- Use generators only outdoors and away from doors and windows, following the manufacturer's safety directions.$guide$
    )
) as guide(id, title, category, body_content)
on conflict (content_type, id) do nothing;
