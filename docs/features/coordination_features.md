# Shelter supplies, volunteering, messaging and feedback

Five tables in the Supabase schema — `shelter_resources`, `volunteer_tasks`,
`volunteer_assignments`, `coordination_messages` and `feedback_forms` — existed
with no app features on top of them. This adds a feature for each. The app has
only two top-level experiences (the citizen tab bar and the authority
dashboard), so none of these got a new tab: each hangs off a screen that
already exists.

## Before you run the app: apply the migration

Run `sql/coordination_features_migration.sql` in the Supabase SQL Editor. It
does not create tables (they already exist, some with seed data). It adds:

- Row-level security policies for all five tables (see *Who can do what*).
- `unique (shelter_id, resource_type)` on `shelter_resources` and
  `unique (task_id, volunteer_id)` on `volunteer_assignments`. The seed data
  was checked for duplicates before adding these.
- Indexes for the message, assignment and feedback queries.
- `coordination_messages` added to the `supabase_realtime` publication, so
  message threads update live.

Every statement is idempotent, so the file is safe to re-run.

**Why it matters:** until it runs, the live database allows some writes but
not others. For example, volunteer sign-up works but withdrawing does not.
Postgres doesn't raise an error when RLS blocks an `UPDATE` or `DELETE`; it
just affects zero rows. Every update and delete in the new services
therefore calls `.select()` and passes the result to `requireRowsAffected()`
(`lib/services/supabase_service.dart`). A blocked write then shows "You don't
have permission to …" instead of a false success message.

If a table already has its own permissive policies in the dashboard, they are
OR-ed with these ones. Check for older "allow all" policies and remove them.

## Where each feature lives

| Feature | Citizen entry point | Authority entry point |
|---|---|---|
| Shelter supplies | Shelter detail sheet → **Supplies** card | Same card, with edit controls |
| Volunteer tasks | Prep Hub → **Volunteer**; Settings → Community & Support; shelter sheet → *Volunteer at this shelter* | Broadcast Dashboard → **Volunteers** (adds *New task* and status changes) |
| Messages | Shelter sheet → **Message Shelter Manager**; Settings → Messages | Broadcast Dashboard → **Messages** |
| Feedback | Settings → **Send Feedback** | Broadcast Dashboard → **Feedback** |

### Shelter supplies (`shelter_resources`)

`ShelterResourcesCard` lists each supply with its quantity, unit and last
update, and highlights zero stock in red. The shelter's manager
(`shelters.managed_by`) or any authority can tap a row to change it, remove
it, or add a supply type the shelter doesn't have yet. `resource_type` is a
Postgres enum whose only valid values are `water`, `food`, `medicine`,
`bedding` and `other`. To add another type, run
`alter type resource_type add value '…'` and add it to `ResourceType` in
`lib/models/shelter_resource.dart`.

### Volunteer tasks (`volunteer_tasks`, `volunteer_assignments`)

`VolunteerTasksScreen` lists tasks newest first, filtered by status (default:
Open). Each card shows the shelter, the description and "*n* of *m*
volunteers", with **Sign up** / **Withdraw** / **Full** as appropriate.
Sign-ups are loaded in the same query as the tasks (`select('*,
volunteer_assignments(volunteer_id)')`), so a list is a single request.
Opening the screen from a shelter sheet limits it to that shelter's tasks.

Authorities get a **New task** button (title, description, optional shelter
and zone, volunteers needed). The status chip on each card becomes a menu that
moves the task between `open`, `in_progress`, `completed` and `cancelled`, the
full set of `volunteer_task_status` enum values. RLS only allows sign-ups to
tasks that are `open`.

### Messages (`coordination_messages`)

A thread is one shelter plus one other person, typically a citizen and that
shelter's manager. `MessageThreadScreen` loads the history and subscribes to
live inserts for the shelter, filtered to its own pair of people.
`MessagesScreen` is the inbox. It groups the latest 300 messages the user sent
or received into one row per thread, so managers see every citizen who has
written to them. The **Message Shelter Manager** button appears only when the
shelter has a manager who isn't the current user.

### Feedback (`feedback_forms`)

The feedback sheet collects a required 1–5 star rating and optional free text
("what do you still need?"). It saves the citizen's zone with the rating.
`FeedbackOverviewScreen` shows authorities the average rating, how many
ratings of each star value there are, and every written comment, with a
zone filter.

## Who can do what

`is_authority()` is true for the `authority`, `admin` and `volunteer_org`
roles. This matches `UserRole.isAuthority` in the app, so volunteer
organisations can post tasks and also edit any shelter's supplies.

| Table | Read | Write |
|---|---|---|
| `shelter_resources` | any signed-in user | that shelter's manager, or an authority |
| `volunteer_tasks` | any signed-in user | authorities |
| `volunteer_assignments` | any signed-in user (ids only, for counts) | insert: yourself, open tasks only · delete: yourself, or an authority |
| `coordination_messages` | sender and recipient only | send as yourself, to a named recipient |
| `feedback_forms` | your own rows; authorities see all | submit as yourself |

The app hides controls the user can't use (`ProfileService.currentUserRole()`,
`ShelterService.canManageShelter()`), but RLS is the real enforcement.

## Files

- **Migration:** `sql/coordination_features_migration.sql`
- **Models:** `shelter_resource.dart`, `volunteer_task.dart`,
  `coordination_message.dart`, `feedback_entry.dart` (in `lib/models/`)
- **Services:** `profile_service.dart` (role and display-name lookups),
  `volunteer_service.dart`, `coordination_service.dart`,
  `feedback_service.dart`, plus supply methods added to `shelter_service.dart`
- **UI:** `widgets/shelter_resources_card.dart`, `widgets/feedback_sheet.dart`,
  `screens/volunteer_tasks_screen.dart`, `screens/messages_screen.dart`,
  `screens/message_thread_screen.dart`, `screens/feedback_overview_screen.dart`
- **Entry points edited:** `shelter_detail_sheet.dart`,
  `preparedness_hub_screen.dart`, `settings_screen.dart`,
  `broadcast_dashboard_screen.dart`
- **Tests:** `test/coordination_models_test.dart` covers enum mapping and parsing

## Known gaps

- There are no unread badges or push notifications for new messages. The
  table has no read-state column, so both would need a schema change.
- A shelter with no `managed_by` can't be messaged.
- Tested on device as a citizen: supplies display, volunteer sign-up, the
  permission error on withdraw (before the migration), the feedback form and
  the inbox. Authority-only flows (posting tasks, changing status, editing
  supplies, the feedback overview) compile and pass analysis but still need a
  run-through with an authority account after the migration is applied.
