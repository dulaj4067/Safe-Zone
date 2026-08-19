import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../theme/app_colors.dart';

class SeverityBadge extends StatelessWidget {
  final AlertSeverity severity;

  const SeverityBadge({super.key, required this.severity});

  Color get _color {
    switch (severity) {
      case AlertSeverity.green:
        return AppColors.severityGreen;
      case AlertSeverity.yellow:
        return AppColors.severityYellow;
      case AlertSeverity.orange:
        return AppColors.severityOrange;
      case AlertSeverity.red:
        return AppColors.severityRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        severity.label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
