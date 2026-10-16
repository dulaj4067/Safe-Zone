-- Run after preparedness_hub_migration.sql to add editable starter checklist items.
-- Existing rows are preserved so authority edits are not overwritten.

insert into preparedness_content (
  content_type,
  id,
  zone_id,
  payload
)
values
  (
    'checklist_item',
    'starter-checklist-emergency-contacts',
    null,
    jsonb_build_object(
      'id', 'starter-checklist-emergency-contacts',
      'title', 'Keep emergency contacts available',
      'description', 'Write down important contacts and make sure household members know where to find them.',
      'riskFactorTags', array[]::text[],
      'isDone', false
    )
  ),
  (
    'checklist_item',
    'starter-checklist-household-meeting-place',
    null,
    jsonb_build_object(
      'id', 'starter-checklist-household-meeting-place',
      'title', 'Agree on a household meeting place',
      'description', 'Choose a safe place to meet if household members become separated.',
      'riskFactorTags', array[]::text[],
      'isDone', false
    )
  ),
  (
    'checklist_item',
    'starter-checklist-essential-supplies',
    null,
    jsonb_build_object(
      'id', 'starter-checklist-essential-supplies',
      'title', 'Prepare essential emergency supplies',
      'description', 'Keep basic supplies, a flashlight, and necessary personal items easy to access.',
      'riskFactorTags', array[]::text[],
      'isDone', false
    )
  ),
  (
    'checklist_item',
    'starter-checklist-important-documents',
    null,
    jsonb_build_object(
      'id', 'starter-checklist-important-documents',
      'title', 'Keep important documents accessible',
      'description', 'Store important documents securely and make copies available if you need to leave quickly.',
      'riskFactorTags', array[]::text[],
      'isDone', false
    )
  ),
  (
    'checklist_item',
    'starter-checklist-flood-route',
    null,
    jsonb_build_object(
      'id', 'starter-checklist-flood-route',
      'title', 'Know your local flood evacuation route',
      'description', 'Check the evacuation guidance provided by your local authority and identify a safe route.',
      'riskFactorTags', array['riverside', 'low-lying'],
      'isDone', false
    )
  ),
  (
    'checklist_item',
    'starter-checklist-household-support',
    null,
    jsonb_build_object(
      'id', 'starter-checklist-household-support',
      'title', 'Plan support for household members who need assistance',
      'description', 'Discuss communication, mobility, equipment, and transport needs with the people who may help.',
      'riskFactorTags', array['elderly-household', 'disabled-household'],
      'isDone', false
    )
  ),
  (
    'checklist_item',
    'starter-checklist-no-vehicle-transport',
    null,
    jsonb_build_object(
      'id', 'starter-checklist-no-vehicle-transport',
      'title', 'Plan transport if you do not have a vehicle',
      'description', 'Ask your local authority about available evacuation transport and how to request assistance.',
      'riskFactorTags', array['no-vehicle'],
      'isDone', false
    )
  ),
  (
    'checklist_item',
    'starter-checklist-large-household-checkin',
    null,
    jsonb_build_object(
      'id', 'starter-checklist-large-household-checkin',
      'title', 'Create a household check-in plan',
      'description', 'Choose how household members will contact each other and share updates during an emergency.',
      'riskFactorTags', array['large-household'],
      'isDone', false
    )
  )
on conflict (content_type, id) do nothing;
