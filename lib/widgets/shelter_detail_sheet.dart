import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shelter.dart';
import '../screens/message_thread_screen.dart';
import '../screens/volunteer_tasks_screen.dart';
import '../services/shelter_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import '../utils/map_tile_config.dart';
import '../utils/map_tile_sources.dart';
import 'shelter_resources_card.dart';

/// Opens the shelter detail sheet.
///
/// [userLocation] (if known) adds a "0.8 km away" distance. [onGetDirections]
/// is what the "Get Live Directions" button does — the sheet closes first.
/// When it is null the button opens the phone's maps app instead.
Future<void> showShelterDetail(
  BuildContext context,
  Shelter shelter, {
  LatLng? userLocation,
  VoidCallback? onGetDirections,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (sheetContext) => ShelterDetailSheet(
      shelter: shelter,
      userLocation: userLocation,
      onGetDirections: onGetDirections == null
          ? null
          : () {
              Navigator.pop(sheetContext);
              onGetDirections();
            },
    ),
  );
}

/// Everything the `shelters` table knows about one shelter: name, type,
/// open/full/closed status, capacity and current occupancy, desk phone,
/// who manages it, and when it was last updated.
class ShelterDetailSheet extends StatelessWidget {
  final Shelter shelter;
  final LatLng? userLocation;
  final VoidCallback? onGetDirections;

  const ShelterDetailSheet({
    super.key,
    required this.shelter,
    this.userLocation,
    this.onGetDirections,
  });

  static const Distance _distance = Distance();

  String? get _distanceLabel {
    final user = userLocation;
    if (user == null) return null;
    final metres = _distance(user, LatLng(shelter.latitude, shelter.longitude));
    return '${distanceLabel(metres)} away';
  }

  Future<void> _openMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${shelter.latitude},${shelter.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callDesk(BuildContext context) async {
    final phone = shelter.contactPhone;
    if (phone == null) return;
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open the dialer. Please call $phone.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = [shelter.address ?? shelter.typeLabel, _distanceLabel]
        .whereType<String>()
        .join(' · ');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: textTheme.bodySmall?.color?.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shelter.name,
                      style: textTheme.headlineMedium?.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: textTheme.bodySmall?.copyWith(fontSize: 14)),
                  ],
                ),
              ),
              if (shelter.status != null) ...[
                const SizedBox(width: 12),
                _StatusPill(status: shelter.status!),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _MiniMap(shelter: shelter),
          const SizedBox(height: 16),
          _InfoCard(shelter: shelter),
          const SizedBox(height: 12),
          ShelterResourcesCard(shelter: shelter),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onGetDirections ?? _openMaps,
            child: const Text('Get Live Directions'),
          ),
          if (shelter.contactPhone != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => _callDesk(context),
              child: const Text('Call Shelter Desk'),
            ),
          ],
          if (shelter.managedBy != null &&
              shelter.managedBy != SupabaseService.currentUserId) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Message Shelter Manager'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MessageThreadScreen(
                    shelterId: shelter.id,
                    shelterName: shelter.name,
                    otherUserId: shelter.managedBy!,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
            label: const Text('Volunteer at this shelter'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VolunteerTasksScreen(
                  shelterId: shelter.id,
                  shelterName: shelter.name,
                ),
              ),
            ),
          ),
          if (shelter.updatedAt != null) ...[
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Last updated ${timeAgo(shelter.updatedAt!)}',
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'open' => ('OPEN', AppColors.severityGreen),
      'full' => ('FULL', AppColors.severityOrange),
      'closed' => ('CLOSED', AppColors.severityRed),
      _ => (status.toUpperCase(), AppColors.slateMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Non-interactive map centred on the shelter's pin.
class _MiniMap extends StatelessWidget {
  final Shelter shelter;

  const _MiniMap({required this.shelter});

  @override
  Widget build(BuildContext context) {
    final point = LatLng(shelter.latitude, shelter.longitude);
    final border = Theme.of(context).dividerTheme.color ?? AppColors.hairline;

    return Container(
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            buildBaseTileLayer(BaseMapStyle.street),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: const Icon(
                    Icons.location_on,
                    size: 44,
                    color: AppColors.severityRed,
                  ),
                ),
              ],
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution(attributionFor(BaseMapStyle.street))],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Shelter shelter;

  const _InfoCard({required this.shelter});

  @override
  Widget build(BuildContext context) {
    final capacity = shelter.capacity;
    final occupancy = shelter.occupancy;
    final fraction = shelter.occupancyFraction;

    final rows = <Widget>[
      if (capacity != null)
        _InfoRow(
          label: 'Current Capacity',
          value: occupancy == null
              ? 'Capacity $capacity'
              : '$occupancy / $capacity occupied'
                  '${fraction == null ? '' : ' (${(fraction * 100).round()}%)'}',
          bar: fraction,
        ),
      if (shelter.contactPhone != null)
        _InfoRow(label: 'Emergency Desk Phone', value: shelter.contactPhone!),
      if (shelter.managedBy != null)
        FutureBuilder<String?>(
          future: ShelterService().fetchManagerName(shelter.managedBy),
          builder: (context, snapshot) {
            final name = snapshot.data;
            if (name == null) return const SizedBox.shrink();
            return _InfoRow(label: 'Managed by:', value: name);
          },
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    final divider = Divider(
      height: 1,
      color: Theme.of(context).dividerTheme.color,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) divider,
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  /// Optional 0–1 fill for a slim progress bar under the row.
  final double? bar;

  const _InfoRow({required this.label, required this.value, this.bar});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final barColor = (bar ?? 0) >= 0.9
        ? AppColors.severityRed
        : (bar ?? 0) >= 0.7
            ? AppColors.severityOrange
            : AppColors.severityGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (bar != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: bar,
                minHeight: 6,
                color: barColor,
                backgroundColor: barColor.withValues(alpha: 0.15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
