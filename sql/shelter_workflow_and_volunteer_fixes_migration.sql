-- ============================================================================
-- Shelter submission / approval workflow, owner management, volunteer fixes
-- Supabase SQL Migration — run this in the Supabase SQL Editor.
--
-- 1. Shelters gain an approval lifecycle: a citizen submits a shelter
--    (pending), an authority verifies it and approves or rejects it, and an
--    approved shelter becomes public and is managed by its submitter.
--    Every existing shelter is grandfathered in as approved.
-- 2. Approved shelter owners can edit their own shelter's details and its
--    supplies (shelter_resources) without being an authority.
-- 3. Volunteers can withdraw from a task themselves. The live schema only
--    had an INSERT policy on volunteer_assignments, so a withdrawal deleted
--    zero rows and looked like it needed an administrator.
--
-- Idempotent — safe to re-run.
-- ============================================================================

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

-- ----------------------------------------------------------------------------
-- 1. Approval lifecycle columns
-- ----------------------------------------------------------------------------
alter table shelters add column if not exists address          text;
alter table shelters add column if not exists description      text;
alter table shelters add column if not exists approval_status  text not null default 'approved';
alter table shelters add column if not exists submitted_by     uuid references profiles(id) on delete set null;
alter table shelters add column if not exists reviewed_by      uuid references profiles(id) on delete set null;
alter table shelters add column if not exists reviewed_at      timestamptz;
alter table shelters add column if not exists rejection_reason text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'shelters_approval_status_check'
  ) then
    alter table shelters
      add constraint shelters_approval_status_check
      check (approval_status in ('pending', 'approved', 'rejected'));
  end if;
end $$;

create index if not exists idx_shelters_approval on shelters (approval_status);
create index if not exists idx_shelters_submitted_by on shelters (submitted_by);

-- ----------------------------------------------------------------------------
-- 2. Row-level security
--    Public sees approved shelters only. A submitter sees their own, whatever
--    its status. Authorities see and change everything.
-- ----------------------------------------------------------------------------
drop policy if exists "Anyone can read shelters" on shelters;
drop policy if exists "Public reads approved shelters" on shelters;
create policy "Public reads approved shelters"
  on shelters for select
  using (
    approval_status = 'approved'
    or submitted_by = auth.uid()
    or managed_by = auth.uid()
    or is_authority()
  );

-- "Authority can manage shelters" (ALL, is_authority()) stays as is.

drop policy if exists "Citizens submit shelters for review" on shelters;
create policy "Citizens submit shelters for review"
  on shelters for insert to authenticated
  with check (
    approval_status = 'pending'
    and submitted_by = auth.uid()
    and managed_by is null
  );

-- Owners edit an approved shelter; submitters can fix a pending / rejected
-- one (which sends it back for review). The trigger below stops either of
-- them touching the approval fields.
drop policy if exists "Owners and submitters update their shelters" on shelters;
create policy "Owners and submitters update their shelters"
  on shelters for update to authenticated
  using (
    managed_by = auth.uid()
    or (submitted_by = auth.uid() and approval_status in ('pending', 'rejected'))
  )
  with check (
    managed_by = auth.uid() or submitted_by = auth.uid()
  );

drop policy if exists "Submitters withdraw unapproved shelters" on shelters;
create policy "Submitters withdraw unapproved shelters"
  on shelters for delete to authenticated
  using (submitted_by = auth.uid() and approval_status in ('pending', 'rejected'));

-- ----------------------------------------------------------------------------
-- 3. Guard the approval fields
--    RLS can't restrict individual columns, so this trigger does:
--    - non-authorities cannot change who owns a shelter or its review state;
--      editing a pending / rejected shelter resubmits it as pending;
--    - an authority's decision stamps who decided and when, and approving
--      makes the submitter the shelter's manager.
--    Calls with no signed-in user (SQL editor, service role) pass through.
-- ----------------------------------------------------------------------------
create or replace function guard_shelter_review_fields()
returns trigger as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if is_authority() then
    if new.approval_status is distinct from old.approval_status then
      new.reviewed_by := auth.uid();
      new.reviewed_at := now();
      if new.approval_status = 'approved' then
        new.managed_by := coalesce(new.managed_by, new.submitted_by);
        new.rejection_reason := null;
      end if;
    end if;
    return new;
  end if;

  new.submitted_by := old.submitted_by;
  new.managed_by   := old.managed_by;
  new.reviewed_by  := old.reviewed_by;
  new.reviewed_at  := old.reviewed_at;

  if old.approval_status = 'approved' then
    new.approval_status  := 'approved';
    new.rejection_reason := old.rejection_reason;
  else
    -- Fixing a rejected shelter (or tweaking a pending one) re-queues it.
    new.approval_status  := 'pending';
    new.rejection_reason := null;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_guard_shelter_review on shelters;
create trigger trg_guard_shelter_review
  before update on shelters
  for each row execute function guard_shelter_review_fields();

-- ----------------------------------------------------------------------------
-- 4. Owners manage their shelter's supplies
-- ----------------------------------------------------------------------------
drop policy if exists "Shelter owners manage resources" on shelter_resources;
create policy "Shelter owners manage resources"
  on shelter_resources for all to authenticated
  using (
    exists (
      select 1 from shelters s
      where s.id = shelter_resources.shelter_id
        and s.managed_by = auth.uid()
        and s.approval_status = 'approved'
    )
  )
  with check (
    exists (
      select 1 from shelters s
      where s.id = shelter_resources.shelter_id
        and s.managed_by = auth.uid()
        and s.approval_status = 'approved'
    )
  );

-- ----------------------------------------------------------------------------
-- 5. Volunteers withdraw themselves
-- ----------------------------------------------------------------------------
drop policy if exists "Volunteers withdraw their own signup" on volunteer_assignments;
create policy "Volunteers withdraw their own signup"
  on volunteer_assignments for delete to authenticated
  using (volunteer_id = auth.uid() or is_authority());
