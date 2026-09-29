import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../providers/alert_provider.dart';
import '../theme/app_colors.dart';
import 'alert_banner.dart';
import 'severity_badge.dart';

/// Opens the notification bell's target: every currently active alert
/// (from [AlertProvider.activeAlerts]), most severe first, tied to the
/// same detail/acknowledge sheet the top banner uses so there's one
/// consistent alert-detail experience in the app.
void showActiveAlertsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _ActiveAlertsSheet(),
  );
}

class _ActiveAlertsSheet extends StatelessWidget {
  static const _severityOrder = [
    AlertSeverity.red,
    AlertSeverity.orange,
    AlertSeverity.yellow,
    AlertSeverity.green,
  ];

  @override
  Widget build(BuildContext context) {
    final alerts = [...context.watch<AlertProvider>().activeAlerts]
      ..sort((a, b) => _severityOrder
          .indexOf(a.severity)
          .compareTo(_severityOrder.indexOf(b.severity)));

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Active Alerts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Text(
                  '${alerts.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.slateMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('No active alerts right now.'),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final alert = alerts[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SeverityBadge(severity: alert.severity),
                      title: Text(
                        alert.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(_relativeTime(alert.createdAt)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(context);
                        showAlertDetailSheet(context, alert);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
