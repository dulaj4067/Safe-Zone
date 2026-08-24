import 'package:flutter/material.dart';

import '../models/incident.dart';
import '../theme/app_colors.dart';

/// Status badge for incident cards and detail views, modeled after
/// [SeverityBadge]. Uses distinct colors so status is readable at a
/// glance without conflicting with the alert severity palette.
class StatusBadge extends StatelessWidget {
  final IncidentStatus status;

  const StatusBadge({super.key, required this.status});

  static Color backgroundColor(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return const Color(0xFFF9A825); // amber
      case IncidentStatus.verified:
        return AppColors.severityGreen;
      case IncidentStatus.rejected:
        return AppColors.severityRed;
      case IncidentStatus.resolved:
        return const Color(0xFF546E7A); // blue-grey
    }
  }

  static Color foregroundColor(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return const Color(0xFF4E3600); // dark amber for contrast
      case IncidentStatus.verified:
        return Colors.white;
      case IncidentStatus.rejected:
        return Colors.white;
      case IncidentStatus.resolved:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: foregroundColor(status),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
