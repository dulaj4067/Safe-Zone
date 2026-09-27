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

3. **Configure your Supabase connection.** The URL and publishable key are set in `lib/main.dart` — replace them with your own project's values.

4. **Configure your CARTO API key.** Create `config/dev.json`:
   ```json
   {
     "CARTO_API_KEY": "your-carto-api-key"
   }
   ```

5. **Run the app**
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

## Known Limitations

- The Preparedness Hub currently stores guides, routes, and history locally on-device rather than in Supabase.
- Shelter messages have no unread badges or push notifications yet.

## Team

- Dulaj Serasinghe
- Dewmini Rathnayake
- D.V. Malliyawatta
- Dewmina Wanninayake
- Dinuka
