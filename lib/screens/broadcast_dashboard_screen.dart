import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/alert_engagement.dart';
import '../models/zone.dart';
import '../providers/alert_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/alert_engagement_sheet.dart';
import '../widgets/severity_badge.dart';

/// Story 4 & Authority Dashboard: authority-only live view of every active/escalated broadcast,
/// with real-time zone resident seen and acknowledged percentage analytics, action threshold
/// indicators ("Further Action Needed"), resident roster inspection, and inline resolve/archive actions.
class BroadcastDashboardScreen extends StatefulWidget {
  final List<Zone> zones;

  const BroadcastDashboardScreen({super.key, this.zones = const []});

  @override
  State<BroadcastDashboardScreen> createState() =>
      _BroadcastDashboardScreenState();
}

class _BroadcastDashboardScreenState extends State<BroadcastDashboardScreen> {
  AlertSeverity? _filter;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final alerts = _filter == null
        ? provider.allAlerts
        : provider.allAlerts.where((a) => a.severity == _filter).toList();

    // Highest severity first, then most recent — matches Story 4 AC.
    final sorted = [...alerts]
      ..sort((a, b) {
        final sevCompare = b.severity.index.compareTo(a.severity.index);
        if (sevCompare != 0) return sevCompare;
        return b.createdAt.compareTo(a.createdAt);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast Dashboard')),
      body: Column(
        children: [
          _SeverityFilterRow(
            selected: _filter,
            onSelected: (s) => setState(() => _filter = s),
          ),
          if (provider.isOffline)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                'Offline — showing last synced alerts',
                style: TextStyle(fontSize: 13),
              ),
            ),
          Expanded(
            child: sorted.isEmpty
                ? const Center(child: Text('No active broadcasts.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _AlertDashboardCard(
                      alert: sorted[index],
                      zones: widget.zones,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SeverityFilterRow extends StatelessWidget {
  final AlertSeverity? selected;
  final ValueChanged<AlertSeverity?> onSelected;

  const _SeverityFilterRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
            const SizedBox(width: 8),
            ...AlertSeverity.values.map((s) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.label),
                  selected: selected == s,
                  onSelected: (_) => onSelected(selected == s ? null : s),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AlertDashboardCard extends StatelessWidget {
  final DisasterAlert alert;
  final List<Zone> zones;

  const _AlertDashboardCard({
    required this.alert,
    this.zones = const [],
  });

  @override
  Widget build(BuildContext context) {
    final alertProvider = context.watch<AlertProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Severity + Title
            Row(
              children: [
                SeverityBadge(severity: alert.severity),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              alert.instructions ?? 'No instructions provided',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${alert.alertType} · radius ${alert.radiusMeters}m · ${_timeAgo(alert.createdAt)}',
              style: AppTheme.dataText(context),
            ),
            const SizedBox(height: 12),

            // Resident Seen & Acknowledged Reach Section
            FutureBuilder<ZoneAlertEngagement>(
              future: alertProvider.getEngagementForAlert(
                alert.id,
                zoneId: alert.affectedZoneId,
                knownZones: zones,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                final engagement = snapshot.data;
                if (engagement == null) return const SizedBox.shrink();

                return _buildEngagementSummaryBox(context, engagement);
              },
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text('Resident Breakdown', style: TextStyle(fontSize: 12)),
                  onPressed: () => AlertEngagementSheet.show(
                    context,
                    alert: alert,
                    zones: zones,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _confirmAndRun(
                    context,
                    title: 'Resolve alert?',
                    body: 'Citizens will see this as de-escalated.',
                    action: () =>
                        context.read<AlertProvider>().resolveAlert(alert.id),
                  ),
                  child: const Text('Resolve'),
                ),
                const SizedBox(width: 4),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _confirmAndRun(
                    context,
                    title: 'Archive alert?',
                    body: 'This removes it from the live dashboard entirely.',
                    action: () =>
                        context.read<AlertProvider>().archiveAlert(alert.id),
                  ),
                  child: const Text('Archive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementSummaryBox(
    BuildContext context,
    ZoneAlertEngagement engagement,
  ) {
    final isCritical = engagement.urgency == EngagementUrgency.critical;
    final isWarning = engagement.urgency == EngagementUrgency.warning;

    final badgeColor = isCritical
        ? AppColors.severityRed
        : (isWarning ? AppColors.severityOrange : AppColors.severityGreen);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone Target and Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.share_location, size: 14, color: AppColors.deepEstuary),
                  const SizedBox(width: 4),
                  Text(
                    engagement.zoneName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.deepEstuary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (engagement.needsFurtherAction) ...[
                      Icon(Icons.warning_amber_rounded, size: 11, color: badgeColor),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      engagement.needsFurtherAction
                          ? 'FURTHER ACTION NEEDED'
                          : 'ON TRACK',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Percentage Metrics Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Acknowledged %
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.severityGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Acknowledged',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${engagement.acknowledgedPercentage.toStringAsFixed(1)}% (${engagement.acknowledgedCount}/${engagement.totalResidents})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.severityGreen,
                    ),
                  ),
                ],
              ),

              // Seen %
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.deepEstuary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Seen / Opened',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${engagement.seenPercentage.toStringAsFixed(1)}% (${engagement.seenCount}/${engagement.totalResidents})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepEstuary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Multi-layer Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: (engagement.acknowledgedPercentage / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade300,
                color: engagement.needsFurtherAction
                    ? AppColors.severityOrange
                    : AppColors.severityGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndRun(
    BuildContext context, {
    required String title,
    required String body,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await action();
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
