import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/incident.dart';
import '../models/shelter.dart';
import '../models/zone.dart';
import '../providers/alert_provider.dart';
import '../providers/incident_provider.dart';
import '../services/location_service.dart';
import '../services/shelter_service.dart';
import '../utils/map_tile_sources.dart';
import '../widgets/severity_badge.dart';
import '../widgets/app_logo_badge.dart';
import '../widgets/live_location_marker.dart';
import '../widgets/location_alert_banner.dart';
import '../widgets/map_controls.dart';
import '../widgets/shelter_marker.dart';

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

  const HomeScreen({super.key, this.zones = const []});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const LatLng _initialCenter = LatLng(6.9615, 79.9010);
  static const Distance _distance = Distance();

  final ShelterService _shelterService = ShelterService();
  final LocationService _locationService = LocationService();
  StreamSubscription<LatLng>? _positionSub;

  List<Shelter> _shelters = [];
  LatLng? _liveLocation;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();
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
    _positionSub?.cancel();
    super.dispose();
  }

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
      final d = _distance(
        center,
        LatLng(zone.centroidLat!, zone.centroidLng!),
      );
      if (bestDistance == null || d < bestDistance) {
        bestDistance = d;
        nearest = zone;
      }
    }
    return nearest?.name;
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

    return Scaffold(
      // Uses the app's theme background (AppTheme.light/dark set
      // scaffoldBackgroundColor to AppColors.mist / AppColors.deepWater)
      // rather than a hardcoded color, so this screen stays in sync with
      // the rest of the app and with dark mode.
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocationAlertBanner(
              userLocation: effectiveCenter,
              onTap: () {
                // TODO: navigate to a full alert-detail screen.
              },
            ),
            if (_locationDenied) const _LocationDeniedBanner(),
            const _HeaderRow(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
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
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              color: const Color(0xFF2A2A2A),
              onPressed: () {
                // TODO: navigate to the Alerts tab/screen.
              },
            ),
          ),
          const SizedBox(width: 8),
          const AppLogoBadge(),
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
  (center: const LatLng(6.9695, 79.8975), radiusMeters: 1600, severity: AlertSeverity.yellow),
  (center: const LatLng(6.9615, 79.9010), radiusMeters: 1400, severity: AlertSeverity.orange),
  (center: const LatLng(6.9560, 79.9075), radiusMeters: 1200, severity: AlertSeverity.red),
  (center: const LatLng(6.9520, 79.9140), radiusMeters: 1500, severity: AlertSeverity.yellow),
];

class _SafeZoneMap extends StatefulWidget {
  final LatLng center;
  final List<Incident> incidents;
  final List<DisasterAlert> alerts;
  final List<Shelter> shelters;
  final LatLng? liveLocation;
  final String? districtLabel;

  const _SafeZoneMap({
    required this.center,
    required this.incidents,
    required this.alerts,
    required this.shelters,
    required this.liveLocation,
    required this.districtLabel,
  });

  @override
  State<_SafeZoneMap> createState() => _SafeZoneMapState();
}

class _SafeZoneMapState extends State<_SafeZoneMap> {
  final MapController _mapController = MapController();
  BaseMapStyle _baseMapStyle = BaseMapStyle.street;

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

  void _showAlertSheet(BuildContext context, {required String title, required AlertSeverity severity, String? instructions}) {
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
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (instructions != null) ...[
              const SizedBox(height: 8),
              Text(instructions),
            ],
          ],
        ),
      ),
    );
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  void _toggleBaseMapStyle() {
    setState(() {
      _baseMapStyle = _baseMapStyle == BaseMapStyle.street ? BaseMapStyle.topo : BaseMapStyle.street;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showDebugZones = _showSampleZonesInDebug && kDebugMode && widget.alerts.isEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.center,
              initialZoom: 13,
              minZoom: 5,
              maxZoom: 18,
              // Explicit: drag-to-pan, pinch-to-zoom, double-tap zoom,
              // two-finger rotate, and mouse-wheel/trackpad zoom on web/desktop.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              buildBaseTileLayer(_baseMapStyle),
              CircleLayer(
                circles: [
                  for (final alert in widget.alerts)
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
              MarkerLayer(
                markers: [
                  // Tap targets over each alert circle's center — flutter_map's
                  // CircleLayer has no built-in tap handling, so this gives
                  // each circle a fixed-size interactive hotspot.
                  for (final alert in widget.alerts)
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
                  // Shelters — same ShelterMarker/detail sheet used on the
                  // routing map, so they look identical everywhere.
                  for (final shelter in widget.shelters)
                    Marker(
                      point: LatLng(shelter.latitude, shelter.longitude),
                      width: 36,
                      height: 36,
                      child: ShelterMarker(
                        shelter: shelter,
                        onTap: () => showShelterDetailSheet(context, shelter),
                      ),
                    ),
                  for (final incident in widget.incidents)
                    Marker(
                      point: LatLng(incident.latitude, incident.longitude),
                      width: 36,
                      height: 36,
                      child: Builder(builder: (context) {
                        final style = _markerStyleFor(incident);
                        return GestureDetector(
                          onTap: () {
                            // TODO: reuse IncidentDetailSheet here, same as
                            // your Hub/Incidents screen does.
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: style.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 3),
                              ],
                            ),
                            child: Icon(style.icon, color: Colors.white, size: 18),
                          ),
                        );
                      }),
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
              // Required by OpenTopoMap's (and CartoDB's) usage policy.
              // Shown for both styles so it's always visible regardless
              // of which base layer is active.
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution(attributionFor(_baseMapStyle)),
                ],
              ),
            ],
          ),
          if (widget.districtLabel != null)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: Text(
                  widget.districtLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              children: [
                MapLayerToggleButton(style: _baseMapStyle, onTap: _toggleBaseMapStyle),
                const SizedBox(height: 12),
                ZoomButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                const SizedBox(height: 8),
                ZoomButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}