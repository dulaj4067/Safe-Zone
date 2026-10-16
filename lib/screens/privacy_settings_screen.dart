import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
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
import '../l10n/ui_text.dart';

/// Settings → Privacy & data: the policies (with the version you accepted),
/// the controls that govern what's shared, the app tour, and account
/// deletion.
class PrivacySettingsScreen extends StatefulWidget {
  final AccountDeletionService? deletionService;
  const PrivacySettingsScreen({super.key, this.deletionService});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen>
    with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _loadAccepted();
    _loadRequest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the mail app: refresh in case the request changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _request?.status == DeletionStatus.awaitingEmail) {
      _loadRequest();
    }
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
        title: Text(context.tr('Delete your account?')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('We will email you a 6-digit code to confirm. Once you enter it, an administrator reviews the request and deletes your account and the personal data linked to it. Until then you can cancel here.'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLength: 500,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.tr('Reason (optional)'),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.severityRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Request deletion')),
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
      if (r.status == DeletionStatus.awaitingEmail) {
        await _sendConfirmation();
      } else {
        _say('Deletion request received. Your data hasn\'t been deleted yet.');
      }
    } on DeletionException catch (e) {
      _say(e.message);
    } catch (_) {
      _say('Couldn\'t send the request — check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Sends (or re-sends) the confirmation email and says what happened.
  Future<void> _sendConfirmation() async {
    try {
      await _deletion.sendConfirmationEmail();
      _say('We emailed you a 6-digit code. Enter it here to confirm; nothing is deleted yet.');
    } on DeletionException catch (e) {
      if (!mounted) return;
      _say('{p0} You can ask for the email again from here.', {'p0': context.tr(e.message)});
    } catch (_) {
      _say('Couldn\'t send the email. Check your connection and try again.');
    }
  }

  /// Asks for the emailed code and checks it. Wrong codes are explained
  /// inside the dialog so the person can retry without losing their place.
  Future<void> _enterCode() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? serverError;
    var checking = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(context.tr('Enter your code')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('Type the 6-digit code we emailed you. It works for 30 minutes.')),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('deletion_code_field'),
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: context.tr('Confirmation code'),
                    border: const OutlineInputBorder(),
                    errorText: serverError,
                  ),
                  validator: (v) =>
                      isValidDeletionCode(v) ? null : context.tr('Enter all 6 digits'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: checking ? null : () => Navigator.pop(ctx, false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              key: const Key('deletion_code_submit'),
              onPressed: checking
                  ? null
                  : () async {
                      setDialog(() => serverError = null);
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialog(() => checking = true);
                      try {
                        final result = await _deletion.confirmWithCode(controller.text);
                        if (result == DeletionCodeResult.confirmed) {
                          if (ctx.mounted) Navigator.pop(ctx, true);
                          return;
                        }
                        setDialog(() {
                          checking = false;
                          serverError = switch (result) {
                            DeletionCodeResult.wrong => context.tr('That code is not right. Try again.'),
                            DeletionCodeResult.expired => context.tr('That code has expired. Ask for a new email.'),
                            DeletionCodeResult.tooManyTries =>
                              context.tr('Too many wrong codes. Ask for a new email.'),
                            DeletionCodeResult.noCode =>
                              context.tr('No code has been emailed yet. Ask for a new email.'),
                            _ => context.tr('There is no deletion request waiting for a code.'),
                          };
                        });
                      } on DeletionException catch (e) {
                        setDialog(() {
                          checking = false;
                          serverError = context.tr(e.message);
                        });
                      } catch (_) {
                        setDialog(() {
                          checking = false;
                          serverError = context.tr('Could not check the code. Check your connection.');
                        });
                      }
                    },
              child: checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('Confirm')),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed == true) {
      await _loadRequest();
      _say('Confirmed. An administrator will review your request. Nothing is deleted yet.');
    }
  }

  Future<void> _resendConfirmation() async {
    setState(() => _busy = true);
    try {
      await _sendConfirmation();
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
      _say(e.message);
    } catch (_) {
      _say('Couldn\'t cancel — check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Shows [english] translated, but only while this screen is still open (the
  /// text is looked up after the check, so no BuildContext is used across an
  /// await).
  void _say(String english, [Map<String, Object?>? args]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr(english, args))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Privacy & data'))),
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
              title: Text(context.tr('Family circle & location sharing')),
              subtitle: Text(context.tr('See who can see your location, stop sharing, or remove people')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyCircleScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_applications_outlined),
              title: Text(context.tr('Location & notification permissions')),
              subtitle: Text(context.tr('Change them in your phone\'s app settings')),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final opened = await Geolocator.openAppSettings();
                if (!opened) _say('Couldn\'t open your phone\'s settings.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.tour_outlined),
              title: Text(context.tr('App tour')),
              subtitle: Text(context.tr('Replay the introduction')),
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
              title: Text(context.tr('Privacy questions or a copy of your data')),
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
      return ListTile(
        leading: Icon(Icons.delete_outline),
        title: Text(context.tr('Delete account')),
        subtitle: LinearProgressIndicator(),
      );
    }
    if (_requestError != null) {
      return ListTile(
        leading: const Icon(Icons.delete_outline),
        title: Text(context.tr('Delete account')),
        subtitle: Text(_requestError!),
        trailing: TextButton(onPressed: _loadRequest, child: Text(context.tr('Retry'))),
      );
    }
    final r = _request;
    if (r != null && r.status == DeletionStatus.awaitingEmail) {
      // A ListTile with three trailing buttons left the text a one-letter-wide
      // column. Text on top, actions underneath.
      return Padding(
        key: const Key('deletion_awaiting_email'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.mark_email_unread_outlined, color: AppColors.severityOrange),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Confirm with the emailed code'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('We emailed you a 6-digit code. Enter it to confirm your request. Until you do, nothing goes to an administrator and nothing is deleted.'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    key: const Key('deletion_enter_code'),
                    onPressed: _busy ? null : _enterCode,
                    child: Text(context.tr('Enter code')),
                  ),
                  TextButton(onPressed: _busy ? null : _resendConfirmation, child: Text(context.tr('Resend'))),
                  TextButton(onPressed: _busy ? null : _cancelDeletion, child: Text(context.tr('Cancel'))),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (r != null && r.isOpen) {
      final when = r.requestedAt == null ? '' : ' on ${DateFormat.yMMMd().format(r.requestedAt!)}';
      return ListTile(
        leading: const Icon(Icons.hourglass_top, color: AppColors.severityOrange),
        title: Text(context.tr('Deletion requested')),
        subtitle: Text(
          r.status == DeletionStatus.processing
              ? 'Being processed$when. Your data hasn\'t been fully deleted yet.'
              : 'Confirmed$when. Waiting for an administrator to delete your account. '
                  'Your data hasn\'t been deleted yet.',
        ),
        trailing: r.status == DeletionStatus.received
            ? TextButton(onPressed: _busy ? null : _cancelDeletion, child: Text(context.tr('Cancel')))
            : null,
      );
    }
    return ListTile(
      leading: const Icon(Icons.delete_outline, color: AppColors.severityRed),
      title: Text(context.tr('Delete account')),
      subtitle: Text(context.tr('Request deletion of your account and personal data')),
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
