import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/incident.dart';
import '../providers/alert_provider.dart';
import '../providers/incident_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../utils/map_tile_sources.dart';
import '../widgets/incident_card.dart';
import '../widgets/incident_detail_sheet.dart';
import '../widgets/map_controls.dart';
import '../widgets/severity_badge.dart';
import 'incident_detail_screen.dart';
import 'report_incident_screen.dart';

class IncidentsScreen extends StatefulWidget {
  final AppUser? currentUser;

  const IncidentsScreen({super.key, this.currentUser});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().load();
    });
  }

  void _openReportScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReportIncidentScreen(),
      ),
    );
  }

  void _openIncidentDetail(Incident incident) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentDetailScreen(
          incident: incident,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncidentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidents'),
        actions: [
          IconButton(
            icon: Icon(
              provider.viewMode == IncidentViewMode.map
                  ? Icons.list_alt_rounded
                  : Icons.map_outlined,
            ),
            tooltip: provider.viewMode == IncidentViewMode.map
                ? 'Switch to list view'
                : 'Switch to map view',
            onPressed: () {
              context.read<IncidentProvider>().setViewMode(
                    provider.viewMode == IncidentViewMode.map
                        ? IncidentViewMode.list
                        : IncidentViewMode.map,
                  );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh incidents',
            onPressed: () => context.read<IncidentProvider>().refresh(),
          ),
        ],
      ),
      floatingActionButton: provider.viewMode == IncidentViewMode.list
          ? FloatingActionButton.extended(
              onPressed: _openReportScreen,
              icon: const Icon(Icons.add),
              label: const Text('Report Incident'),
              backgroundColor: AppColors.deepEstuary,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Offline Banner ──────────────────────────────────────────────
          if (provider.isOffline)
            _OfflineBanner(lastUpdated: provider.lastUpdated),

          // ─── Header & Filter Bar ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: isDark ? AppColors.harborSurface : AppColors.cloud,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitor and report flood & disaster incidents in real-time.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                _FilterBar(
                  selectedStatus: provider.statusFilter,
                  selectedCategory: provider.categoryFilter,
                  sosOnly: provider.sosFilter,
                  onStatusChanged: (s) => provider.setStatusFilter(s),
                  onCategoryChanged: (c) => provider.setCategoryChanged(c),
                  onSosChanged: (sos) => provider.setSosFilter(sos),
                  onClearAll: () => provider.clearFilters(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ─── Body Content: Map vs List ───────────────────────────────────
          Expanded(
            child: provider.isLoading && provider.incidents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.errorMessage != null && provider.incidents.isEmpty
                    ? _ErrorState(
                        errorMessage: provider.errorMessage!,
                        onRetry: () => provider.refresh(),
                      )
                    : provider.viewMode == IncidentViewMode.map
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.all(Radius.circular(20)),
                                child: _IncidentsMap(
                                  incidents: provider.filteredIncidents,
                                  onIncidentTap: _openIncidentDetail,
                                ),
                              ),
                            ),
                          )
                        : _IncidentList(
                            incidents: provider.filteredIncidents,
                            onIncidentTap: _openIncidentDetail,
                            onReportTap: _openReportScreen,
                            onRefresh: () => provider.refresh(),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Bar Widget ────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final IncidentStatus? selectedStatus;
  final IncidentCategory? selectedCategory;
  final bool sosOnly;
  final ValueChanged<IncidentStatus?> onStatusChanged;
  final ValueChanged<IncidentCategory?> onCategoryChanged;
  final ValueChanged<bool> onSosChanged;
  final VoidCallback onClearAll;

  const _FilterBar({
    required this.selectedStatus,
    required this.selectedCategory,
    required this.sosOnly,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onSosChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // All chip
          FilterChip(
            label: const Text('All'),
            selected: selectedStatus == null && selectedCategory == null && !sosOnly,
            onSelected: (_) => onClearAll(),
          ),
          const SizedBox(width: 6),

          // SOS Emergency Filter
          FilterChip(
            avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
            label: const Text('SOS Only'),
            selected: sosOnly,
            selectedColor: AppColors.sosBackground,
            onSelected: (val) => onSosChanged(val),
          ),
          const SizedBox(width: 6),

          // Pending Filter
          FilterChip(
            label: const Text('Pending'),
            selected: selectedStatus == IncidentStatus.pending,
            onSelected: (val) => onStatusChanged(val ? IncidentStatus.pending : null),
          ),
          const SizedBox(width: 6),

          // Verified Filter
          FilterChip(
            label: const Text('Verified'),
            selected: selectedStatus == IncidentStatus.verified,
            onSelected: (val) => onStatusChanged(val ? IncidentStatus.verified : null),
          ),
          const SizedBox(width: 6),

          // Resolved Filter
          FilterChip(
            label: const Text('Resolved'),
            selected: selectedStatus == IncidentStatus.resolved,
            onSelected: (val) => onStatusChanged(val ? IncidentStatus.resolved : null),
          ),
          const SizedBox(width: 6),

          // Rejected Filter
          FilterChip(
            label: const Text('Rejected'),
            selected: selectedStatus == IncidentStatus.rejected,
            onSelected: (val) => onStatusChanged(val ? IncidentStatus.rejected : null),
          ),
        ],
      ),
    );
  }
}

// ─── List View ────────────────────────────────────────────────────────────────

class _IncidentList extends StatelessWidget {
  final List<Incident> incidents;
  final ValueChanged<Incident> onIncidentTap;
  final VoidCallback onReportTap;
  final Future<void> Function() onRefresh;

  const _IncidentList({
    required this.incidents,
    required this.onIncidentTap,
    required this.onReportTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (incidents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.seafoam.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.report_outlined, size: 48, color: AppColors.deepEstuary),
              ),
              const SizedBox(height: 16),
              const Text(
                'No incidents reported yet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                'Help keep your community informed during floods and extreme weather events.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onReportTap,
                icon: const Icon(Icons.add),
                label: const Text('Report an Incident'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: incidents.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final incident = incidents[index];
          return IncidentCard(
            incident: incident,
            onTap: () => onIncidentTap(incident),
          );
        },
      ),
    );
  }
}

// ─── Map View ─────────────────────────────────────────────────────────────────

class _IncidentsMap extends StatefulWidget {
  final List<Incident> incidents;
  final ValueChanged<Incident> onIncidentTap;

  const _IncidentsMap({
    required this.incidents,
    required this.onIncidentTap,
  });

  @override
  State<_IncidentsMap> createState() => _IncidentsMapState();
}

class _IncidentsMapState extends State<_IncidentsMap> {
  static const LatLng _initialCenter = LatLng(6.9615, 79.9010);
  final MapController _mapController = MapController();
  BaseMapStyle _baseMapStyle = BaseMapStyle.street;

  void _showIncidentSheet(Incident incident) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => IncidentDetailSheet(
        incident: incident,
        onViewDetails: () {
          Navigator.pop(context);
          widget.onIncidentTap(incident);
        },
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAlerts = context.watch<AlertProvider>().activeAlerts;

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
            buildBaseTileLayer(_baseMapStyle),
            CircleLayer(
              circles: [
                for (final alert in activeAlerts)
                  CircleMarker(
                    point: LatLng(alert.centerLat, alert.centerLng),
                    radius: alert.radiusMeters.toDouble(),
                    useRadiusInMeter: true,
                    color: severityFillColor(alert.severity),
                    borderColor: severityColor(alert.severity),
                    borderStrokeWidth: 1.5,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final incident in widget.incidents)
                  Marker(
                    point: LatLng(incident.latitude, incident.longitude),
                    width: 38,
                    height: 38,
                    child: GestureDetector(
                      onTap: () => _showIncidentSheet(incident),
                      child: Container(
                        decoration: BoxDecoration(
                          color: incident.isSos ? AppColors.severityRed : categoryColor(incident.category),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Icon(
                          incident.isSos ? Icons.warning_amber_rounded : categoryIcon(incident.category),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution(attributionFor(_baseMapStyle)),
              ],
            ),
          ],
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            children: [
              MapLayerToggleButton(
                style: _baseMapStyle,
                onTap: () {
                  setState(() {
                    _baseMapStyle = _baseMapStyle == BaseMapStyle.street
                        ? BaseMapStyle.topo
                        : BaseMapStyle.street;
                  });
                },
              ),
              const SizedBox(height: 8),
              ZoomButton(
                icon: Icons.add,
                onTap: () {
                  _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  );
                },
              ),
              const SizedBox(height: 6),
              ZoomButton(
                icon: Icons.remove,
                onTap: () {
                  _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Offline Banner ───────────────────────────────────────────────────────────

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

// ─── Error State Widget ───────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const _ErrorState({required this.errorMessage, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.severityRed),
            const SizedBox(height: 12),
            const Text(
              'Failed to load incidents',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

extension on IncidentProvider {
  void setCategoryChanged(IncidentCategory? c) {
    setCategoryFilter(c);
  }
}
