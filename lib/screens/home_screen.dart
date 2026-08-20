import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/incident.dart';
import '../models/zone.dart';
import '../providers/alert_provider.dart';
import '../providers/incident_provider.dart';
import '../theme/app_colors.dart';

/// SafeZone home tab — district map with live alert-radius overlays
/// (from AlertProvider.activeAlerts) and incident markers (from
/// IncidentProvider). The global flood-warning banner is already handled
/// by AlertBanner in AppShell, so this screen doesn't duplicate it.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().load();
      // AlertProvider.init() is already called once from AppShell, so we
      // don't call it again here — just read its current state below.
    });
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
    final districtLabel = _nearestZoneName(_initialCenter);

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
                    center: _initialCenter,
                    incidents: incidents,
                    alerts: activeAlerts,
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
        ],
      ),
    );
  }
}

/// Which base map style is currently showing. Kept as an enum rather than
/// a bool so a third style (e.g. satellite) can be added later without
/// renaming anything.
enum _BaseMapStyle { street, topo }

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

Color _severityFillColor(AlertSeverity severity) {
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

Color _severityBorderColor(AlertSeverity severity) {
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

class _SafeZoneMap extends StatefulWidget {
  final LatLng center;
  final List<Incident> incidents;
  final List<DisasterAlert> alerts;
  final String? districtLabel;

  const _SafeZoneMap({
    required this.center,
    required this.incidents,
    required this.alerts,
    required this.districtLabel,
  });

  @override
  State<_SafeZoneMap> createState() => _SafeZoneMapState();
}

class _SafeZoneMapState extends State<_SafeZoneMap> {
  final MapController _mapController = MapController();
  _BaseMapStyle _baseMapStyle = _BaseMapStyle.street;

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
                    color: _severityBorderColor(severity),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  severity.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _severityBorderColor(severity),
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
      _baseMapStyle = _baseMapStyle == _BaseMapStyle.street
          ? _BaseMapStyle.topo
          : _BaseMapStyle.street;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showDebugZones = _showSampleZonesInDebug && kDebugMode && widget.alerts.isEmpty;
    final isTopo = _baseMapStyle == _BaseMapStyle.topo;

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
              if (isTopo)
                // OpenTopoMap — free, keyless XYZ tiles with contour lines
                // and hillshading, so elevation differences across a
                // district are actually visible. Tiles stop at z17, so we
                // cap maxNativeZoom there and let flutter_map upscale the
                // last tile for any zoom beyond that instead of failing
                // to load.
                TileLayer(
                  urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.safezone',
                  maxNativeZoom: 17,
                )
              else
                // Free, keyless raster tiles — no API key or billing setup
                // required. Swap the urlTemplate for any XYZ-compatible
                // provider if you want a different look.
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.safezone',
                ),
              CircleLayer(
                circles: [
                  for (final alert in widget.alerts)
                    CircleMarker(
                      point: LatLng(alert.centerLat, alert.centerLng),
                      radius: alert.radiusMeters.toDouble(),
                      useRadiusInMeter: true,
                      color: _severityFillColor(alert.severity),
                      borderColor: _severityBorderColor(alert.severity),
                      borderStrokeWidth: 1.5,
                    ),
                  if (showDebugZones)
                    for (final zone in _debugSampleZones)
                      CircleMarker(
                        point: zone.center,
                        radius: zone.radiusMeters,
                        useRadiusInMeter: true,
                        color: _severityFillColor(zone.severity),
                        borderColor: _severityBorderColor(zone.severity),
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
                ],
              ),
              // Required by OpenTopoMap's (and CartoDB's) usage policy.
              // Shown for both styles so it's always visible regardless
              // of which base layer is active.
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  if (isTopo)
                    const TextSourceAttribution(
                      'Map data: OpenStreetMap contributors, SRTM | Map style: OpenTopoMap (CC-BY-SA)',
                    )
                  else
                    const TextSourceAttribution(
                      'Map data: OpenStreetMap contributors | Tiles: CARTO',
                    ),
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
                _MapLayerToggleButton(isTopo: isTopo, onTap: _toggleBaseMapStyle),
                const SizedBox(height: 12),
                _ZoomButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                const SizedBox(height: 8),
                _ZoomButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: const Color(0xFF2A2A2A)),
        ),
      ),
    );
  }
}

/// Toggles the base map between the warm street style and OpenTopoMap's
/// terrain/elevation style. Icon flips so it always shows what tapping it
/// will switch *to*, matching the convention used elsewhere in the app.
class _MapLayerToggleButton extends StatelessWidget {
  final bool isTopo;
  final VoidCallback onTap;
  const _MapLayerToggleButton({required this.isTopo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            isTopo ? Icons.map_outlined : Icons.terrain,
            size: 20,
            color: const Color(0xFF2A2A2A),
          ),
        ),
      ),
    );
  }
}