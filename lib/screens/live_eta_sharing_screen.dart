import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../providers/safety_provider.dart';
import '../models/circle_member_location.dart';
import '../models/risk_zone.dart';
import '../theme/app_colors.dart';
import '../utils/map_tile_config.dart';
import '../utils/map_tile_sources.dart';
import '../utils/sri_lanka_bounds.dart';
import '../utils/format_utils.dart';
import '../widgets/live_location_marker.dart';
import '../widgets/loved_one_marker.dart';
import '../widgets/session_history_list.dart';

class LiveEtaSharingScreen extends StatefulWidget {
  final RiskZone? currentRiskZone;
  /// Optional destination to compute ETA/distance against — e.g. a
  /// selected shelter. If null, live position still shares, just without
  /// a meaningful ETA countdown.
  final LatLng? destination;

  const LiveEtaSharingScreen({super.key, this.currentRiskZone, this.destination});

  @override
  State<LiveEtaSharingScreen> createState() => _LiveEtaSharingScreenState();
}

class _LiveEtaSharingScreenState extends State<LiveEtaSharingScreen> {
  bool _safeBroadcastSent = false;

  final List<SessionHistoryEntry> _sessionHistory = [
    SessionHistoryEntry(
      id: 's1',
      title: 'Risk-zone route check-in',
      occurredAt: DateTime(2024, 1, 10, 8, 40),
      subtitle: 'Shared safe route update',
    ),
    SessionHistoryEntry(
      id: 's2',
      title: 'Shelter arrival confirmation',
      occurredAt: DateTime(2024, 1, 11, 7, 5),
      subtitle: 'Reached safer ground',
    ),
    SessionHistoryEntry(
      id: 's3',
      title: 'Flood map refresh',
      occurredAt: DateTime(2024, 1, 12, 9, 15),
      subtitle: 'Updated nearest safe route',
    ),
    SessionHistoryEntry(
      id: 's4',
      title: 'Family ETA sync',
      occurredAt: DateTime(2024, 1, 13, 18, 30),
      subtitle: 'Live share to selected contacts',
    ),
    SessionHistoryEntry(
      id: 's5',
      title: 'Evening safety ping',
      occurredAt: DateTime(2024, 1, 14, 21, 0),
      subtitle: 'Checked in after commute',
    ),
    SessionHistoryEntry(
      id: 's6',
      title: 'Night watch update',
      occurredAt: DateTime(2024, 1, 15, 22, 10),
      subtitle: 'Location beacon remained active',
    ),
  ];

  @override
  void initState() {
    super.initState();
    context.read<SafetyProvider>().startSharingEta(
          currentRiskZone: widget.currentRiskZone,
          destination: widget.destination,
        );
  }

  String _formatEta(Duration d) =>
      '${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s';

  /// A contact you're sharing with only ever appears here if they've ALSO
  /// added you to their own circle and confirmed it — the server-side
  /// privacy model is "I added them, so they can see me," so seeing *their*
  /// location back requires the reverse link too. That mutual-consent
  /// requirement is exactly right for "this is probably a family member
  /// pinging back" rather than a one-way watch list.
  CircleMemberLocation? _locationFor(String contactId, List<CircleMemberLocation> locations) {
    for (final loc in locations) {
      if (loc.contactId == contactId && loc.hasLocation) return loc;
    }
    return null;
  }

  void _showContactLocationSheet(BuildContext context, CircleMemberLocation member) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LovedOneMarker(initials: member.initials, isActive: member.isActive),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text(member.relationship,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
                  color: member.isActive ? AppColors.severityGreen : Colors.grey.shade600,
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

  @override
  Widget build(BuildContext context) {
    final safety = context.watch<SafetyProvider>();
    final update = safety.latestUpdate;
    final eta = update?.etaRemaining ?? Duration.zero;
    final km = update?.distanceRemainingKm ?? 0.0;
    final zone = widget.currentRiskZone;
    final mapCenter = update == null
      ? _zoneCenter(zone) ?? const LatLng(6.9615, 79.9010)
      : LatLng(update.latitude, update.longitude);
    // Only contacts you're actively sharing *with* on this screen, and only
    // where the location is actually visible to you (see _locationFor).
    final sharedContactLocations = [
      for (final c in safety.selectedContacts) ?_locationFor(c.id, safety.circleLocations),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Live Location - Sharing')),
      body: Column(
        children: [
          if (safety.errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Text(safety.errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 14,
                    minZoom: kSriLankaMinZoom,
                    cameraConstraint: kSriLankaCameraConstraint,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    buildBaseTileLayer(
                      isCartoApiKeyConfigured ? BaseMapStyle.street : BaseMapStyle.topo,
                    ),
                    if (zone != null && zone.boundary.isNotEmpty)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: zone.boundary,
                            color: zone.fillColor,
                            borderColor: zone.borderColor,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Family/circle contacts you're sharing with, where
                        // they've also shared back with you (see
                        // _locationFor) — pinged live alongside your own
                        // position so you can see each other on this screen,
                        // not just on the Home map.
                        for (final member in sharedContactLocations)
                          Marker(
                            point: LatLng(member.lat!, member.lng!),
                            width: 32,
                            height: 32,
                            child: GestureDetector(
                              onTap: () => _showContactLocationSheet(context, member),
                              child: LovedOneMarker(
                                initials: member.initials,
                                isActive: member.isActive,
                              ),
                            ),
                          ),
                        Marker(
                          point: mapCenter,
                          width: 40,
                          height: 40,
                          child: const LiveLocationMarker(),
                        ),
                      ],
                    ),
                  ],
                ),
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: zone?.borderColor ?? Colors.red.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, color: Colors.white, size: 10),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              zone != null
                                  ? 'LIVE - in ${zone.name} (${zone.label})'
                                  : 'LIVE - sharing your location',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _StatTile(label: 'ETA', value: _formatEta(eta), icon: Icons.schedule)),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Distance left',
                    value: '${km.toStringAsFixed(1)} km',
                    icon: Icons.route,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sharing with', style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
          SizedBox(
            // A touch taller than the avatar+label actually need, so a
            // larger system text-scale setting can't push this into
            // overflow the way the old fixed 72px did.
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: safety.selectedContacts.length,
              itemBuilder: (context, i) {
                final c = safety.selectedContacts[i];
                final loc = _locationFor(c.id, safety.circleLocations);
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: loc == null ? null : () => _showContactLocationSheet(context, loc),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(radius: 18, child: Text(c.initials)),
                            // A small status dot: green while they're
                            // actively sharing back, grey if we only have an
                            // older last-known fix, nothing if they haven't
                            // shared with you at all (see _locationFor).
                            if (loc != null)
                              Positioned(
                                right: -1,
                                bottom: -1,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: loc.isActive
                                        ? AppColors.severityGreen
                                        : Colors.grey.shade500,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 48,
                          child: Text(
                            c.name.split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (sheetContext) {
                      return SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Session history',
                                    style: Theme.of(sheetContext).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SessionHistoryList(
                                sessions: _sessionHistory,
                                pageSize: 3,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Session history'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _safeBroadcastSent ? Colors.green.shade600 : Colors.green.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _safeBroadcastSent
                  ? null
                  : () async {
                      setState(() => _safeBroadcastSent = true);
                      await context.read<SafetyProvider>().sendImSafeBroadcast(
                        currentRiskZone: widget.currentRiskZone,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Your safety circle has been notified that you are safe.'),
                          ),
                        );
                      }
                    },
              icon: Icon(
                _safeBroadcastSent ? Icons.check_circle : Icons.check_circle_outline,
              ),
              label: Text(_safeBroadcastSent ? 'Broadcast sent' : "I'm Safe"),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Stop sharing'),
                  onPressed: () async {
                    await context.read<SafetyProvider>().stopSharing();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LatLng? _zoneCenter(RiskZone? zone) {
    if (zone == null || zone.boundary.isEmpty) return null;

    final latitude = zone.boundary.fold<double>(0, (sum, point) => sum + point.latitude);
    final longitude = zone.boundary.fold<double>(0, (sum, point) => sum + point.longitude);
    return LatLng(latitude / zone.boundary.length, longitude / zone.boundary.length);
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFFF5F6F8), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}