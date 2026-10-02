import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/route_result.dart';
import '../models/shelter.dart';
import '../providers/active_route_provider.dart';
import '../providers/alert_provider.dart';
import '../providers/route_provider.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../theme/app_colors.dart';
import '../utils/map_tile_sources.dart';
import '../widgets/live_location_marker.dart';
import '../widgets/location_alert_banner.dart';
import '../widgets/route_summary_card.dart';
import '../widgets/safe_zone_base_map.dart';
import '../widgets/cached_map_indicator.dart';

/// Hazard-aware directions to a shelter, opened from its Shelter page.
/// Starts with [destination] preselected and the origin set to the
/// device's live position (when location is available), then routes
/// immediately. Tapping another shelter re-routes to it; tapping the map
/// places a custom point.
///
/// Routing itself asks OSRM's free, keyless public routing API for every
/// alternative it offers, then RouteHazardScorer (see
/// utils/route_hazard_scoring.dart) picks whichever one best avoids
/// AlertProvider's currently active disaster zones — red zones are
/// avoided outright whenever any alternative allows it — without
/// straying far from the shortest option otherwise. See
/// RouteProvider.requestRoute().
class ShelterDirectionsScreen extends StatelessWidget {
  final Shelter destination;

  const ShelterDirectionsScreen({super.key, required this.destination});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RouteProvider(service: RoutingService()),
      child: _RouteScreenBody(destination: destination),
    );
  }
}

class _RouteScreenBody extends StatefulWidget {
  final Shelter destination;

  const _RouteScreenBody({required this.destination});

  @override
  State<_RouteScreenBody> createState() => _RouteScreenBodyState();
}

class _RouteScreenBodyState extends State<_RouteScreenBody> {
  static const LatLng _initialCenter = LatLng(6.9615, 79.9010);

  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  StreamSubscription<LatLng>? _positionSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  LatLng? _liveLocation;
  bool _locationDenied = false;

  late final RouteProvider _routeProvider;
  RouteResult? _publishedResult;

  /// Shares every newly computed route (including after a Walk/Drive
  /// switch) with the home map, so it stays visible after leaving here.
  void _publishRoute() {
    final result = _routeProvider.result;
    final destination = _routeProvider.destination;
    if (result == null ||
        destination == null ||
        identical(result, _publishedResult)) {
      return;
    }
    _publishedResult = result;
    final shelter = [widget.destination, ..._routeProvider.shelters]
        .where(
          (s) =>
              s.latitude == destination.latitude &&
              s.longitude == destination.longitude,
        )
        .firstOrNull;
    Provider.of<ActiveRouteProvider?>(context, listen: false)?.set(
      ActiveRoute(
        result: result,
        destination: destination,
        mode: _routeProvider.mode,
        shelter: shelter,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _routeProvider = context.read<RouteProvider>()..addListener(_publishRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeToDestination());
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      if (results.any((result) => result != ConnectivityResult.none)) {
        final route = context.read<RouteProvider>().result;
        if (route != null) {
          safeZoneTileCache.prefetchRoute(route.bounds);
        }
      }
    });
    _startWatchingLocation();
  }

  Future<void> _startWatchingLocation() async {
    final granted = await _locationService.ensurePermission();
    if (!mounted) return;
    if (!granted) {
      setState(() => _locationDenied = true);
      return;
    }
    // The stream below only reports once the device moves, so ask for a
    // one-off fix right away — otherwise the dot and the "my location"
    // button have nothing to use until the person starts walking.
    _locationService.getCurrentLocation().then((fix) {
      if (fix != null) _applyFix(fix, onlyIfUnknown: true);
    });
    _positionSub = _locationService.watchPosition().listen(
      (position) => _applyFix(position),
      onError: (_) {
        // Leave whatever last-known position we have rather than
        // clearing it on a transient GPS/provider error.
      },
    );
  }

  @override
  void dispose() {
    _routeProvider.removeListener(_publishRoute);
    _positionSub?.cancel();
    _connectivitySub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Stores a new position for the blue dot. SafeZoneBaseMap handles
  /// moving the camera onto it the first time one arrives.
  void _applyFix(LatLng position, {bool onlyIfUnknown = false}) {
    if (!mounted) return;
    if (onlyIfUnknown && _liveLocation != null) return;
    setState(() => _liveLocation = position);
  }

  /// Tapping anywhere on the map places whichever point (origin or
  /// destination) is currently active — RouteProvider.setPointFromTap
  /// auto-advances from origin to destination, so two taps place a full
  /// route with no restriction to shelter locations.
  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    final provider = context.read<RouteProvider>();
    provider.setPointFromTap(point);
    if (provider.canRequestRoute) {
      await _requestRouteAndFit();
    }
  }

  /// Preselects the shelter this screen was opened for, starts from the
  /// live position, and routes straight away. Without a location fix the
  /// destination stays set and the person taps the map for a start point.
  Future<void> _routeToDestination() async {
    final provider = context.read<RouteProvider>();
    provider.selectShelterAsDestination(widget.destination);
    await provider.init();
    if (!mounted) return;
    if (await _locationService.ensurePermission()) {
      final here = _liveLocation ?? await _locationService.getCurrentLocation();
      if (!mounted) return;
      if (here != null) provider.setOriginToCurrentLocation(here);
    }
    if (provider.canRequestRoute) await _requestRouteAndFit();
  }

  /// Tapping another shelter's marker re-routes to it.
  Future<void> _onShelterTap(Shelter shelter) async {
    final provider = context.read<RouteProvider>();
    provider.selectShelterAsDestination(shelter);
    if (provider.canRequestRoute) {
      await _requestRouteAndFit();
    }
  }

  /// Seeds the origin from the device's live GPS fix — useful since a
  /// citizen fleeing a disaster wants "route from where I actually am,"
  /// not a manually-tapped approximation.
  Future<void> _useMyLocationAsOrigin() async {
    final current =
        _liveLocation ?? await _locationService.getCurrentLocation();
    if (current == null) {
      if (mounted) {
        setState(() => _locationDenied = true);
      }
      return;
    }
    final provider = context.read<RouteProvider>();
    provider.setOriginToCurrentLocation(current);
    if (provider.canRequestRoute) {
      await _requestRouteAndFit();
    }
  }

  Future<void> _requestRouteAndFit({
    RouteProvider? providerOverride,
    List<DisasterAlert>? activeAlertsOverride,
  }) async {
    final provider = providerOverride ?? context.read<RouteProvider>();
    final activeAlerts =
        activeAlertsOverride ?? context.read<AlertProvider>().activeAlerts;

    await provider.requestRoute(activeAlerts: activeAlerts);
    if (!mounted) return;

    final result = provider.result;
    if (result == null) return;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: result.bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
    safeZoneTileCache.prefetchRoute(result.bounds);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteProvider>();
    final activeAlerts = context.watch<AlertProvider>().activeAlerts;
    final destination = provider.destination;
    final destinationIsShelter =
        destination != null &&
        provider.shelters.any(
          (s) =>
              s.latitude == destination.latitude &&
              s.longitude == destination.longitude,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe route to shelter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Use my location as start',
            onPressed: _useMyLocationAsOrigin,
          ),
          if (provider.origin != null || provider.destination != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Reset',
              onPressed: () {
                context.read<RouteProvider>().reset();
                Provider.of<ActiveRouteProvider?>(
                  context,
                  listen: false,
                )?.clear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          LocationAlertBanner(
            userLocation: _liveLocation ?? _initialCenter,
            onTap: () {
              // TODO: navigate to a full alert-detail screen.
            },
          ),
          if (_locationDenied) const _LocationDeniedBanner(),
          _ModeAndStatusBar(provider: provider),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      SafeZoneBaseMap(
                        initialCenter: _initialCenter,
                        liveLocation: _liveLocation,
                        controller: _mapController,
                        onTap: _onMapTap,
                        overlayLayers: [
                          // Drawn so it's visible *why* the chosen route
                          // may curve away from the straight-line path —
                          // same alert data RouteHazardScorer used to
                          // pick the route in the first place.
                          CircleLayer(
                            circles: [
                              for (final alert in activeAlerts)
                                CircleMarker(
                                  point: LatLng(
                                    alert.centerLat,
                                    alert.centerLng,
                                  ),
                                  radius: alert.radiusMeters.toDouble(),
                                  useRadiusInMeter: true,
                                  color: _alertFillColor(alert.severity),
                                  borderColor: _alertBorderColor(
                                    alert.severity,
                                  ),
                                  borderStrokeWidth: 1.5,
                                ),
                            ],
                          ),
                          if (provider.result != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: provider.result!.points,
                                  strokeWidth: 5,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              // Shelters remain visible/tappable as a
                              // one-tap destination shortcut alongside
                              // free tap-to-place.
                              for (final shelter in provider.shelters)
                                Marker(
                                  point: LatLng(
                                    shelter.latitude,
                                    shelter.longitude,
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: _ShelterMarker(
                                    shelter: shelter,
                                    isSelected:
                                        destination != null &&
                                        destination.latitude ==
                                            shelter.latitude &&
                                        destination.longitude ==
                                            shelter.longitude,
                                    onTap: () => _onShelterTap(shelter),
                                  ),
                                ),
                              if (provider.origin != null)
                                Marker(
                                  point: provider.origin!,
                                  width: 32,
                                  height: 32,
                                  child: const _PointMarker(
                                    icon: Icons.trip_origin,
                                    color: Color(0xFF1E88E5),
                                  ),
                                ),
                              // A freely-tapped destination (not a
                              // shelter) gets its own pin — shelters
                              // already draw their own marker above.
                              if (destination != null && !destinationIsShelter)
                                Marker(
                                  point: destination,
                                  width: 32,
                                  height: 32,
                                  child: const _PointMarker(
                                    icon: Icons.flag,
                                    color: Color(0xFFD32F2F),
                                  ),
                                ),
                              // Live device position — always on the map,
                              // independent of origin/destination.
                              if (_liveLocation != null)
                                Marker(
                                  point: _liveLocation!,
                                  width: 28,
                                  height: 28,
                                  child: const LiveLocationMarker(),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: CachedMapIndicator(
                          showingCachedTiles:
                              safeZoneTileCache.showingCachedTiles,
                        ),
                      ),
                      if (provider.isLoadingShelters || provider.isLoading)
                        const Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (provider.error != null)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: _ErrorBanner(message: provider.error!),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (provider.result != null) ...[
            _RouteHazardNotice(result: provider.result!),
            RouteSummaryCard(result: provider.result!),
          ],
        ],
      ),
    );
  }
}

class _LocationDeniedBanner extends StatelessWidget {
  const _LocationDeniedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.location_off, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Location access is off — enable it in Settings to see your position and route from it.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same translucent-fill / solid-border severity treatment used on
/// HomeScreen and IncidentsScreen's maps, duplicated locally rather than
/// shared — matches how those two screens already do it in this codebase.
Color _alertFillColor(AlertSeverity severity) {
  switch (severity) {
    case AlertSeverity.green:
      return AppColors.severityGreen.withValues(alpha: 0.33);
    case AlertSeverity.yellow:
      return AppColors.severityYellow.withValues(alpha: 0.33);
    case AlertSeverity.orange:
      return AppColors.severityOrange.withValues(alpha: 0.33);
    case AlertSeverity.red:
      return AppColors.severityRed.withValues(alpha: 0.33);
  }
}

Color _alertBorderColor(AlertSeverity severity) {
  switch (severity) {
    case AlertSeverity.green:
      return AppColors.severityGreen;
    case AlertSeverity.yellow:
      return AppColors.severityYellow;
    case AlertSeverity.orange:
      return AppColors.severityOrange;
    case AlertSeverity.red:
      return AppColors.severityRed;
  }
}

/// Tells the person whether the route RouteHazardScorer picked fully
/// avoided active alert zones, or — if every alternative crossed one —
/// which severity it still had to cross.
class _RouteHazardNotice extends StatelessWidget {
  final RouteResult result;
  const _RouteHazardNotice({required this.result});

  @override
  Widget build(BuildContext context) {
    if (!result.passesThroughHazard) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_outlined, size: 16, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'This route avoids active alert zones',
                style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
              ),
            ),
          ],
        ),
      );
    }

    final color = _alertBorderColor(result.worstHazardSeverity!);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.worstHazardSeverity == AlertSeverity.red
                  ? 'Every available route crosses a red zone — this one '
                        'minimizes the distance through it'
                  : 'This is the safest route available — it still '
                        'briefly crosses a ${result.worstHazardSeverity!.label} zone',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelterMarker extends StatelessWidget {
  final Shelter shelter;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShelterMarker({
    required this.shelter,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? const Color(0xFFD32F2F)
        : const Color(0xFF2E7D32);
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: shelter.name,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
          ),
          child: const Icon(Icons.night_shelter, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _PointMarker extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _PointMarker({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}

class _ModeAndStatusBar extends StatelessWidget {
  final RouteProvider provider;
  const _ModeAndStatusBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SegmentedButton<TravelMode>(
            segments: const [
              ButtonSegment(
                value: TravelMode.walking,
                icon: Icon(Icons.directions_walk),
                label: Text('Walk'),
              ),
              ButtonSegment(
                value: TravelMode.driving,
                icon: Icon(Icons.directions_car),
                label: Text('Drive'),
              ),
            ],
            selected: {provider.mode},
            onSelectionChanged: (s) =>
                context.read<RouteProvider>().setMode(s.first),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              provider.origin == null
                  ? 'Tap the map to set your start point'
                  : provider.destination == null
                  ? 'Tap the map or a shelter to set your destination'
                  : '',
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
