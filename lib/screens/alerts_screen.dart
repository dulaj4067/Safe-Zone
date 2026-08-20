import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/incident.dart';
import '../providers/alert_provider.dart';
import '../providers/incident_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/incident_detail_sheet.dart';

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().load();
      // AlertProvider.init() is already called once from AppShell, so we
      // don't call it again here — the map below just reads its current
      // state via context.watch, same pattern as HomeScreen.
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncidentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidents'),
        actions: [
          IconButton(
            icon: Icon(
              provider.viewMode == IncidentViewMode.map
                  ? Icons.list
                  : Icons.map,
            ),
            tooltip: provider.viewMode == IncidentViewMode.map
                ? 'Switch to list'
                : 'Switch to map',
            onPressed: () {
              context.read<IncidentProvider>().setViewMode(
                    provider.viewMode == IncidentViewMode.map
                        ? IncidentViewMode.list
                        : IncidentViewMode.map,
                  );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (provider.isOffline) _OfflineBanner(lastUpdated: provider.lastUpdated),
          Expanded(
            child: provider.isLoading && provider.incidents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.viewMode == IncidentViewMode.map
                    ? Padding(
                        padding: const EdgeInsets.all(16),
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
                          child: const ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            child: _AlertZonesMap(),
                          ),
                        ),
                      )
                    : _IncidentList(incidents: provider.sortedIncidents),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final DateTime? lastUpdated;
  const _OfflineBanner({this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    final label = lastUpdated != null
        ? 'Showing cached data from ${lastUpdated!.hour.toString().padLeft(2, '0')}:${lastUpdated!.minute.toString().padLeft(2, '0')}'
        : 'Offline — no cached data available';
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Which base map style is currently showing on this screen's map tab.
/// Mirrors the same toggle on HomeScreen's map.
enum _BaseMapStyle { street, topo }

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

/// Map tab for the Incidents screen. Deliberately shows active alert
/// zones only (no incident pins) — the list tab on this same screen
/// already covers individual incidents, so this map is meant to give a
/// quick read on which areas currently have an active warning.
///
/// Uses the same free, keyless tile setup as HomeScreen's map: CartoDB
/// Voyager for street view, OpenTopoMap for terrain/elevation, with a
/// toggle between the two.
class _AlertZonesMap extends StatefulWidget {
  const _AlertZonesMap();

  @override
  State<_AlertZonesMap> createState() => _AlertZonesMapState();
}

class _AlertZonesMapState extends State<_AlertZonesMap> {
  // Same default center as HomeScreen, so this map opens on the same
  // district rather than an arbitrary point. Swap both for a real
  // device location once location services are wired up.
  static const LatLng _initialCenter = LatLng(6.9615, 79.9010);

  final MapController _mapController = MapController();
  _BaseMapStyle _baseMapStyle = _BaseMapStyle.street;

  void _showAlertSheet(BuildContext context, DisasterAlert alert) {
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
                    color: _severityBorderColor(alert.severity),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  alert.severity.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _severityBorderColor(alert.severity),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(alert.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (alert.instructions != null) ...[
              const SizedBox(height: 8),
              Text(alert.instructions!),
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
    final alerts = context.watch<AlertProvider>().activeAlerts;
    final isTopo = _baseMapStyle == _BaseMapStyle.topo;

    if (alerts.isEmpty) {
      // Still show the map (with the toggle/zoom controls) rather than
      // just text, so switching to this tab doesn't feel broken — just
      // let the person know there's nothing active right now.
      return Stack(
        children: [
          _buildMap(alerts, isTopo),
          const Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _NoActiveAlertsBanner(),
          ),
        ],
      );
    }

    return _buildMap(alerts, isTopo);
  }

  Widget _buildMap(List<DisasterAlert> alerts, bool isTopo) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: _initialCenter,
            initialZoom: 12,
            minZoom: 5,
            maxZoom: 18,
            interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            if (isTopo)
              TileLayer(
                urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.safezone',
                maxNativeZoom: 17,
              )
            else
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.safezone',
              ),
            CircleLayer(
              circles: [
                for (final alert in alerts)
                  CircleMarker(
                    point: LatLng(alert.centerLat, alert.centerLng),
                    radius: alert.radiusMeters.toDouble(),
                    useRadiusInMeter: true,
                    color: _severityFillColor(alert.severity),
                    borderColor: _severityBorderColor(alert.severity),
                    borderStrokeWidth: 1.5,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final alert in alerts)
                  Marker(
                    point: LatLng(alert.centerLat, alert.centerLng),
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () => _showAlertSheet(context, alert),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
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
    );
  }
}

class _NoActiveAlertsBanner extends StatelessWidget {
  const _NoActiveAlertsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF2E7D32)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No active alerts right now',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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

class _IncidentList extends StatelessWidget {
  final List<Incident> incidents;
  const _IncidentList({required this.incidents});

  @override
  Widget build(BuildContext context) {
    if (incidents.isEmpty) {
      return const Center(child: Text('No incidents reported nearby.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: incidents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final incident = incidents[index];
        return Card(
          color: incident.isSos ? Colors.red.shade50 : null,
          child: ListTile(
            leading: incident.isSos
                ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
                : const Icon(Icons.report_outlined),
            title: Text(incident.category.label),
            subtitle: Text(
              incident.description ?? 'No description provided',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text('${incident.credibilityScore} ✓'),
            onTap: () => showModalBottomSheet(
              context: context,
              builder: (_) => IncidentDetailSheet(
                incident: incident,
                onConfirm: () {
                  final userId = SupabaseService.currentUserId;
                  if (userId != null) {
                    context.read<IncidentProvider>().confirmIncident(
                          incidentId: incident.id,
                          memberId: userId,
                        );
                  }
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}