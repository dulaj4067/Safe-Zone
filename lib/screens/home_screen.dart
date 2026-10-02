import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/app_user.dart';
import '../models/incident.dart';
import '../models/risk_zone.dart';
import '../models/shelter.dart';
import '../models/zone.dart';
import '../models/circle_member_location.dart';
import '../providers/alert_provider.dart';
import '../providers/incident_provider.dart';
import '../models/route_result.dart';
import '../providers/active_route_provider.dart';
import '../providers/map_focus_provider.dart';
import '../providers/safety_provider.dart';
import '../theme/app_colors.dart';
import '../services/activity_history_service.dart';
import '../services/location_service.dart';
import '../services/shelter_service.dart';
import '../widgets/severity_badge.dart';
import '../widgets/active_alerts_sheet.dart';
import '../widgets/active_route_banner.dart';
import '../widgets/heatmap_layer.dart';
import '../widgets/live_location_marker.dart';
import '../widgets/location_alert_banner.dart';
import '../widgets/loved_one_marker.dart';
import '../widgets/map_filter_sheet.dart';
import '../widgets/resume_dropdown.dart';
import '../widgets/safe_zone_base_map.dart';
import '../widgets/shelter_marker.dart';
import '../widgets/shelter_preview_card.dart';
import '../utils/format_utils.dart';
import '../utils/map_tile_config.dart';
import '../widgets/incident_detail_sheet.dart';
import '../screens/incident_detail_screen.dart';
import '../screens/shelter_detail_screen.dart';
import '../screens/shelter_directions_screen.dart';
import '../screens/select_safety_circle_screen.dart';
import '../services/supabase_service.dart';

/// SafeZone home tab — district map with live alert-radius overlays
/// (from AlertProvider.activeAlerts), incident markers (from
/// IncidentProvider), shelter markers (fetched locally via
/// ShelterService), and the device's own live GPS position (via
/// LocationService), always shown as a distinct marker.
class HomeScreen extends StatefulWidget {
  /// Optional — pass AppShell's loaded `_zones` if you want the chip in
  /// the top-left corner to label the district nearest the map center.
  /// Omit it and the chip just won't render.
  final List<Zone> zones;
  final AppUser? currentUser;
  final ValueChanged<ActivityEntry>? onResumeActivity;

  const HomeScreen({
    super.key,
    this.zones = const [],
    this.currentUser,
    this.onResumeActivity,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const LatLng _initialCenter = LatLng(6.9615, 79.9010);
  static const Distance _distance = Distance();

  /// Minimum displacement (metres) between the backgrounded position and the
  /// current position that triggers the "Want to pick up where you left off?"
  /// resume prompt. 500 m is large enough to ignore GPS jitter (already
  /// filtered to 5 m in LocationService) while still being meaningful in a
  /// disaster-response context.
  static const double _driftThresholdMeters = 500.0;

  final ShelterService _shelterService = ShelterService();
  final LocationService _locationService = LocationService();
  StreamSubscription<LatLng>? _positionSub;

  List<Shelter> _shelters = [];
  LatLng? _liveLocation;
  bool _locationDenied = false;

  /// The map centre saved when the app was last backgrounded, so the resume
  /// prompt can offer to re-centre back to it after drift is detected.
  LatLng? _lastKnownLocation;

  /// Prevents the resume modal from firing more than once per foreground cycle.
  bool _resumeModalShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().load();
      // AlertProvider.init() is already called once from AppShell, so we
      // don't call it again here — just read its current state below.
    });
    _loadShelters();
    _startWatchingLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    super.dispose();
  }

  // ─── App lifecycle — drift detection ──────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Snapshot the current position before going to background.
      if (_liveLocation != null) {
        _lastKnownLocation = _liveLocation;
        _resumeModalShown =
            false; // reset so the next foreground entry can fire
      }
    } else if (state == AppLifecycleState.resumed) {
      _checkForDriftAndPrompt();
    }
  }

  /// Compares the current GPS position to [_lastKnownLocation]. If the device
  /// has drifted more than [_driftThresholdMeters], shows the resume modal.
  Future<void> _checkForDriftAndPrompt() async {
    if (_resumeModalShown) return;
    final saved = _lastKnownLocation;
    final current = _liveLocation;
    if (saved == null || current == null) return;

    final driftM = _distance(saved, current);
    if (driftM < _driftThresholdMeters) return;

    _resumeModalShown = true;
    if (!mounted) return;
    _showResumeModal(savedLocation: saved);
  }

  /// Shows a one-tap-dismissible bottom modal asking the user whether they
  /// want to re-centre the map to their last-known position after drift.
  void _showResumeModal({required LatLng savedLocation}) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: true, // one tap on the backdrop closes it
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ResumeSessionModal(
        onResume: () {
          Navigator.of(ctx).pop();
          // Re-centre the map via the map widget's key/controller — we pass
          // savedLocation through the _SafeZoneMap widget's resumeCenter param.
          setState(() => _resumeCenter = savedLocation);
        },
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  /// When non-null the map should snap back to this centre on its next build.
  /// Cleared immediately after consumption so it only fires once.
  LatLng? _resumeCenter;

  Future<void> _loadShelters() async {
    try {
      final shelters = await _shelterService.fetchShelters();
      if (mounted) setState(() => _shelters = shelters);
    } catch (_) {
      // Leave shelters empty on failure rather than crashing the map —
      // same fail-quiet approach RouteProvider.loadShelters() uses.
    }
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
      if (mounted && fix != null && _liveLocation == null) {
        setState(() => _liveLocation = fix);
      }
    });
    _positionSub = _locationService.watchPosition().listen(
      (position) {
        if (mounted) setState(() => _liveLocation = position);
      },
      onError: (_) {
        // Leave whatever last-known position we have rather than
        // clearing it on a transient GPS/provider error.
      },
    );
  }

  String? _nearestZoneName(LatLng center) {
    Zone? nearest;
    double? bestDistance;
    for (final zone in widget.zones) {
      if (zone.centroidLat == null || zone.centroidLng == null) continue;
      final d = _distance(center, LatLng(zone.centroidLat!, zone.centroidLng!));
      if (bestDistance == null || d < bestDistance) {
        bestDistance = d;
        nearest = zone;
      }
    }
    return nearest?.name;
  }

  /// `sampleRiskZones` is hardcoded sample data with no real backend source
  /// (see its doc comment) — assigning a real user a "current risk zone"
  /// from it would mean showing them a fabricated flood-risk warning, which
  /// is actively misleading for a disaster app. Gated to debug builds only,
  /// same as `_debugSampleZones` below, until a real zone-risk data source
  /// exists. In release builds this always returns null, so "Share my ETA"
  /// simply has no zone context rather than a made-up one.
  RiskZone? _nearestRiskZone(LatLng center) {
    if (!kDebugMode) return null;
    RiskZone? nearest;
    double? bestDistance;
    for (final zone in sampleRiskZones) {
      final centroid = zone.boundary.reduce(
        (a, b) => LatLng(
          (a.latitude + b.latitude) / 2,
          (a.longitude + b.longitude) / 2,
        ),
      );
      final d = _distance(center, centroid);
      if (bestDistance == null || d < bestDistance) {
        bestDistance = d;
        nearest = zone;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    final incidents = context.watch<IncidentProvider>().sortedIncidents;
    final activeAlerts = context.watch<AlertProvider>().activeAlerts;
    // District chip and the alert banner's relevance ranking should both
    // reflect where the person actually is once we have a GPS fix,
    // falling back to the district default until then.
    final effectiveCenter = _liveLocation ?? _initialCenter;
    final districtLabel = _nearestZoneName(effectiveCenter);
    final nearestRiskZone = _nearestRiskZone(effectiveCenter);

    // Consume the resume-centre once so the map animates to it this frame
    // and subsequent rebuilds don't re-trigger the move.
    final resumeTarget = _resumeCenter;
    if (resumeTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _resumeCenter = null);
      });
    }

    return Scaffold(
      // Uses the app's theme background (AppTheme.light/dark set
      // scaffoldBackgroundColor to AppColors.mist / AppColors.deepWater)
      // rather than a hardcoded color, so this screen stays in sync with
      // the rest of the app and with dark mode.
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _HeaderRow(),
            Builder(
              builder: (context) {
                final history = Provider.of<ActivityHistoryService?>(context);
                if (history == null) return const SizedBox.shrink();
                final hasEmergencyAlert = activeAlerts.any(
                  (alert) => alert.severity == AlertSeverity.red,
                );
                return ResumeDropdown(
                  items: history.entries,
                  onResume: widget.onResumeActivity ?? (_) {},
                  hasEmergencyAlert: hasEmergencyAlert,
                );
              },
            ),
            if (activeAlerts.isNotEmpty)
              LocationAlertBanner(userLocation: effectiveCenter),
            if (_locationDenied) const _LocationDeniedBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SelectSafetyCircleScreen(
                          currentRiskZone: nearestRiskZone,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_location_rounded),
                  label: const Text('Share my ETA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F6F8B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
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
                  child: _SafeZoneMap(
                    center: effectiveCenter,
                    incidents: incidents,
                    alerts: activeAlerts,
                    shelters: _shelters,
                    liveLocation: _liveLocation,
                    districtLabel: districtLabel,
                    currentUser: widget.currentUser,
                    resumeCenter: resumeTarget,
                  ),
                ),
              ),
            ),
          ],
        ),
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
              'Location access is off — enable it in Settings to see your position on the map.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SafeZone', style: textTheme.headlineMedium),
                const SizedBox(height: 2),
                Text(
                  'Sri Lanka Disaster Early Warning',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              color: const Color(0xFF2A2A2A),
              onPressed: () => showActiveAlertsSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Debug-only stand-ins for AlertProvider data, so the banded
/// yellow/orange/red look from the mockup is visible during development
/// even before real alerts exist in Supabase. These never show in release
/// builds. Delete this once you have real seeded alert data to test with.
const bool _showSampleZonesInDebug = true;

final List<({LatLng center, double radiusMeters, AlertSeverity severity})>
_debugSampleZones = [
  (
    center: const LatLng(6.9695, 79.8975),
    radiusMeters: 1600,
    severity: AlertSeverity.yellow,
  ),
  (
    center: const LatLng(6.9615, 79.9010),
    radiusMeters: 1400,
    severity: AlertSeverity.orange,
  ),
  (
    center: const LatLng(6.9560, 79.9075),
    radiusMeters: 1200,
    severity: AlertSeverity.red,
  ),
  (
    center: const LatLng(6.9520, 79.9140),
    radiusMeters: 1500,
    severity: AlertSeverity.yellow,
  ),
];

class _SafeZoneMap extends StatefulWidget {
  final LatLng center;
  final List<Incident> incidents;
  final List<DisasterAlert> alerts;
  final List<Shelter> shelters;
  final LatLng? liveLocation;
  final String? districtLabel;
  final AppUser? currentUser;

  /// When non-null, the map controller will move to this position
  /// on the next frame (resume-from-drift behaviour).
  final LatLng? resumeCenter;

  const _SafeZoneMap({
    required this.center,
    required this.incidents,
    required this.alerts,
    required this.shelters,
    required this.liveLocation,
    required this.districtLabel,
    this.currentUser,
    this.resumeCenter,
  });

  @override
  State<_SafeZoneMap> createState() => _SafeZoneMapState();
}

class _SafeZoneMapState extends State<_SafeZoneMap> {
  bool _showHeatmap = false;
  BaseMapStyle _baseMapStyle = BaseMapStyle.street;
  MapFilters _filters = const MapFilters();

  /// Shelter whose preview card is showing over the map, if any.
  Shelter? _selectedShelter;

  final MapController _mapController = MapController();
  MapFocusProvider? _mapFocus;
  ActiveRouteProvider? _activeRoute;
  RouteResult? _framedRoute;

  @override
  void initState() {
    super.initState();
    _mapFocus = Provider.of<MapFocusProvider?>(context, listen: false)
      ?..addListener(_onMapFocus);
    _activeRoute = Provider.of<ActiveRouteProvider?>(context, listen: false)
      ?..addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _mapFocus?.removeListener(_onMapFocus);
    _activeRoute?.removeListener(_onRouteChanged);
    _mapController.dispose();
    super.dispose();
  }

  /// Frame each newly computed route once, so coming back to Home after
  /// working one out shows the whole thing rather than wherever the map
  /// was last left.
  void _onRouteChanged() {
    final route = _activeRoute?.route;
    if (route == null || identical(route.result, _framedRoute)) return;
    _framedRoute = route.result;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitRoute(route);
    });
  }

  void _fitRoute(ActiveRoute route) => _mapController.fitCamera(
    CameraFit.bounds(
      bounds: route.result.bounds,
      padding: const EdgeInsets.fromLTRB(40, 90, 70, 40),
    ),
  );

  void _openDirections(Shelter shelter) {
    setState(() => _selectedShelter = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShelterDirectionsScreen(destination: shelter),
      ),
    );
  }

  /// A "show on map" request (e.g. tapping the Shelter page's mini map):
  /// fly to the shelter and open its preview card. If the current filters
  /// would hide it, relax just the shelter filters so the card can show.
  void _onMapFocus() {
    final shelter = _mapFocus?.shelter;
    if (shelter == null || !mounted) return;
    setState(() {
      _selectedShelter = shelter;
      if (_filters.visibleShelters([shelter]).isEmpty) {
        _filters = _filters.copyWith(shelters: true, openSheltersOnly: false);
      }
    });
    // After the tab switch has laid the map out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final zoom = _mapController.camera.zoom;
      _mapController.move(
        LatLng(shelter.latitude, shelter.longitude),
        zoom < 15 ? 15 : zoom,
      );
    });
  }

  void _openFilters() => showMapFilterSheet(
    context,
    current: _filters,
    onChanged: (next) => setState(() => _filters = next),
    style: _baseMapStyle,
    onStyleChanged: (s) => setState(() => _baseMapStyle = s),
    heatmap: _showHeatmap,
    onHeatmapChanged: (v) => setState(() => _showHeatmap = v),
  );

  void _openShelter(Shelter shelter) {
    setState(() => _selectedShelter = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShelterDetailScreen(
          shelter: shelter,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _showLovedOneSheet(BuildContext context, CircleMemberLocation member) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LovedOneMarker(
                  initials: member.initials,
                  isActive: member.isActive,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        member.relationship,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  member.isActive ? Icons.podcasts : Icons.history,
                  size: 16,
                  color: member.isActive
                      ? AppColors.severityGreen
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  member.isActive
                      ? 'Actively sharing their ETA'
                      : member.lastSeenAt != null
                      ? 'Last seen ${timeAgo(member.lastSeenAt!)}'
                      : 'Last seen location unknown',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ({IconData icon, Color color}) _markerStyleFor(Incident incident) {
    if (incident.isSos) {
      return (icon: Icons.warning_rounded, color: const Color(0xFFD32F2F));
    }
    switch (incident.category) {
      case IncidentCategory.trappedPerson:
        return (icon: Icons.warning_rounded, color: const Color(0xFFD32F2F));
      case IncidentCategory.waterlogging:
        return (icon: Icons.water_drop, color: const Color(0xFF1E88E5));
      case IncidentCategory.blockedRoad:
        return (icon: Icons.block, color: const Color(0xFFF57C00));
      case IncidentCategory.powerOutage:
        return (icon: Icons.flash_off, color: const Color(0xFFFBC02D));
      case IncidentCategory.structuralDamage:
        return (icon: Icons.domain_disabled, color: const Color(0xFF8E24AA));
      case IncidentCategory.other:
        return (icon: Icons.place, color: const Color(0xFF616161));
    }
  }

  void _showAlertSheet(
    BuildContext context, {
    required String title,
    required AlertSeverity severity,
    String? instructions,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: severityColor(severity),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  severity.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: severityColor(severity),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (instructions != null) ...[
              const SizedBox(height: 8),
              Text(instructions),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showDebugZones =
        _showSampleZonesInDebug && kDebugMode && widget.alerts.isEmpty;
    final alerts = _filters.visibleAlerts(widget.alerts);
    final incidents = _filters.visibleIncidents(widget.incidents);
    final shelters = _filters.visibleShelters(widget.shelters);
    final family = _filters.family
        ? context.watch<SafetyProvider>().circleLocations
        : const <CircleMemberLocation>[];
    // Drop the preview if a filter has since hidden that shelter. Prefer
    // the map's own copy; fall back to the selected object itself in case
    // the home list hasn't loaded it yet (e.g. arriving from "View on map").
    final pending = _selectedShelter;
    final selected =
        shelters.where((s) => s.id == pending?.id).firstOrNull ??
        (pending != null && _filters.visibleShelters([pending]).isNotEmpty
            ? pending
            : null);
    final activeRoute = context.watch<ActiveRouteProvider?>()?.route;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          SafeZoneBaseMap(
            // Tapping empty map dismisses the shelter preview.
            onTap: (_, _) {
              if (_selectedShelter != null) {
                setState(() => _selectedShelter = null);
              }
            },
            controller: _mapController,
            initialCenter: widget.center,
            liveLocation: widget.liveLocation,
            resumeCenter: widget.resumeCenter,
            // The route banner takes the top of the map while active.
            topLeftOverlay: widget.districtLabel != null && activeRoute == null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.districtLabel!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  )
                : null,
            // Style, heatmap and filters all live behind one button.
            baseMapStyle: _baseMapStyle,
            extraControls: [
              MapFilterButton(
                changedCount: _filters.changedCount,
                onTap: _openFilters,
              ),
            ],
            overlayLayers: [
              // Heatmap layer — sits between the base tiles and the alert
              // circles so it never obscures interactive elements.
              if (_showHeatmap) HeatmapLayer(incidents: incidents),
              CircleLayer(
                circles: [
                  for (final alert in alerts)
                    CircleMarker(
                      point: LatLng(alert.centerLat, alert.centerLng),
                      radius: alert.radiusMeters.toDouble(),
                      useRadiusInMeter: true,
                      color: severityFillColor(alert.severity),
                      borderColor: severityColor(alert.severity),
                      borderStrokeWidth: 1.5,
                    ),
                  if (showDebugZones)
                    for (final zone in _debugSampleZones)
                      CircleMarker(
                        point: zone.center,
                        radius: zone.radiusMeters,
                        useRadiusInMeter: true,
                        color: severityFillColor(zone.severity),
                        borderColor: severityColor(zone.severity),
                        borderStrokeWidth: 1.5,
                      ),
                ],
              ),
              if (activeRoute != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: activeRoute.result.points,
                      strokeWidth: 5,
                      color: AppColors.deepEstuary,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // A route to a tapped point (not a shelter) gets a flag;
                  // shelters already have their own pin.
                  if (activeRoute != null && activeRoute.shelter == null)
                    Marker(
                      point: activeRoute.destination,
                      width: 32,
                      height: 32,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.flag,
                        color: AppColors.severityRed,
                        size: 32,
                      ),
                    ),
                  // Tap targets over each alert circle's center — flutter_map's
                  // CircleLayer has no built-in tap handling, so this gives
                  // each circle a fixed-size interactive hotspot.
                  for (final alert in alerts)
                    Marker(
                      point: LatLng(alert.centerLat, alert.centerLng),
                      width: 28,
                      height: 28,
                      child: GestureDetector(
                        onTap: () => _showAlertSheet(
                          context,
                          title: alert.title,
                          severity: alert.severity,
                          instructions: alert.instructions,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  // Shelters — tap opens that shelter's full Shelter page.
                  for (final shelter in shelters)
                    Marker(
                      point: LatLng(shelter.latitude, shelter.longitude),
                      width: 36,
                      height: 36,
                      child: ShelterMarker(
                        shelter: shelter,
                        isSelected: shelter.id == selected?.id,
                        onTap: () => setState(() => _selectedShelter = shelter),
                      ),
                    ),
                  for (final incident in incidents)
                    Marker(
                      point: LatLng(incident.latitude, incident.longitude),
                      width: 36,
                      height: 36,
                      child: Builder(
                        builder: (context) {
                          final style = _markerStyleFor(incident);
                          return GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                builder: (_) => IncidentDetailSheet(
                                  incident: incident,
                                  onViewDetails: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => IncidentDetailScreen(
                                          incident: incident,
                                          currentUser: widget.currentUser,
                                        ),
                                      ),
                                    );
                                  },
                                  onConfirm: () {
                                    final userId =
                                        SupabaseService.currentUserId;
                                    if (userId != null) {
                                      context
                                          .read<IncidentProvider>()
                                          .confirmIncident(
                                            incidentId: incident.id,
                                            memberId: userId,
                                          );
                                    }
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: style.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: Icon(
                                style.icon,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  // Safety-circle contacts' last-known locations (only
                  // ones who are registered app users and have ever shared
                  // a location show up here — see SafetyProvider).
                  for (final member in family)
                    Marker(
                      point: LatLng(member.lat!, member.lng!),
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        onTap: () => _showLovedOneSheet(context, member),
                        child: LovedOneMarker(
                          initials: member.initials,
                          isActive: member.isActive,
                        ),
                      ),
                    ),
                  // The device's own live position — always shown,
                  // independent of incidents/shelters/alerts.
                  if (widget.liveLocation != null)
                    Marker(
                      point: widget.liveLocation!,
                      width: 28,
                      height: 28,
                      child: const LiveLocationMarker(),
                    ),
                ],
              ),
            ],
          ),
          if (selected != null)
            Positioned(
              left: 12,
              // Leaves the right-hand button column uncovered.
              right: 68,
              bottom: 12,
              child: ShelterPreviewCard(
                shelter: selected,
                userLocation: widget.liveLocation,
                onOpen: () => _openShelter(selected),
                onRoute: () => _openDirections(selected),
                onClose: () => setState(() => _selectedShelter = null),
              ),
            ),
          if (activeRoute != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: ActiveRouteBanner(
                route: activeRoute,
                onTap: () => _fitRoute(activeRoute),
                onOpenDirections: activeRoute.shelter == null
                    ? null
                    : () => _openDirections(activeRoute.shelter!),
                onClear: () => _activeRoute?.clear(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Resume-session bottom modal ────────────────────────────────────────────

/// One-tap-dismissible bottom sheet shown when drift is detected after the
/// app returns to the foreground.
///
/// Requirements met:
///   • Triggered externally (only after drift sensing — caller's responsibility)
///   • Question phrasing: "Want to pick up where you left off?"
///   • Dismissible with one tap: tapping the backdrop OR the "Not now" button
///     closes the sheet without any forced interaction.
class _ResumeSessionModal extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onDismiss;

  const _ResumeSessionModal({required this.onResume, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C7C89).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Color(0xFF1C7C89),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Want to pick up where you left off?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Text(
                    "Looks like you've moved. Your previous map view is still saved.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDismiss,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Not now'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: onResume,
                        icon: const Icon(Icons.redo_rounded, size: 18),
                        label: const Text('Go back'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1C7C89),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
