import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/incident.dart';
import '../providers/alert_provider.dart';
import '../providers/incident_provider.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../widgets/incident_card.dart';
import '../widgets/location_alert_banner.dart';
import '../widgets/context_recall_card.dart';
import 'incident_detail_screen.dart';
import 'report_incident_screen.dart';

class IncidentsScreen extends StatefulWidget {
  final AppUser? currentUser;

  const IncidentsScreen({super.key, this.currentUser});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  static const LatLng _initialCenter = LatLng(6.9615, 79.9010);

  final LocationService _locationService = LocationService();
  StreamSubscription<LatLng>? _positionSub;

  LatLng? _liveLocation;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().load();
    });
    _startWatchingLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
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

  void _openReportScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportIncidentScreen()),
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
    final alertProvider = context.watch<AlertProvider>();
    final isOffline = provider.isOffline || alertProvider.isOffline;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveCenter = _liveLocation ?? _initialCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh incidents',
            onPressed: () => context.read<IncidentProvider>().refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openReportScreen,
        icon: const Icon(Icons.add),
        label: const Text('Report Incident'),
        backgroundColor: AppColors.deepEstuary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocationAlertBanner(
            userLocation: effectiveCenter,
            onTap: () {
              // TODO: navigate to a full alert-detail screen.
            },
          ),
          if (_locationDenied) const _LocationDeniedBanner(),
          if (provider.isOffline)
            _OfflineBanner(lastUpdated: provider.lastUpdated),
          if (alertProvider.isOffline)
            Builder(
              builder: (context) {
                final criticalAlerts = alertProvider.activeAlerts
                    .where((a) => a.severity.isCritical)
                    .take(ContextRecallCard.maxOfflineItems)
                    .toList();
                if (criticalAlerts.isEmpty) return const SizedBox.shrink();
                return ContextRecallCard(
                  key: const ValueKey('offline_last_known_alerts_card'),
                  alerts: criticalAlerts,
                  maxItems: ContextRecallCard.maxOfflineItems,
                  title: 'Last-Known Alerts',
                  subtitle: 'Offline critical alert recall',
                  isOffline: true,
                  onAcknowledge: (alert) =>
                      context.read<AlertProvider>().acknowledgeAlert(alert.id),
                );
              },
            ),

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
                  myReportsOnly: provider.myReportsFilter,
                  onStatusChanged: (s) => provider.setStatusFilter(s),
                  onCategoryChanged: (c) => provider.setCategoryChanged(c),
                  onSosChanged: (sos) => provider.setSosFilter(sos),
                  onMyReportsChanged: (my) => provider.setMyReportsFilter(my),
                  onClearAll: () => provider.clearFilters(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: provider.isLoading && provider.incidents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.errorMessage != null && provider.incidents.isEmpty
                ? _ErrorState(
                    errorMessage: provider.errorMessage!,
                    onRetry: () => provider.refresh(),
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

// ─── Location Denied Banner ───────────────────────────────────────────────────

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

// ─── Filter Bar Widget ────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final IncidentStatus? selectedStatus;
  final IncidentCategory? selectedCategory;
  final bool sosOnly;
  final bool myReportsOnly;
  final ValueChanged<IncidentStatus?> onStatusChanged;
  final ValueChanged<IncidentCategory?> onCategoryChanged;
  final ValueChanged<bool> onSosChanged;
  final ValueChanged<bool> onMyReportsChanged;
  final VoidCallback onClearAll;

  const _FilterBar({
    required this.selectedStatus,
    required this.selectedCategory,
    required this.sosOnly,
    required this.myReportsOnly,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onSosChanged,
    required this.onMyReportsChanged,
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
            selected:
                selectedStatus == null &&
                selectedCategory == null &&
                !sosOnly &&
                !myReportsOnly,
            onSelected: (_) => onClearAll(),
          ),
          const SizedBox(width: 6),

          // My Reports Filter
          FilterChip(
            avatar: const Icon(
              Icons.person_pin_circle_outlined,
              size: 16,
              color: AppColors.deepEstuary,
            ),
            label: const Text('My Reports'),
            selected: myReportsOnly,
            selectedColor: AppColors.deepEstuary.withValues(alpha: 0.15),
            onSelected: (val) => onMyReportsChanged(val),
          ),
          const SizedBox(width: 6),

          // SOS Emergency Filter
          FilterChip(
            avatar: const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Colors.red,
            ),
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
            onSelected: (val) =>
                onStatusChanged(val ? IncidentStatus.pending : null),
          ),
          const SizedBox(width: 6),

          // Verified Filter
          FilterChip(
            label: const Text('Verified'),
            selected: selectedStatus == IncidentStatus.verified,
            onSelected: (val) =>
                onStatusChanged(val ? IncidentStatus.verified : null),
          ),
          const SizedBox(width: 6),

          // Resolved Filter
          FilterChip(
            label: const Text('Resolved'),
            selected: selectedStatus == IncidentStatus.resolved,
            onSelected: (val) =>
                onStatusChanged(val ? IncidentStatus.resolved : null),
          ),
          const SizedBox(width: 6),

          // Rejected Filter
          FilterChip(
            label: const Text('Rejected'),
            selected: selectedStatus == IncidentStatus.rejected,
            onSelected: (val) =>
                onStatusChanged(val ? IncidentStatus.rejected : null),
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
      // Scrollable so it never overflows when banners above take space,
      // and so pull-to-refresh still works with nothing listed.
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.seafoam.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.report_outlined,
                    size: 48,
                    color: AppColors.deepEstuary,
                  ),
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
          ],
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.severityRed,
              ),
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
      ),
    );
  }
}

extension on IncidentProvider {
  void setCategoryChanged(IncidentCategory? c) {
    setCategoryFilter(c);
  }
}
