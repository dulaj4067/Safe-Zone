import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../providers/alert_provider.dart';
import 'severity_badge.dart';

/// Global warning strip — matches the SafeZone mockup exactly: solid
/// severity-color background, a white pill with the severity label
/// ("WARNING", "ALERT", etc.), the alert title in bold white, and a
/// trailing chevron. Sits flush at the very top of the screen, no card,
/// margin, rounding, or shadow.
///
/// Tap opens the alert detail & resident acknowledgment sheet so citizens
/// can confirm receipt and safety.
class AlertBanner extends StatelessWidget {
  final DisasterAlert alert;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;
  final VoidCallback? onAcknowledge;

  const AlertBanner({
    super.key,
    required this.alert,
    required this.onDismiss,
    this.onTap,
    this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final bannerColor = severityColor(alert.severity);

    // Auto-record that the alert was seen by the resident on device
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertProvider>().markAlertSeen(alert.id);
    });

    final alertProvider = context.watch<AlertProvider>();
    final isFallback = alertProvider.lastDeliveryResult?.alertId == alert.id &&
        alertProvider.lastDeliveryResult?.fallbackTriggered == true;

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
            onTap: onTap ?? () => _showAlertDetailModal(context),
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
                  if (isFallback) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.alt_route, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'FALLBACK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  void _showAlertDetailModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SeverityBadge(severity: alert.severity),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alert.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alert.instructions ?? 'No specific safety instructions provided.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Type: ${alert.alertType.toUpperCase()} · Radius: ${alert.radiusMeters}m',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Builder(
              builder: (ctx) {
                final prov = ctx.read<AlertProvider>();
                final delivery = prov.deliveryHistory
                    .where((d) => d.alertId == alert.id)
                    .firstOrNull ?? prov.lastDeliveryResult;
                if (delivery == null || delivery.alertId != alert.id) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: delivery.fallbackTriggered
                          ? Colors.orange.withValues(alpha: 0.12)
                          : Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: delivery.fallbackTriggered
                            ? Colors.orange.withValues(alpha: 0.4)
                            : Colors.green.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          delivery.fallbackTriggered ? Icons.alt_route : Icons.check_circle,
                          size: 16,
                          color: delivery.fallbackTriggered ? Colors.orange.shade800 : Colors.green.shade800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            delivery.fallbackTriggered
                                ? 'Delivered via Backup Channels (SMS & In-App) after primary push failed.'
                                : 'Delivered via Primary Channel: ${delivery.channelsUsed.map((c) => c.name.toUpperCase()).join(", ")}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: delivery.fallbackTriggered ? Colors.orange.shade900 : Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: severityColor(alert.severity),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Acknowledge & Confirm Safe'),
              onPressed: () async {
                await context.read<AlertProvider>().acknowledgeAlert(alert.id);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alert acknowledged. Local authorities notified.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}