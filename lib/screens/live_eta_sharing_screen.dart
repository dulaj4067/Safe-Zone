import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../providers/safety_provider.dart';
import '../models/risk_zone.dart';
import '../widgets/live_location_marker.dart';

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

  @override
  Widget build(BuildContext context) {
    final safety = context.watch<SafetyProvider>();
    final update = safety.latestUpdate;
    final eta = update?.etaRemaining ?? Duration.zero;
    final km = update?.distanceRemainingKm ?? 0.0;
    final zone = widget.currentRiskZone;

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
            child: Container(
              width: double.infinity,
              color: const Color(0xFFE3EAF2),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Real "you are here" marker, matching the rest of the app's map style.
                  const LiveLocationMarker(),
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
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: safety.selectedContacts.length,
              itemBuilder: (context, i) {
                final c = safety.selectedContacts[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      CircleAvatar(child: Text(c.initials)),
                      const SizedBox(height: 4),
                      Text(c.name.split(' ').first, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              },
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