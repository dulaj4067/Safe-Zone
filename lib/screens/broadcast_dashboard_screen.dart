import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../providers/alert_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/severity_badge.dart';

/// Story 4: authority-only live view of every active/escalated broadcast,
/// with inline resolve/archive actions. Gate the entry point to this
/// screen the same way as AdminBroadcastScreen — only reachable when
/// currentUser.role.isAuthority is true; RLS is the real enforcement on
/// the resolve/archive calls themselves.
class BroadcastDashboardScreen extends StatefulWidget {
  const BroadcastDashboardScreen({super.key});

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
        ? provider.activeAlerts
        : provider.activeAlerts.where((a) => a.severity == _filter).toList();

    // Highest severity first, then most recent — matches Story 4 AC.
    final sorted = [...alerts]
      ..sort((a, b) {
        final sevCompare =
            b.severity.index.compareTo(a.severity.index);
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
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _AlertDashboardCard(alert: sorted[index]),
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
  const _AlertDashboardCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
              '${alert.alertType} · radius ${alert.radiusMeters}m · '
              '${_timeAgo(alert.createdAt)}',
              style: AppTheme.dataText(context),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
