-- ============================================================================
-- Fires the notify-safety-circle-request Edge Function whenever a
-- safety_circle_contacts row becomes 'pending' with a resolved
-- contact_user_id — i.e. someone just added a real registered user to
-- their circle and that person needs to confirm before any location is
-- ever exposed to the owner. Covers both the initial insert and the later
-- "relink" case (phone number matches a user who registers afterwards).
--
-- Requires sql/safety_circle_consent_migration.sql to have been run first.
-- Before running: replace <SAFETY_CIRCLE_WEBHOOK_SECRET> below with the same
-- value set as the Edge Function secret SAFETY_CIRCLE_WEBHOOK_SECRET.
-- Run this once in the Safe-Zone Supabase project's SQL Editor.
-- ============================================================================

create extension if not exists pg_net;

create or replace function notify_safety_circle_pending()
returns trigger as $$
begin
  if NEW.status = 'pending' and NEW.contact_user_id is not null then
    perform net.http_post(
      url := 'https://frkwsgriwdezkvrmgsgf.supabase.co/functions/v1/notify-safety-circle-request',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', '<SAFETY_CIRCLE_WEBHOOK_SECRET>'
      ),
      body := jsonb_build_object('contact_id', NEW.id)
    );
  end if;
  return NEW;
end;
$$ language plpgsql security definer set search_path = public, net;

drop trigger if exists trg_notify_safety_circle_pending on safety_circle_contacts;
create trigger trg_notify_safety_circle_pending
  after insert or update of status, contact_user_id on safety_circle_contacts
  for each row
  execute function notify_safety_circle_pending();
