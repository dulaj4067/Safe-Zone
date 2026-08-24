import 'package:flutter/material.dart';

import '../models/alert.dart';
import 'severity_badge.dart';

/// Global warning strip — matches the SafeZone mockup exactly: solid
/// severity-color background, a white pill with the severity label
/// ("WARNING", "ALERT", etc.), the alert title in bold white, and a
/// trailing chevron. Sits flush at the very top of the screen, no card,
/// margin, rounding, or shadow.
///
/// There's no visible close icon (the mockup doesn't have one) — swipe
/// up to dismiss instead, which still calls [onDismiss] so callers
/// (AppShell's global banner, LocationAlertBanner) don't need to change.
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

  @override
  Widget build(BuildContext context) {
    final bannerColor = severityColor(alert.severity);

    return SafeArea(
      bottom: false,
      left: false,
      right: false,
      child: Dismissible(
        key: ValueKey(alert.id),
        direction: DismissDirection.up,
        onDismissed: (_) => onDismiss(),
        child: Material(
          color: bannerColor,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      alert.severity.label.toUpperCase(),
                      style: TextStyle(
                        color: bannerColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      alert.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}