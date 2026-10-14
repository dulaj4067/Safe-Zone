-- ============================================================================
-- Shelter messaging: private threads, manager-initiated chats, unread badges
-- Supabase SQL Migration — run this in the Supabase SQL Editor.
--
-- 1. Reading: only the sender and the recipient can read a message. (The live
--    database also let every authority read every conversation.)
-- 2. Sending: a message must be about a shelter and sent either to that
--    shelter's manager or BY that shelter's manager. That lets managers
--    start a conversation (e.g. with a volunteer on one of their tasks) while
--    stopping anyone messaging arbitrary people through a shelter.
-- 3. Unread: messages get a read_at stamp that only the recipient can set.
--    Messages that already exist are marked read so nobody gets a flood of
--    old "unread" badges.
--
-- Run after sql/shelter_workflow_and_volunteer_fixes_migration.sql.
-- Idempotent — safe to re-run.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 3a. read_at column (existing rows count as read)
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'coordination_messages'
      and column_name = 'read_at'
  ) then
    alter table coordination_messages add column read_at timestamptz;
    update coordination_messages set read_at = created_at;
  end if;
end $$;

create index if not exists idx_coordination_messages_unread
  on coordination_messages (recipient_id)
  where read_at is null;

-- ----------------------------------------------------------------------------
-- 1. Reading: participants only
-- ----------------------------------------------------------------------------
drop policy if exists "Participants can read their messages" on coordination_messages;
create policy "Participants can read their messages"
  on coordination_messages for select to authenticated
  using (sender_id = auth.uid() or recipient_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 2. Sending: to the shelter's manager, or from it
-- ----------------------------------------------------------------------------
drop policy if exists "Users can send messages" on coordination_messages;
drop policy if exists "Citizens send messages as themselves" on coordination_messages;
drop policy if exists "Send messages about a shelter you manage or contact" on coordination_messages;
create policy "Send messages about a shelter you manage or contact"
  on coordination_messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and recipient_id is not null
    and shelter_id is not null
    and exists (
      select 1 from shelters s
      where s.id = coordination_messages.shelter_id
        and (s.managed_by = auth.uid() or s.managed_by = coordination_messages.recipient_id)
    )
  );

-- ----------------------------------------------------------------------------
-- 3b. Only the recipient can mark a message read, and only that field changes
-- ----------------------------------------------------------------------------
drop policy if exists "Recipients mark messages read" on coordination_messages;
create policy "Recipients mark messages read"
  on coordination_messages for update to authenticated
  using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid());

create or replace function guard_message_update()
returns trigger as $$
begin
  if auth.uid() is null then
    return new;
  end if;
  new.id           := old.id;
  new.shelter_id   := old.shelter_id;
  new.sender_id    := old.sender_id;
  new.recipient_id := old.recipient_id;
  new.message      := old.message;
  new.created_at   := old.created_at;
  -- read_at may be set once, never cleared or moved.
  new.read_at := coalesce(old.read_at, new.read_at);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_guard_message_update on coordination_messages;
create trigger trg_guard_message_update
  before update on coordination_messages
  for each row execute function guard_message_update();
