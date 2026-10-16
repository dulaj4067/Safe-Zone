import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../legal/policy_documents.dart';
import '../screens/policy_screen.dart';
import '../theme/app_colors.dart';

/// The foot of the Settings page: team logo, app name and version,
/// copyright, and links to the legal documents. The version is read from
/// the installed build, never hardcoded.
class AboutFooter extends StatelessWidget {
  const AboutFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final year = DateTime.now().year;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          // The logo is dark artwork on white, so it sits on a white tile in
          // both themes rather than being tinted.
          Semantics(
            label: 'The Pioneers logo',
            image: true,
            child: Container(
              key: const Key('pioneers_logo'),
              width: 200,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Image.asset(
                'assets/pioneers_logo.jpg',
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) => Text(
                  'the pioneers',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final info = snap.data;
              return Text(
                info == null
                    ? 'SafeZone'
                    : 'SafeZone · Version ${info.version} (${info.buildNumber})',
                key: const Key('about_version'),
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            'Sri Lanka Disaster Early Warning',
            style: textTheme.bodySmall?.copyWith(color: context.inkMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                key: const Key('about_terms'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => PolicyScreen.open(context, termsOfUse),
                child: const Text('Terms of Use'),
              ),
              TextButton(
                key: const Key('about_privacy'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => PolicyScreen.open(context, privacyPolicy),
                child: const Text('Privacy Policy'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '© $year The Pioneers. All rights reserved.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: context.inkMuted),
          ),
          Text(
            'Built by The Pioneers',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: context.inkMuted),
          ),
        ],
      ),
    );
  }
}
