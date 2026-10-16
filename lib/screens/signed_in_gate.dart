import 'package:flutter/material.dart';

import '../legal/policy_documents.dart';
import '../services/consent_service.dart';
import '../services/onboarding_service.dart';
import '../services/supabase_service.dart';
import '../widgets/splash_screen.dart';
import 'app_shell.dart';
import 'onboarding_screen.dart';
import 'policy_acceptance_screen.dart';
import '../l10n/ui_text.dart';

/// What a signed-in user sees before the main app:
///   1. the current Terms / Privacy Policy, if not yet accepted (required);
///   2. onboarding, if this account hasn't finished it;
///   3. the app.
/// Each check fails open to the next step when the server can't be reached
/// (using locally saved state), so a network problem never locks someone
/// out of disaster warnings.
class SignedInGate extends StatefulWidget {
  const SignedInGate({super.key});

  @override
  State<SignedInGate> createState() => _SignedInGateState();
}

enum _Stage { loading, policies, onboarding, app }

class _SignedInGateState extends State<SignedInGate> {
  final ConsentService _consent = ConsentService();
  final OnboardingService _onboarding = OnboardingService();

  _Stage _stage = _Stage.loading;
  List<PolicyDocument> _outstanding = const [];
  bool _isPolicyUpdate = false;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  Future<void> _evaluate() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    await _consent.syncPending(uid);
    final accepted = await _consent.acceptedVersions(uid);
    final outstanding = [
      for (final doc in requiredPolicies)
        if (accepted[doc.id] != doc.version) doc,
    ];
    if (!mounted) return;
    if (outstanding.isNotEmpty) {
      setState(() {
        _outstanding = outstanding;
        _isPolicyUpdate = outstanding.any((d) => accepted.containsKey(d.id));
        _stage = _Stage.policies;
      });
      return;
    }

    final needsOnboarding = await _onboarding.needsOnboarding(uid);
    if (!mounted) return;
    setState(() => _stage = needsOnboarding ? _Stage.onboarding : _Stage.app);
  }

  Future<void> _acceptPolicies() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    final uploaded = await _consent.accept(uid, _outstanding);
    if (!mounted) return;
    if (!uploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('You\'re offline — your acceptance is saved and will be sent when you reconnect.')),
        ),
      );
    }
    setState(() => _stage = _Stage.loading);
    await _evaluate();
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.loading:
        return const SplashScreen();
      case _Stage.policies:
        return PolicyAcceptanceScreen(
          documents: _outstanding,
          isUpdate: _isPolicyUpdate,
          onAccept: _acceptPolicies,
        );
      case _Stage.onboarding:
        return OnboardingScreen(
          onFinished: () => setState(() => _stage = _Stage.app),
        );
      case _Stage.app:
        return const AppShell();
    }
  }
}
