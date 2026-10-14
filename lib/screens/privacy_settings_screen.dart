import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../legal/policy_documents.dart';
import '../services/account_deletion_service.dart';
import '../services/consent_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'family_circle_screen.dart';
import 'onboarding_screen.dart';
import 'policy_screen.dart';

/// Settings → Privacy & data: the policies (with the version you accepted),
/// the controls that govern what's shared, the app tour, and account
/// deletion.
class PrivacySettingsScreen extends StatefulWidget {
  final AccountDeletionService? deletionService;
  const PrivacySettingsScreen({super.key, this.deletionService});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  late final AccountDeletionService _deletion =
      widget.deletionService ?? AccountDeletionService();
  Map<String, String> _accepted = const {};

  DeletionRequest? _request;
  bool _requestLoading = true;
  String? _requestError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadAccepted();
    _loadRequest();
  }

  Future<void> _loadAccepted() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    final accepted = await ConsentService().acceptedVersions(uid);
    if (mounted) setState(() => _accepted = accepted);
  }

  Future<void> _loadRequest() async {
    setState(() {
      _requestLoading = true;
      _requestError = null;
    });
    try {
      final r = await _deletion.current();
      if (mounted) setState(() => _request = r);
    } catch (_) {
      if (mounted) setState(() => _requestError = 'Couldn\'t check deletion status.');
    } finally {
      if (mounted) setState(() => _requestLoading = false);
    }
  }

  Future<void> _requestDeletion() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This sends a request to delete your account and the personal '
                'data linked to it. The operator completes deletion; until then '
                'you can cancel the request here.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.severityRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Request deletion'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final r = await _deletion.request(reason: reason.isEmpty ? null : reason);
      if (!mounted) return;
      setState(() => _request = r);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deletion request received. Your data hasn\'t been deleted yet.')),
      );
    } on DeletionException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Couldn\'t send the request — check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelDeletion() async {
    setState(() => _busy = true);
    try {
      await _deletion.cancel();
      await _loadRequest();
    } on DeletionException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Couldn\'t cancel — check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & data')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _header(context, 'Policies'),
            for (final doc in requiredPolicies)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(doc.title),
                subtitle: Text(_policySubtitle(doc)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => PolicyScreen.open(context, doc),
              ),
            const Divider(),
            _header(context, 'What you share'),
            ListTile(
              leading: const Icon(Icons.family_restroom_outlined),
              title: const Text('Family circle & location sharing'),
              subtitle: const Text('See who can see your location, stop sharing, or remove people'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyCircleScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_applications_outlined),
              title: const Text('Location & notification permissions'),
              subtitle: const Text('Change them in your phone\'s app settings'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final opened = await Geolocator.openAppSettings();
                if (!opened) _showError('Couldn\'t open your phone\'s settings.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.tour_outlined),
              title: const Text('App tour'),
              subtitle: const Text('Replay the introduction'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => OnboardingScreen(
                    replay: true,
                    onFinished: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ),
            const Divider(),
            _header(context, 'Your account'),
            _deletionTile(context),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Privacy questions or a copy of your data'),
              subtitle: Text(LegalConfig.contactLabel),
            ),
          ],
        ),
      ),
    );
  }

  String _policySubtitle(PolicyDocument doc) {
    final updated = DateFormat.yMMMd().format(doc.lastUpdated);
    final accepted = _accepted[doc.id];
    final acceptance = accepted == null
        ? 'not accepted on this device'
        : accepted == doc.version
            ? 'you accepted this version'
            : 'you accepted v$accepted';
    return 'Version ${doc.version}, updated $updated · $acceptance';
  }

  Widget _deletionTile(BuildContext context) {
    if (_requestLoading) {
      return const ListTile(
        leading: Icon(Icons.delete_outline),
        title: Text('Delete account'),
        subtitle: LinearProgressIndicator(),
      );
    }
    if (_requestError != null) {
      return ListTile(
        leading: const Icon(Icons.delete_outline),
        title: const Text('Delete account'),
        subtitle: Text(_requestError!),
        trailing: TextButton(onPressed: _loadRequest, child: const Text('Retry')),
      );
    }
    final r = _request;
    if (r != null && r.isOpen) {
      final when = r.requestedAt == null ? '' : ' on ${DateFormat.yMMMd().format(r.requestedAt!)}';
      return ListTile(
        leading: const Icon(Icons.hourglass_top, color: AppColors.severityOrange),
        title: const Text('Deletion requested'),
        subtitle: Text(
          r.status == DeletionStatus.processing
              ? 'Being processed$when. Your data hasn\'t been fully deleted yet.'
              : 'Received$when — waiting for the operator. Your data hasn\'t been deleted yet.',
        ),
        trailing: r.status == DeletionStatus.received
            ? TextButton(onPressed: _busy ? null : _cancelDeletion, child: const Text('Cancel'))
            : null,
      );
    }
    return ListTile(
      leading: const Icon(Icons.delete_outline, color: AppColors.severityRed),
      title: const Text('Delete account'),
      subtitle: const Text('Request deletion of your account and personal data'),
      onTap: _busy ? null : _requestDeletion,
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Semantics(
          header: true,
          child: Text(text, style: Theme.of(context).textTheme.titleSmall),
        ),
      );
}
