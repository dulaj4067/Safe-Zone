import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../theme/app_colors.dart';

/// Solid severity color — single source of truth. SeverityBadge uses this
/// internally, and anything else that needs a severity color (map
/// circles, AlertBanner's stripe) should call this too, so nothing drifts
/// out of sync with AppColors.severity*.
Color severityColor(AlertSeverity severity) {
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

/// Translucent fill version of [severityColor], for area overlays like
/// the map's alert-radius circles.
Color severityFillColor(AlertSeverity severity) =>
    severityColor(severity).withValues(alpha: 0.33);

class SeverityBadge extends StatelessWidget {
  final AlertSeverity severity;

  const SeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: severityColor(severity),
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