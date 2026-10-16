import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../legal/policy_documents.dart';
import '../providers/auth_provider.dart';
import 'policy_screen.dart';
import '../l10n/ui_text.dart';

/// Asks a signed-in user to accept the current Terms of Use and Privacy
/// Policy. Shown when they haven't accepted the current versions — first use,
/// an account created by an administrator, or after a material update.
class PolicyAcceptanceScreen extends StatefulWidget {
  /// The documents still to accept (current versions).
  final List<PolicyDocument> documents;

  /// Records the acceptance; the screen closes when it completes.
  final Future<void> Function() onAccept;

  /// True when the user previously accepted an older version.
  final bool isUpdate;

  const PolicyAcceptanceScreen({
    super.key,
    required this.documents,
    required this.onAccept,
    this.isUpdate = false,
  });

  @override
  State<PolicyAcceptanceScreen> createState() => _PolicyAcceptanceScreenState();
}

class _PolicyAcceptanceScreenState extends State<PolicyAcceptanceScreen> {
  bool _agreed = false; // never pre-ticked
  bool _saving = false;

  Future<void> _accept() async {
    setState(() => _saving = true);
    try {
      await widget.onAccept();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Icon(Icons.policy_outlined, size: 40, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  widget.isUpdate ? 'We\'ve updated our terms' : 'Before you continue',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isUpdate
                      ? 'Please review what changed and accept to keep using SafeZone.'
                      : 'Please review how SafeZone works and what happens to your information.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                for (final doc in widget.documents)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(doc.title),
                      subtitle: Text(context.tr('Version {p0}', {'p0': doc.version})),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => PolicyScreen.open(context, doc),
                    ),
                  ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const Key('policy_agree_checkbox'),
                  value: _agreed,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _saving ? null : (v) => setState(() => _agreed = v ?? false),
                  title: Text(context.tr('I agree to the Terms of Use and have read the Privacy Policy'),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('policy_accept_button'),
                  onPressed: _agreed && !_saving ? _accept : null,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(context.tr('Accept and continue')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : () => context.read<AuthProvider>().logout(),
                  child: Text(context.tr('Not now — sign out')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
