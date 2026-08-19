import 'package:flutter/material.dart';

import '../models/alert.dart';
import 'severity_badge.dart';

class AlertBanner extends StatelessWidget {
  final DisasterAlert alert;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const AlertBanner({
    super.key,
    required this.alert,
    required this.onDismiss,
    this.onTap,
  });

  /// Signature detail: urgency is legible even in peripheral vision, not
  /// just from reading the badge text. Higher severity = thicker stripe.
  double get _stripeWidth {
    switch (alert.severity) {
      case AlertSeverity.green:
        return 3;
      case AlertSeverity.yellow:
        return 5;
      case AlertSeverity.orange:
        return 7;
      case AlertSeverity.red:
        return 9;
    }
  }

  Color get _stripeColor {
    switch (alert.severity) {
      case AlertSeverity.green:
        return const Color(0xFF2E7D32);
      case AlertSeverity.yellow:
        return const Color(0xFFF9A825);
      case AlertSeverity.orange:
        return const Color(0xFFEF6C00);
      case AlertSeverity.red:
        return const Color(0xFFC62828);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: _stripeWidth, color: _stripeColor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: _BannerContent(alert: alert, onDismiss: onDismiss),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  final DisasterAlert alert;
  final VoidCallback onDismiss;

  const _BannerContent({required this.alert, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SeverityBadge(severity: alert.severity),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (alert.instructions != null) ...[
                const SizedBox(height: 6),
                Text(
                  alert.instructions!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: onDismiss,
          splashRadius: 18,
        ),
      ],
    );
  }
}
