import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/alert.dart';
import '../providers/accessibility_provider.dart';
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

  const AlertBanner({
    super.key,
    required this.alert,
    required this.onDismiss,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bannerColor = severityColor(alert.severity);
    final strings = appStringsOf(context);

    // Auto-record that the alert was seen by the resident on device
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertProvider>().markAlertSeen(alert.id);
    });

    final alertProvider = context.watch<AlertProvider>();
    final isFallback =
        alertProvider.lastDeliveryResult?.alertId == alert.id &&
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
            onTap: onTap ?? () => showAlertDetailSheet(context, alert),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      strings.t('sev_${alert.severity.name}').toUpperCase(),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.alt_route,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            strings.t('fallback').toUpperCase(),
                            style: const TextStyle(
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
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the full alert detail & resident acknowledgment sheet for
/// [alert] — the severity badge, title, instructions, delivery-channel
/// status, and the "Acknowledge & Confirm Safe" action. Used both by
/// [AlertBanner]'s own tap handler and by anything else that needs to
/// surface a specific alert's details (e.g. an active-alerts list).
void showAlertDetailSheet(BuildContext context, DisasterAlert alert) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final strings = appStringsOf(ctx);
      // Authorities can attach a plain-language siren script; it's stored
      // after "Transcript:" in the instructions. With captions on, show it
      // as its own caption so people who can't hear the alarm still get it.
      final rawInstructions = alert.instructions;
      final transcriptAt = rawInstructions?.indexOf('Transcript:') ?? -1;
      var captionsOn = true;
      try {
        captionsOn = Provider.of<AccessibilityProvider>(
          ctx,
          listen: false,
        ).captionsEnabled;
      } catch (_) {}
      final showCaption = captionsOn && transcriptAt >= 0;
      final transcript = showCaption
          ? rawInstructions!
                .substring(transcriptAt + 'Transcript:'.length)
                .trim()
          : null;
      final body = showCaption
          ? rawInstructions!.substring(0, transcriptAt).trim()
          : rawInstructions;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        // Scrolls when long translations, a siren caption or large text push
        // the content past the sheet's height.
        child: SingleChildScrollView(
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                (body == null || body.isEmpty)
                    ? strings.t('noInstructions')
                    : body,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (transcript != null && transcript.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.tintSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.closed_caption,
                        size: 20,
                        color: context.brandInk,
                        semanticLabel: strings.t('sirenTranscript'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          transcript,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: context.brandInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                strings.f('alertMeta', {
                  'type': alert.alertType.toUpperCase(),
                  'radius': alert.radiusMeters,
                }),
                style: TextStyle(fontSize: 12, color: context.inkMuted),
              ),
              Builder(
                builder: (ctx) {
                  final prov = ctx.read<AlertProvider>();
                  final delivery =
                      prov.deliveryHistory
                          .where((d) => d.alertId == alert.id)
                          .firstOrNull ??
                      prov.lastDeliveryResult;
                  if (delivery == null || delivery.alertId != alert.id) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
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
                            delivery.fallbackTriggered
                                ? Icons.alt_route
                                : Icons.check_circle,
                            size: 16,
                            color: delivery.fallbackTriggered
                                ? Colors.orange.shade800
                                : Colors.green.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              delivery.fallbackTriggered
                                  ? strings.t('deliveredBackup')
                                  : strings.f('deliveredPrimary', {
                                      'channels': delivery.channelsUsed
                                          .map((c) => c.name.toUpperCase())
                                          .join(', '),
                                    }),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: delivery.fallbackTriggered
                                    ? Colors.orange.shade900
                                    : Colors.green.shade900,
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
                label: Text(strings.t('acknowledgeSafe')),
                onPressed: () async {
                  await context.read<AlertProvider>().acknowledgeAlert(
                    alert.id,
                  );
                  if (ctx.mounted) {
                    // Visual confirmation plus an optional vibration; never sound.
                    pulseHapticOf(ctx);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(strings.t('acknowledged')),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
