# SafeZone

**Sri Lanka Disaster Early-Warning Network** — a Flutter app that gives citizens real-time flood and disaster alerts, lets them report and confirm incidents, find nearby shelters, and keep their safety circle updated, while giving authorities a dashboard to broadcast and manage it all.

Built on [Supabase](https://supabase.com) (Postgres + PostGIS, Auth, Realtime, Storage) with an offline-first map layer so core safety information keeps working with a spotty connection.

## Features

- **Real-time alerts** — severity-banded flood/disaster warnings pushed live via Supabase Realtime. Critical (red) alerts can bypass Do Not Disturb with a dedicated alarm channel, with automatic SMS/in-app fallback if push notifications fail.
- **Interactive map** — street and topographic base layers (offline-cached), live GPS position, shelters, incidents, and active alert zones all on one map, per role.
- **Incident reporting** — photo/video attachments, an SOS flag for life-threatening reports, and community confirmation with an auto-updating credibility score.
- **Shelters directory** — capacity/occupancy, status, live supply levels (water, food, medicine, bedding), manager contact, and a one-tap call action.
- **Volunteering** — authorities and volunteer organisations post tasks; citizens sign up and track how many helpers each task still needs.
- **Shelter messaging** — live one-to-one threads between citizens and shelter managers.
- **Citizen feedback** — star ratings and "what do you still need" notes, summarised by zone for authorities.
- **Safety Circle** — one-tap "I'm Safe" broadcasts, live ETA sharing, and map markers showing where circle members were last at.
- **Preparedness Hub** — disaster guides, evacuation routes, and local disaster history.
- **Authority tools** — a broadcast dashboard for creating geo-targeted alerts, reviewing citizen incident reports, and tracking resident reach/acknowledgment.
- **Offline resilience** — cached map tiles, cached alerts, and resumable activity history so the app degrades gracefully when connectivity drops.

## Tech Stack

- [Flutter](https://flutter.dev) / Dart
- [Supabase](https://supabase.com) — Postgres with PostGIS, Auth, Realtime subscriptions, Storage
- [Provider](https://pub.dev/packages/provider) for state management
- [flutter_map](https://pub.dev/packages/flutter_map) with CARTO (street) and OpenTopoMap (topo) tile layers
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) + [geolocator](https://pub.dev/packages/geolocator)

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (see `pubspec.yaml` for the required Dart SDK constraint)
- A [Supabase](https://supabase.com) project with the app's core tables already created (`profiles`, `zones`, `alerts`, `incidents`, `shelters`, etc.)
- A [CARTO](https://carto.com/basemaps) API key for street map tiles

### Setup

1. **Clone and install dependencies**
   ```bash
   git clone <this-repo>
   cd Safe-Zone
   flutter pub get
   ```

2. **Run the SQL migrations** in your Supabase project's SQL Editor:
   - `sql/incident_migration.sql` — incidents, confirmations, credibility scoring, storage bucket for incident media
   - `sql/safety_circle_migration.sql` — safety circle contacts, live ETA location sharing, "I'm Safe" broadcasts, and the view backing the map's "last known location" markers
   - `sql/coordination_features_migration.sql` — access rules, constraints, and realtime for shelter supplies, volunteer tasks, messaging, and feedback (see [docs/features/coordination_features.md](docs/features/coordination_features.md))
   - `sql/security_hardening_migration.sql` — locks down profiles/PII, server-managed roles, authority-only incident review fields
   - `sql/privacy_consent_onboarding_migration.sql` — policy acceptances, deletion requests, onboarding state, alert engagement
   - `sql/account_deletion_and_notifications_migration.sql` — deletion processing, duplicate-phone sign-ups, "I'm Safe" emails (moves the webhook secret into Vault)
   - `sql/preparedness_hub_migration.sql` — shared preparedness content, including disaster history
   - `sql/disaster_history_samples_migration.sql` — fictional, clearly labeled demo history rows (run after the preparedness hub migration)

   Then deploy the Edge Functions: `notify-safety-circle-request` and `notify-im-safe` with **verify JWT off** (called by database triggers with a shared secret), and `process-account-deletion` with **verify JWT on**. They need the secrets `BREVO_API_KEY`, `BREVO_SENDER_EMAIL` and `SAFETY_CIRCLE_WEBHOOK_SECRET`.

3. **Configure the app.** Copy `config/dev.example.json` to `config/dev.json` and fill it in:
   ```json
   {
     "CARTO_API_KEY": "your-carto-api-key",
     "SUPABASE_URL": "https://<project-ref>.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
   }
   ```
   `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY` are optional and default to the shared project (see `lib/utils/app_config.dart`). Only ever use the **publishable** key — every value here is compiled into the APK, and the app refuses to start with a secret/service-role key.

4. **Run the app**
   ```bash
   flutter run --dart-define-from-file=config/dev.json
   ```

## Project Structure

```
lib/
├── models/       # Data classes (Alert, Incident, Shelter, SafetyCircleContact, ...)
├── providers/     # App state (AlertProvider, IncidentProvider, SafetyProvider, ...)
├── services/      # Supabase queries, notifications, location, tile caching
├── screens/       # Top-level screens (Home, Incidents, Shelters, Settings, admin screens, ...)
├── widgets/       # Reusable UI (markers, banners, sheets, ...)
├── modules/       # Self-contained feature modules (Preparedness Hub)
└── theme/         # App colors and typography

sql/               # Supabase migrations, run manually via the SQL Editor
docs/features/     # Design notes for individual features
```

## Preparedness Hub Data

- Preparedness content is cached locally and syncs with Supabase when the user is signed in and a connection is available.
- Disaster history supports national or district records, partial event dates, impact figures, and source attribution.
- It includes clearly marked fictional demo samples for UI preview. Run `sql/disaster_history_samples_migration.sql` after `sql/preparedness_hub_migration.sql` to add them to Supabase; the same fixtures are available locally, and duplicate copies are collapsed in the UI. These samples are never saved or synced as real events.
- Before distributing EM-DAT records through the app, review its [data terms](https://doc.emdat.be/docs/legal/terms-of-use/) and obtain any required permission. The terms restrict redistributing EM-DAT data to unauthorized users.

## Known Limitations

- Shelter messages have no unread badges or push notifications yet.

## Team

- Dulaj Serasinghe
- Dewmini Rathnayake
- Dinuka Malliyawatta
- Dewmina Wanninayake