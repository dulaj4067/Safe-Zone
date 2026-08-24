import 'package:flutter/material.dart';

import '../models/incident.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

/// Returns the Material icon for an incident category.
IconData categoryIcon(IncidentCategory category) {
  switch (category) {
    case IncidentCategory.waterlogging:
      return Icons.water_drop;
    case IncidentCategory.blockedRoad:
      return Icons.block;
    case IncidentCategory.powerOutage:
      return Icons.flash_off;
    case IncidentCategory.trappedPerson:
      return Icons.warning_rounded;
    case IncidentCategory.structuralDamage:
      return Icons.domain_disabled;
    case IncidentCategory.other:
      return Icons.place;
  }
}

/// Returns the color for an incident category marker/icon.
Color categoryColor(IncidentCategory category) {
  switch (category) {
    case IncidentCategory.waterlogging:
      return const Color(0xFF1E88E5);
    case IncidentCategory.blockedRoad:
      return const Color(0xFFF57C00);
    case IncidentCategory.powerOutage:
      return const Color(0xFFFBC02D);
    case IncidentCategory.trappedPerson:
      return const Color(0xFFD32F2F);
    case IncidentCategory.structuralDamage:
      return const Color(0xFF8E24AA);
    case IncidentCategory.other:
      return const Color(0xFF616161);
  }
}

/// Reusable incident card for the incidents list view. Shows category,
/// description, time, status, credibility, and SOS/photo indicators.
class IncidentCard extends StatelessWidget {
  final Incident incident;
  final VoidCallback? onTap;

  const IncidentCard({
    super.key,
    required this.incident,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = categoryColor(incident.category);

    return Card(
      color: incident.isSos
          ? (isDark
              ? AppColors.severityRed.withValues(alpha: 0.15)
              : AppColors.sosBackground)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Top row: category + status ─────────────────────────────
              Row(
                children: [
                  // Category icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      categoryIcon(incident.category),
                      size: 20,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Category label + time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incident.category.label,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _timeAgo(incident.createdAt),
                          style: AppTheme.dataText(context).copyWith(
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // SOS badge
                  if (incident.isSos) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.severityRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Status badge
                  StatusBadge(status: incident.status),
                ],
              ),

              // ─── Description preview ────────────────────────────────────
              if (incident.description != null &&
                  incident.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  incident.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],

              // ─── Bottom row: photo indicator + credibility ──────────────
              const SizedBox(height: 10),
              Row(
                children: [
                  // Photo thumbnail indicator
                  if (incident.photoUrl != null) ...[
                    Icon(
                      Icons.photo_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (incident.videoUrl != null) ...[
                    Icon(
                      Icons.videocam_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                  ],
                  const Spacer(),
                  // Credibility score
                  Icon(
                    Icons.thumb_up_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${incident.credibilityScore}',
                    style: AppTheme.dataText(context).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
