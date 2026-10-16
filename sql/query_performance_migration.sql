-- ============================================================================
-- Query performance
-- Supabase SQL Migration — run this in the Supabase SQL Editor.
--
-- 1. is_authority() is called by RLS policies on every row Postgres considers.
--    Declared VOLATILE (the default) it ran once per row; STABLE lets Postgres
--    evaluate it once per query. A fixed search_path is also required for a
--    SECURITY DEFINER function.
-- 2. Indexes for the filters and joins the app actually uses (policy checks on
--    reporter_id / managed_by, "my reports", zone lookups, list ordering).
--    Each index is created only if its table and columns exist, so this runs
--    cleanly on a database that is missing some of the optional tables.
--
-- Idempotent — safe to re-run.
-- ============================================================================

create or replace function public.is_authority()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return exists (
    select 1 from profiles
    where id = auth.uid()
      and role in ('authority', 'admin', 'volunteer_org')
  );
end;
$$;

do $$
declare
  spec record;
  have_all boolean;
begin
  for spec in
    select * from (values
      -- name,                              table,                    columns (comma separated, with order)
      ('idx_incidents_reporter',            'incidents',              'reporter_id'),
      ('idx_incidents_updated',             'incidents',              'updated_at desc'),
      ('idx_confirmations_member',          'incident_confirmations', 'member_id'),
      ('idx_alerts_status_created',         'alerts',                 'status, created_at desc'),
      ('idx_alerts_zone',                   'alerts',                 'affected_zone_id'),
      ('idx_volunteer_tasks_shelter',       'volunteer_tasks',        'shelter_id'),
      ('idx_volunteer_tasks_status_created','volunteer_tasks',        'status, created_at desc'),
      ('idx_shelters_managed_by',           'shelters',               'managed_by'),
      ('idx_profiles_zone',                 'profiles',               'zone_id'),
      ('idx_feedback_zone_created',         'feedback_forms',         'zone_id, created_at desc'),
      ('idx_feedback_submitted_by',         'feedback_forms',         'submitted_by'),
      ('idx_safety_broadcasts_user_sent',   'safety_broadcasts',      'user_id, sent_at desc'),
      ('idx_location_shares_owner_created', 'location_shares',        'owner_id, created_at desc'),
      ('idx_family_invites_open',           'family_invites',         'owner_id, expires_at')
    ) as t(idx, tbl, cols)
  loop
    select bool_and(exists (
             select 1 from information_schema.columns c
             where c.table_schema = 'public'
               and c.table_name = spec.tbl
               and c.column_name = split_part(trim(col), ' ', 1)))
      into have_all
    from unnest(string_to_array(spec.cols, ',')) as col;

    if coalesce(have_all, false) then
      execute format('create index if not exists %I on public.%I (%s)',
                     spec.idx, spec.tbl, spec.cols);
    end if;
  end loop;
end $$;

-- Refresh planner statistics so the new indexes are used straight away.
analyze;
