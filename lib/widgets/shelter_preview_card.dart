import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/shelter.dart';
import '../screens/shelter_detail_screen.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';

/// Compact shelter summary shown over the map when a shelter pin is
/// tapped. Tapping the card opens the full Shelter page; "Safe route"
/// opens hazard-aware directions to it.
class ShelterPreviewCard extends StatelessWidget {
  final Shelter shelter;
  final LatLng? userLocation;
  final VoidCallback onOpen;
  final VoidCallback onRoute;
  final VoidCallback onClose;

  const ShelterPreviewCard({
    super.key,
    required this.shelter,
    required this.onOpen,
    required this.onRoute,
    required this.onClose,
    this.userLocation,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = userLocation;
    final metres = user == null
        ? null
        : const Distance()(user, LatLng(shelter.latitude, shelter.longitude));
    final fraction = shelter.occupancyFraction;
    final cap = shelter.capacity, occ = shelter.occupancy;
    final free = (cap != null && occ != null) ? cap - occ : null;
    final barColor = (fraction ?? 0) >= 0.9
        ? AppColors.severityRed
        : (fraction ?? 0) >= 0.7
        ? AppColors.severityOrange
        : AppColors.severityGreen;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.night_shelter, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shelter.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          [
                            shelter.typeLabel,
                            if (metres != null) '${distanceLabel(metres)} away',
                          ].join(' · '),
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (shelter.status != null)
                    ShelterStatusPill(status: shelter.status!),
                  IconButton(
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClose,
                  ),
                ],
              ),
              if (fraction != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      color: barColor,
                      backgroundColor: barColor.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                free == null
                    ? 'Availability unknown'
                    : free > 0
                    ? '$free spaces free · $occ/$cap'
                    : 'At capacity · $occ/$cap',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.deepEstuary,
                        // The app theme makes filled buttons full-width,
                        // which is infinite inside this Row.
                        minimumSize: const Size(0, 40),
                      ),
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Safe route'),
                      onPressed: onRoute,
                    ),
                    const Spacer(),
                    Text(
                      'View shelter',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.riverTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.riverTeal,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
