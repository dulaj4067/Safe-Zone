import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
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
    final strings = appStringsOf(context);
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
                Expanded(
                  child: Text(
                    strings.t('activeAlerts'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${alerts.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(strings.t('noActiveAlerts')),
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
                      subtitle: Text(strings.timeAgo(alert.createdAt)),
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
}
