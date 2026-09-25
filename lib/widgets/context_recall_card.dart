import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../providers/alert_provider.dart';
import 'severity_badge.dart';

/// Context Recall Card
///
/// Gives citizens an immediate, high-priority overview of active emergency alerts
/// and warnings with a one-tap acknowledgment action so they can confirm
/// they have seen and understood the warning.
///
/// Requirements:
/// - Citizen can acknowledge an alert with one tap.
/// - Context Recall card has a hard maximum of 4 items.
/// - No scrolling inside the recall card.
/// - Recall card is visually distinct from the session history list.
class ContextRecallCard extends StatefulWidget {
  static const int maxItems = 4;

  final List<DisasterAlert>? alerts;
  final ValueChanged<DisasterAlert>? onAcknowledge;
  final ValueChanged<DisasterAlert>? onTapAlert;
  final String? currentUserId;

  const ContextRecallCard({
    super.key,
    this.alerts,
    this.onAcknowledge,
    this.onTapAlert,
    this.currentUserId,
  });

  @override
  State<ContextRecallCard> createState() => _ContextRecallCardState();
}

class _ContextRecallCardState extends State<ContextRecallCard> {
  final Set<String> _acknowledgedIds = {};

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  @override
  void didUpdateWidget(covariant ContextRecallCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkInitialStatus();
  }

  void _checkInitialStatus() {
    final alertProvider = Provider.of<AlertProvider?>(context, listen: false);
    final list = widget.alerts ?? alertProvider?.activeAlerts ?? [];
    for (final alert in list.take(ContextRecallCard.maxItems)) {
      if (alertProvider != null && alertProvider.isAlertAcknowledged(alert.id)) {
        _acknowledgedIds.add(alert.id);
      } else if (alertProvider != null) {
        alertProvider.hasAcknowledged(alert.id, userId: widget.currentUserId).then((ack) {
          if (ack && mounted) {
            setState(() => _acknowledgedIds.add(alert.id));
          }
        });
      }
    }
  }

  Future<void> _handleAcknowledge(DisasterAlert alert) async {
    setState(() => _acknowledgedIds.add(alert.id));

    if (widget.onAcknowledge != null) {
      widget.onAcknowledge!(alert);
    } else {
      final alertProvider = Provider.of<AlertProvider?>(context, listen: false);
      if (alertProvider != null) {
        await alertProvider.acknowledgeAlert(alert.id, userId: widget.currentUserId);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Warning "${alert.title}" acknowledged. Confirmation recorded.'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertProvider = Provider.of<AlertProvider?>(context);
    final rawAlerts = widget.alerts ?? alertProvider?.activeAlerts ?? [];
    if (rawAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Hard maximum of 4 items
    final items = rawAlerts.take(ContextRecallCard.maxItems).toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: const ValueKey('context_recall_card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.amber.shade700.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      color: colorScheme.brightness == Brightness.dark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
          : const Color(0xFFFFFBEB), // Distinct warm emergency context styling
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          // No scrolling inside the recall card: strict non-scrollable Column
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Distinct header with emergency crisis alert badge and counter
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.crisis_alert_rounded,
                    size: 18,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Context Recall',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: Colors.amber.shade900,
                            ),
                      ),
                      Text(
                        'Confirm and acknowledge active warnings',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: Colors.amber.shade900.withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length} ACTIVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Iterate directly inside Column without any scrollable view
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 16,
                  thickness: 1,
                  color: Colors.amber.shade200.withValues(alpha: 0.6),
                ),
              _buildAlertItem(context, items[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(BuildContext context, DisasterAlert alert) {
    final alertProvider = Provider.of<AlertProvider?>(context);
    final isAck = _acknowledgedIds.contains(alert.id) ||
        (alertProvider?.isAlertAcknowledged(alert.id) ?? false);
    final color = severityColor(alert.severity);

    return InkWell(
      onTap: widget.onTapAlert != null ? () => widget.onTapAlert!(alert) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Vertical severity accent line
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            // Severity indicator pill
            SeverityBadge(severity: alert.severity),
            const SizedBox(width: 8),
            // Alert Title & short subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (alert.instructions != null && alert.instructions!.isNotEmpty)
                    Text(
                      alert.instructions!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // One-Tap Acknowledgment Action Button
            if (isAck)
              Container(
                key: ValueKey('ack_done_${alert.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Acknowledged',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              )
            else
              FilledButton.tonalIcon(
                key: ValueKey('ack_btn_${alert.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.15),
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check, size: 14),
                label: const Text(
                  'Acknowledge',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
                onPressed: () => _handleAcknowledge(alert),
              ),
          ],
        ),
      ),
    );
  }
}
