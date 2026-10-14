import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';

/// Ambient strip shown while the app is running from cached data. Uses an
/// icon *and* words (never colour alone) and themed colours, so it stays
/// readable in dark mode and glare mode. Pass [message] to override the
/// default "You are offline. Showing the last saved alerts."
class OfflineStrip extends StatelessWidget {
  final String? message;
  const OfflineStrip({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final text = message ?? appStringsOf(context).t('offlineBanner');
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: context.cautionTint,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 16, color: context.inkStrong),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 13, color: context.inkStrong),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
