-- ============================================================================
-- Live incident updates
-- Supabase SQL Migration — run this in the Supabase SQL Editor.
--
-- The app listens for changes to `incidents` so a report someone files (or an
-- authority verifies) appears on everyone else's list and map without a manual
-- reload. Supabase only streams changes for tables that are in the
-- `supabase_realtime` publication. RLS still applies: people only receive
-- events for rows they are allowed to read.
--
-- Idempotent — safe to re-run.
-- ============================================================================

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'incidents'
  ) then
    alter publication supabase_realtime add table public.incidents;
  end if;
end $$;
