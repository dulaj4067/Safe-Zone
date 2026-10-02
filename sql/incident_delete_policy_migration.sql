-- ============================================================================
-- Let citizens delete their own incident reports.
-- Run this in the Supabase SQL Editor.
--
-- The app offers "Delete Incident Report" to a report's own reporter, but
-- the only DELETE policy on incidents was "Authority can delete incidents".
-- RLS silently filters a blocked delete down to zero rows instead of
-- raising an error, so the app showed "deleted" and the report came back
-- on the next refresh. This adds the missing reporter policy; authorities
-- keep their existing one for moderation.
--
-- incident_confirmations already cascades on delete, so no cleanup needed.
-- ============================================================================

drop policy if exists "Reporters can delete their own incidents" on incidents;
create policy "Reporters can delete their own incidents"
  on incidents for delete to authenticated
  using (reporter_id = auth.uid());
