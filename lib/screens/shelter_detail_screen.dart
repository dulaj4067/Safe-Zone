import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/alert.dart';
import '../models/app_user.dart';
import '../models/incident.dart';
import '../models/shelter.dart';
import '../models/volunteer_task.dart';
import '../providers/alert_provider.dart';
import '../providers/incident_provider.dart';
import '../providers/map_focus_provider.dart';
import '../services/location_service.dart';
import '../services/shelter_service.dart';
import '../services/supabase_service.dart';
import '../services/volunteer_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import '../utils/map_tile_config.dart';
import '../utils/map_tile_sources.dart';
import '../utils/sri_lanka_bounds.dart';
import '../widgets/incident_card.dart';
import '../widgets/live_location_marker.dart';
import '../widgets/severity_badge.dart';
import '../widgets/shelter_resources_card.dart';
import 'incident_detail_screen.dart';
import 'message_thread_screen.dart';
import 'shelter_directions_screen.dart';
import 'volunteer_tasks_screen.dart';

/// Everything the database connects to one shelter, on one page:
/// the `shelters` row (status, capacity, desk phone, manager), its
/// `shelter_resources` supplies, its `volunteer_tasks`, plus the active
/// alerts covering it and incidents reported nearby — the two things a
/// person heading there most needs to know about its surroundings.
class ShelterDetailScreen extends StatefulWidget {
  final Shelter shelter;
  final AppUser? currentUser;

  const ShelterDetailScreen({
    super.key,
    required this.shelter,
    this.currentUser,
  });

  @override
  State<ShelterDetailScreen> createState() => _ShelterDetailScreenState();
}

class _ShelterDetailScreenState extends State<ShelterDetailScreen> {
  static const Distance _distance = Distance();

  /// How far around the shelter an incident still counts as "nearby" —
  /// roughly the last stretch of road someone would take to get there.
  static const double _nearbyIncidentMetres = 3000;

  final ShelterService _shelterService = ShelterService();
  final VolunteerService _volunteerService = VolunteerService();

  late Shelter _shelter = widget.shelter;
  LatLng? _userLocation;
  String? _managerName;
  List<VolunteerTask>? _tasks;
  bool _tasksFailed = false;

  /// Bumped on refresh so ShelterResourcesCard re-fetches its supplies.
  int _refreshKey = 0;

  LatLng get _point => LatLng(_shelter.latitude, _shelter.longitude);

  /// The name lives in the big header; the app bar only picks it up once
  /// that header has scrolled away, so it's never shown twice at once.
  final ScrollController _scroll = ScrollController();
  bool _headerScrolledAway = false;

  void _onScroll() {
    final away = _scroll.offset > 64;
    if (away != _headerScrolledAway) {
      setState(() => _headerScrolledAway = away);
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadRelated();
    _locate();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final service = LocationService();
    if (!await service.ensurePermission()) return;
    final here = await service.getCurrentLocation();
    if (mounted && here != null) setState(() => _userLocation = here);
  }

  Future<void> _loadRelated() async {
    final manager = _shelterService.fetchManagerName(_shelter.managedBy);
    try {
      final tasks = await _volunteerService.fetchTasks(shelterId: _shelter.id);
      if (mounted) setState(() => _tasks = tasks);
    } catch (_) {
      if (mounted) setState(() => _tasksFailed = true);
    }
    final name = await manager;
    if (mounted) setState(() => _managerName = name);
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _shelterService.fetchShelter(_shelter.id);
      if (fresh != null && mounted) setState(() => _shelter = fresh);
    } catch (_) {
      // Keep showing what we have rather than blanking the page offline.
    }
    if (mounted) {
      setState(() {
        _tasksFailed = false;
        _refreshKey++;
      });
    }
    await _loadRelated();
  }

  /// Back to the root screen, onto the Home tab, with the map centred on
  /// this shelter and its preview card open.
  void _showOnHomeMap() {
    context.read<MapFocusProvider>().focusShelter(_shelter);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _callDesk() async {
    final phone = _shelter.contactPhone;
    if (phone == null) return;
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open the dialer. Please call $phone.'),
        ),
      );
    }
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final coveringAlerts =
        context
            .watch<AlertProvider>()
            .activeAlerts
            .where(
              (a) =>
                  _distance(_point, LatLng(a.centerLat, a.centerLng)) <=
                  a.radiusMeters,
            )
            .toList()
          ..sort((a, b) => b.severity.index.compareTo(a.severity.index));

    final nearbyIncidents =
        [
            for (final i in context.watch<IncidentProvider>().incidents)
              if (i.status == IncidentStatus.pending ||
                  i.status == IncidentStatus.verified)
                (
                  incident: i,
                  metres: _distance(_point, LatLng(i.latitude, i.longitude)),
                ),
          ].where((e) => e.metres <= _nearbyIncidentMetres).toList()
          ..sort((a, b) {
            // SOS first, then closest.
            if (a.incident.isSos != b.incident.isSos) {
              return a.incident.isSos ? -1 : 1;
            }
            return a.metres.compareTo(b.metres);
          });

    final isMine = _shelter.managedBy == SupabaseService.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _headerScrolledAway ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Text(_shelter.name, overflow: TextOverflow.ellipsis),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _Header(shelter: _shelter, userLocation: _userLocation),
            for (final alert in coveringAlerts) ...[
              const SizedBox(height: 12),
              _AlertWarning(alert: alert),
            ],
            const SizedBox(height: 16),
            _ShelterMiniMap(
              shelter: _shelter,
              alerts: coveringAlerts,
              incidents: [for (final e in nearbyIncidents) e.incident],
              userLocation: _userLocation,
              onTap: _showOnHomeMap,
            ),
            const SizedBox(height: 16),
            _AvailabilityCard(shelter: _shelter),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.directions),
                    label: const Text('Safe route here'),
                    onPressed: () =>
                        _push(ShelterDirectionsScreen(destination: _shelter)),
                  ),
                ),
                if (_shelter.contactPhone != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.call),
                      label: const Text('Call desk'),
                      onPressed: _callDesk,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Contact & management'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Emergency desk'),
                    subtitle: Text(_shelter.contactPhone ?? 'No phone listed'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Managed by'),
                    subtitle: Text(
                      _shelter.managedBy == null
                          ? 'No manager assigned'
                          : _managerName ?? 'Loading…',
                    ),
                    trailing: _shelter.managedBy != null && !isMine
                        ? TextButton.icon(
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                            ),
                            label: const Text('Message'),
                            onPressed: () => _push(
                              MessageThreadScreen(
                                shelterId: _shelter.id,
                                shelterName: _shelter.name,
                                otherUserId: _shelter.managedBy!,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Supplies'),
            ShelterResourcesCard(key: ValueKey(_refreshKey), shelter: _shelter),
            const SizedBox(height: 20),
            _SectionTitle(
              'Volunteer needs',
              action: TextButton(
                onPressed: () => _push(
                  VolunteerTasksScreen(
                    shelterId: _shelter.id,
                    shelterName: _shelter.name,
                  ),
                ),
                child: const Text('See all & sign up'),
              ),
            ),
            _VolunteerNeeds(tasks: _tasks, failed: _tasksFailed),
            const SizedBox(height: 20),
            const _SectionTitle('Reported nearby (within 3 km)'),
            if (nearbyIncidents.isEmpty)
              const _EmptyNote(
                icon: Icons.check_circle_outline,
                text: 'No active incidents reported around this shelter.',
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final e in nearbyIncidents.take(5))
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: e.incident.isSos
                              ? AppColors.severityRed
                              : categoryColor(e.incident.category),
                          foregroundColor: Colors.white,
                          child: Icon(
                            e.incident.isSos
                                ? Icons.warning_amber_rounded
                                : categoryIcon(e.incident.category),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          e.incident.isSos
                              ? 'SOS · ${e.incident.category.label}'
                              : e.incident.category.label,
                        ),
                        subtitle: Text(
                          [
                            distanceLabel(e.metres),
                            e.incident.status.label,
                            timeAgo(e.incident.createdAt),
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _push(
                          IncidentDetailScreen(
                            incident: e.incident,
                            currentUser: widget.currentUser,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (_shelter.updatedAt != null) ...[
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Shelter info last updated ${timeAgo(_shelter.updatedAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Shelter shelter;
  final LatLng? userLocation;

  const _Header({required this.shelter, this.userLocation});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = userLocation;
    final away = user == null
        ? null
        : '${distanceLabel(const Distance()(user, LatLng(shelter.latitude, shelter.longitude)))} away';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shelter.name,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [shelter.typeLabel, ?away].join(' · '),
                style: textTheme.bodyMedium?.copyWith(
                  color: textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        if (shelter.status != null) ...[
          const SizedBox(width: 12),
          ShelterStatusPill(status: shelter.status!),
        ],
      ],
    );
  }
}

/// OPEN / FULL / CLOSED chip, shared by the shelter list and this page.
class ShelterStatusPill extends StatelessWidget {
  final String status;

  const ShelterStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'open' => ('OPEN', AppColors.severityGreen),
      'full' => ('FULL', AppColors.severityOrange),
      'closed' => ('CLOSED', AppColors.severityRed),
      _ => (status.toUpperCase(), AppColors.slateMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Small fixed map of the shelter's surroundings: its pin, any alert zone
/// covering it, active incidents nearby, and the person's own position
/// when it falls in view. It doesn't pan or zoom (so it never steals the
/// page's scroll gesture); tapping it opens the full home map instead.
class _ShelterMiniMap extends StatelessWidget {
  final Shelter shelter;
  final List<DisasterAlert> alerts;
  final List<Incident> incidents;
  final LatLng? userLocation;
  final VoidCallback onTap;

  const _ShelterMiniMap({
    required this.shelter,
    required this.alerts,
    required this.incidents,
    required this.onTap,
    this.userLocation,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(shelter.latitude, shelter.longitude);
    final border = Theme.of(context).dividerTheme.color ?? AppColors.hairline;

    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 14,
                minZoom: kSriLankaMinZoom,
                cameraConstraint: kSriLankaCameraConstraint,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                buildBaseTileLayer(BaseMapStyle.street),
                CircleLayer(
                  circles: [
                    for (final a in alerts)
                      CircleMarker(
                        point: LatLng(a.centerLat, a.centerLng),
                        radius: a.radiusMeters.toDouble(),
                        useRadiusInMeter: true,
                        color: severityFillColor(a.severity),
                        borderColor: severityColor(a.severity),
                        borderStrokeWidth: 1.5,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final i in incidents)
                      Marker(
                        point: LatLng(i.latitude, i.longitude),
                        width: 26,
                        height: 26,
                        child: Container(
                          decoration: BoxDecoration(
                            color: i.isSos
                                ? AppColors.severityRed
                                : categoryColor(i.category),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Icon(
                            i.isSos
                                ? Icons.warning_amber_rounded
                                : categoryIcon(i.category),
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    if (userLocation != null)
                      Marker(
                        point: userLocation!,
                        width: 24,
                        height: 24,
                        child: const LiveLocationMarker(),
                      ),
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 3),
                          ],
                        ),
                        child: const Icon(
                          Icons.night_shelter,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution(attributionFor(BaseMapStyle.street)),
                  ],
                ),
              ],
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 3),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 16,
                        color: AppColors.riverTeal,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'View on map',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.riverTeal,
                        ),
                      ),
                    ],
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

class _AlertWarning extends StatelessWidget {
  final DisasterAlert alert;

  const _AlertWarning({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = severityColor(alert.severity);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inside an active ${alert.severity.label.toLowerCase()} alert: ${alert.title}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                if (alert.instructions != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    alert.instructions!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final Shelter shelter;

  const _AvailabilityCard({required this.shelter});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final capacity = shelter.capacity;
    final occupancy = shelter.occupancy;
    final fraction = shelter.occupancyFraction;
    final free = (capacity != null && occupancy != null)
        ? capacity - occupancy
        : null;
    final barColor = (fraction ?? 0) >= 0.9
        ? AppColors.severityRed
        : (fraction ?? 0) >= 0.7
        ? AppColors.severityOrange
        : AppColors.severityGreen;

    final headline = switch (shelter.status) {
      'closed' => 'Closed — not accepting people',
      'full' => 'Full — try another shelter',
      _ when free != null && free <= 0 => 'At capacity',
      _ when free != null => '$free spaces available',
      _ => 'Availability unknown',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headline,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (capacity != null) ...[
              const SizedBox(height: 4),
              Text(
                occupancy == null
                    ? 'Capacity $capacity people'
                    : '$occupancy of $capacity people sheltered'
                          '${fraction == null ? '' : ' (${(fraction * 100).round()}%)'}',
                style: textTheme.bodySmall,
              ),
            ],
            if (fraction != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  color: barColor,
                  backgroundColor: barColor.withValues(alpha: 0.15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VolunteerNeeds extends StatelessWidget {
  final List<VolunteerTask>? tasks;
  final bool failed;

  const _VolunteerNeeds({required this.tasks, required this.failed});

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return const _EmptyNote(
        icon: Icons.cloud_off,
        text: "Couldn't load volunteer tasks.",
      );
    }
    final all = tasks;
    if (all == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final active = all
        .where(
          (t) =>
              t.status == VolunteerTaskStatus.open ||
              t.status == VolunteerTaskStatus.inProgress,
        )
        .toList();
    if (active.isEmpty) {
      return const _EmptyNote(
        icon: Icons.volunteer_activism_outlined,
        text: 'No open volunteer tasks at this shelter right now.',
      );
    }
    return Card(
      child: Column(
        children: [
          for (final t in active.take(4))
            ListTile(
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: Text(t.title),
              subtitle: Text(
                '${t.status.label} · ${t.signedUpCount}/${t.volunteersNeeded} volunteers'
                '${t.isFull ? ' · filled' : ''}',
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Widget? action;

  const _SectionTitle(this.text, {this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.slateMuted),
        title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
