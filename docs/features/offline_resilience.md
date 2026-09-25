# Offline resilience

## Route map tile caching

SafeZone uses a local tile cache behind every `flutter_map` base layer. The cache
is shared by street and topographic tiles, stores at most 2,000 tiles, and treats
tiles older than 14 days as stale. The cache manager evicts the least-recently
used entries when its bound is reached.

After a route is calculated, the route bounding box is expanded by a 2 km buffer
and tiles for zoom levels 12 through 15 are prefetched on a best-effort basis.
This runs without blocking the route UI. If a request fails later, the tile
provider returns the stale local copy when one exists; route lines and markers
remain Flutter layers above the tile layer. A small `Offline map data` label is
shown when cached tiles are being used. When connectivity returns, the active
route can be prefetched again without replacing the visible route.

## Resume Activity card

The Home screen's `Resume where you left off` card reads only the local
`SharedPreferences` key `safezone_local_activity_history`. It contains a rolling
maximum of four distinct screen/section entries, newest first. Recording and
reading this list never calls Supabase and never sends analytics or activity data
to a server.

The app treats `AppLifecycleState.paused` and `inactive` as interruptions, and
also treats a `ConnectivityResult.none` event as an interruption. The most recent
entry is marked locally so the card can identify the interruption point. The card
is omitted when the local list is empty, and tapping an item returns to its
recorded app section.
