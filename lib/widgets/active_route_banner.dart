import 'package:flutter/material.dart';

import '../models/route_result.dart';
import '../providers/active_route_provider.dart';
import '../theme/app_colors.dart';
import 'severity_badge.dart';

/// Strip across the top of the home map while a safe route is active:
/// where it goes, how long it takes, and whether it crosses an alert zone.
/// Tap to frame the whole route; the directions icon reopens the full
/// directions screen; ✕ clears the route.
class ActiveRouteBanner extends StatelessWidget {
  final ActiveRoute route;
  final VoidCallback onTap;
  final VoidCallback? onOpenDirections;
  final VoidCallback onClear;

  const ActiveRouteBanner({
    super.key,
    required this.route,
    required this.onTap,
    required this.onClear,
    this.onOpenDirections,
  });

  @override
  Widget build(BuildContext context) {
    final result = route.result;
    final hazard = result.worstHazardSeverity;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Icon(
                route.mode == TravelMode.walking
                    ? Icons.directions_walk
                    : Icons.directions_car,
                color: AppColors.deepEstuary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Safe route to ${route.shelter?.name ?? 'dropped pin'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${result.distanceLabel} · ${result.durationLabel}',
                          style: textTheme.bodySmall,
                        ),
                        if (hazard != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: severityColor(hazard),
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              'crosses ${hazard.label.toLowerCase()} zone',
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: severityColor(hazard),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onOpenDirections != null)
                IconButton(
                  tooltip: 'Open directions',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.directions,
                    color: AppColors.riverTeal,
                  ),
                  onPressed: onOpenDirections,
                ),
              IconButton(
                tooltip: 'Clear route',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
