import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../legal/policy_documents.dart';
import '../theme/app_colors.dart';
import '../l10n/ui_text.dart';

/// Read-only view of one policy document (Terms of Use / Privacy Policy).
class PolicyScreen extends StatelessWidget {
  final PolicyDocument document;
  const PolicyScreen({super.key, required this.document});

  static Future<void> open(BuildContext context, PolicyDocument document) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PolicyScreen(document: document)),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(context.tr('Version {p0} · Last updated {p1}', {'p0': document.version, 'p1': DateFormat.yMMMMd().format(document.lastUpdated)}),
              style: theme.textTheme.bodySmall,
            ),
            if (LegalConfig.pendingLegalReview) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cautionTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(context.tr('Draft pending legal review. It describes how the app works today; some operator details are still to be confirmed.'),
                  style: TextStyle(color: context.inkStrong, fontSize: 13),
                ),
              ),
            ],
            for (final section in document.sections) ...[
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(section.heading, style: theme.textTheme.titleMedium),
              ),
              for (final p in section.paragraphs) ...[
                const SizedBox(height: 8),
                Text(p, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
