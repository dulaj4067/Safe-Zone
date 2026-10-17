-- Run after preparedness_hub_migration.sql to add explicitly fictional
-- disaster-history examples for demos and UI previews.
-- These are not historical events and must remain labeled as samples.
-- Existing rows are not overwritten, making this safe to re-run.

insert into preparedness_content (content_type, id, zone_id, payload)
values
  (
    'history',
    'sample-flood-practice',
    null,
    jsonb_build_object(
      'id', 'sample-flood-practice',
      'zoneId', null,
      'disasterType', 'Flood',
      'disasterSubtype', 'Illustrative scenario',
      'date', '2024-05',
      'datePrecision', 'month',
      'endDate', null,
      'endDatePrecision', 'day',
      'severity', null,
      'summary', 'Fictional sample record for previewing the history screen. Not based on a real event.',
      'eventName', 'Practice scenario A',
      'locationDescription', 'Fictional multi-district area',
      'sourceEventId', null,
      'sourceName', 'SafeZone demo sample',
      'sourceUrl', null,
      'sourceVersion', null,
      'totalDeaths', null,
      'totalInjured', null,
      'totalAffected', null,
      'totalHomeless', null,
      'adjustedDamageKusd', null,
      'isSample', true
    )
  ),
  (
    'history',
    'sample-storm-practice',
    null,
    jsonb_build_object(
      'id', 'sample-storm-practice',
      'zoneId', null,
      'disasterType', 'Storm',
      'disasterSubtype', 'Illustrative scenario',
      'date', '2023',
      'datePrecision', 'year',
      'endDate', null,
      'endDatePrecision', 'day',
      'severity', null,
      'summary', 'Fictional sample record for previewing the history screen. Not based on a real event.',
      'eventName', 'Practice scenario B',
      'locationDescription', 'Fictional coastal area',
      'sourceEventId', null,
      'sourceName', 'SafeZone demo sample',
      'sourceUrl', null,
      'sourceVersion', null,
      'totalDeaths', null,
      'totalInjured', null,
      'totalAffected', null,
      'totalHomeless', null,
      'adjustedDamageKusd', null,
      'isSample', true
    )
  ),
  (
    'history',
    'sample-landslide-practice',
    null,
    jsonb_build_object(
      'id', 'sample-landslide-practice',
      'zoneId', null,
      'disasterType', 'Landslide',
      'disasterSubtype', 'Illustrative scenario',
      'date', '2022-11-12T00:00:00.000',
      'datePrecision', 'day',
      'endDate', null,
      'endDatePrecision', 'day',
      'severity', null,
      'summary', 'Fictional sample record for previewing the history screen. Not based on a real event.',
      'eventName', 'Practice scenario C',
      'locationDescription', 'Fictional hillside area',
      'sourceEventId', null,
      'sourceName', 'SafeZone demo sample',
      'sourceUrl', null,
      'sourceVersion', null,
      'totalDeaths', null,
      'totalInjured', null,
      'totalAffected', null,
      'totalHomeless', null,
      'adjustedDamageKusd', null,
      'isSample', true
    )
  )
on conflict (content_type, id) do nothing;
