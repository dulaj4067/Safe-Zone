-- ============================================================================
-- Shelter Resources, Volunteer Tasks, Coordination Messages & Feedback
-- Supabase SQL Migration — run this in the Supabase SQL Editor.
--
-- These five tables already exist in the live schema (shelter_resources,
-- volunteer_tasks and volunteer_assignments also have seed data), so this
-- file does NOT create them. It adds what the app needs to use them safely:
-- row-level security policies, uniqueness guards, indexes, and realtime for
-- message threads. Every statement is idempotent — safe to re-run.
-- ============================================================================

-- 0. is_authority() — same definition as sql/incident_migration.sql, repeated
-- so this file runs standalone.
create or replace function is_authority()
returns boolean as $$
begin
  return exists (
    select 1 from profiles
    where id = auth.uid()
    and role in ('authority', 'admin', 'volunteer_org')
  );
end;
$$ language plpgsql security definer;

-- ============================================================================
-- 1. shelter_resources — per-shelter stock (water, food, medicine, bedding,
--    other). Readable by any signed-in user; editable by that shelter's
--    manager (shelters.managed_by) or an authority.
-- ============================================================================
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'shelter_resources_shelter_type_key'
  ) then
    alter table shelter_resources
      add constraint shelter_resources_shelter_type_key unique (shelter_id, resource_type);
  end if;
end$$;

alter table shelter_resources enable row level security;

drop policy if exists "Authenticated can view shelter resources" on shelter_resources;
create policy "Authenticated can view shelter resources"
  on shelter_resources for select to authenticated using (true);

drop policy if exists "Shelter managers and authorities manage resources" on shelter_resources;
create policy "Shelter managers and authorities manage resources"
  on shelter_resources for all to authenticated
  using (
    is_authority()
    or exists (
      select 1 from shelters s
      where s.id = shelter_resources.shelter_id and s.managed_by = auth.uid()
    )
  )
  with check (
    is_authority()
    or exists (
      select 1 from shelters s
      where s.id = shelter_resources.shelter_id and s.managed_by = auth.uid()
    )
  );

-- ============================================================================
-- 2. volunteer_tasks — posted by authorities / volunteer organisations,
--    visible to every signed-in user.
-- ============================================================================
alter table volunteer_tasks enable row level security;

drop policy if exists "Authenticated can view volunteer tasks" on volunteer_tasks;
create policy "Authenticated can view volunteer tasks"
  on volunteer_tasks for select to authenticated using (true);

drop policy if exists "Authorities manage volunteer tasks" on volunteer_tasks;
create policy "Authorities manage volunteer tasks"
  on volunteer_tasks for all to authenticated
  using (is_authority())
  with check (is_authority());

-- ============================================================================
-- 3. volunteer_assignments — a citizen signing up for a task. One row per
--    (task, volunteer); you can only sign yourself up, only for an open task.
-- ============================================================================
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'volunteer_assignments_task_volunteer_key'
  ) then
    alter table volunteer_assignments
      add constraint volunteer_assignments_task_volunteer_key unique (task_id, volunteer_id);
  end if;
end$$;

create index if not exists idx_volunteer_assignments_task
  on volunteer_assignments (task_id);

alter table volunteer_assignments enable row level security;

-- Visible to everyone signed in so "3 / 5 signed up" counts work; rows only
-- carry ids, no personal details.
drop policy if exists "Authenticated can view assignments" on volunteer_assignments;
create policy "Authenticated can view assignments"
  on volunteer_assignments for select to authenticated using (true);

drop policy if exists "Citizens sign themselves up for open tasks" on volunteer_assignments;
create policy "Citizens sign themselves up for open tasks"
  on volunteer_assignments for insert to authenticated
  with check (
    volunteer_id = auth.uid()
    and exists (
      select 1 from volunteer_tasks t
      where t.id = volunteer_assignments.task_id and t.status = 'open'
    )
  );

drop policy if exists "Volunteers withdraw, authorities remove" on volunteer_assignments;
create policy "Volunteers withdraw, authorities remove"
  on volunteer_assignments for delete to authenticated
  using (volunteer_id = auth.uid() or is_authority());

-- ============================================================================
-- 4. coordination_messages — shelter-scoped one-to-one messages (e.g. a
--    citizen and a shelter's manager). Only the two people in a thread can
--    read it.
-- ============================================================================
create index if not exists idx_coordination_messages_shelter
  on coordination_messages (shelter_id, created_at);
create index if not exists idx_coordination_messages_sender
  on coordination_messages (sender_id, created_at desc);
create index if not exists idx_coordination_messages_recipient
  on coordination_messages (recipient_id, created_at desc);

alter table coordination_messages enable row level security;

drop policy if exists "Participants can read their messages" on coordination_messages;
create policy "Participants can read their messages"
  on coordination_messages for select to authenticated
  using (sender_id = auth.uid() or recipient_id = auth.uid());

drop policy if exists "Citizens send messages as themselves" on coordination_messages;
create policy "Citizens send messages as themselves"
  on coordination_messages for insert to authenticated
  with check (sender_id = auth.uid() and recipient_id is not null);

-- Live message threads: the app subscribes to inserts on this table.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'coordination_messages'
  ) then
    alter publication supabase_realtime add table coordination_messages;
  end if;
end$$;

-- ============================================================================
-- 5. feedback_forms — citizen rating (1–5) plus free-text needs. Citizens
--    see only their own; authorities see everything.
-- ============================================================================
create index if not exists idx_feedback_forms_created
  on feedback_forms (created_at desc);

alter table feedback_forms enable row level security;

drop policy if exists "Citizens submit their own feedback" on feedback_forms;
create policy "Citizens submit their own feedback"
  on feedback_forms for insert to authenticated
  with check (submitted_by = auth.uid());

drop policy if exists "Own feedback or authority can view" on feedback_forms;
create policy "Own feedback or authority can view"
  on feedback_forms for select to authenticated
  using (submitted_by = auth.uid() or is_authority());
