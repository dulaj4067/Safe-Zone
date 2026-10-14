import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safezone/legal/policy_documents.dart';
import 'package:safezone/services/alert_engagement_service.dart';
import 'package:safezone/services/consent_service.dart';
import 'package:safezone/services/onboarding_service.dart';
import 'package:safezone/screens/onboarding_screen.dart';
import 'package:safezone/screens/policy_acceptance_screen.dart';

// Supabase isn't initialised in unit tests, so every server call fails —
// which exercises the offline/fallback paths these services must handle.
void main() {
  const uid = 'user-1';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ConsentService', () {
    test('a new user must accept every current policy', () async {
      final outstanding = await ConsentService().outstanding(uid);
      expect(outstanding.map((d) => d.id), containsAll(['terms', 'privacy']));
    });

    test('acceptance made offline is kept locally and queued, not lost', () async {
      final service = ConsentService();
      final uploaded = await service.accept(uid, requiredPolicies);

      expect(uploaded, isFalse, reason: 'no server in tests');
      expect(await service.outstanding(uid), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('consent_v1_pending_$uid'), isNotNull);
    });

    test('an older accepted version is asked again after a policy update', () async {
      SharedPreferences.setMockInitialValues({
        'consent_v1_accepted_$uid':
            '{"terms":"0.9","privacy":"${privacyPolicy.version}"}',
      });
      final outstanding = await ConsentService().outstanding(uid);
      expect(outstanding.map((d) => d.id), ['terms']);
    });

    test('acceptances are per user', () async {
      await ConsentService().accept(uid, requiredPolicies);
      expect(await ConsentService().outstanding('someone-else'), hasLength(2));
    });

    test('corrupt local data is treated as not accepted', () async {
      SharedPreferences.setMockInitialValues({'consent_v1_accepted_$uid': '{oops'});
      expect(await ConsentService().outstanding(uid), hasLength(2));
    });
  });

  group('OnboardingService', () {
    test('new user needs onboarding; completion is remembered', () async {
      final service = OnboardingService();
      expect(await service.needsOnboarding(uid), isTrue);
      await service.complete(uid);
      expect(await service.needsOnboarding(uid), isFalse);
    });

    test('progress survives an interruption and is cleared on completion', () async {
      final service = OnboardingService();
      await service.saveStep(uid, 2);
      expect(await OnboardingService().savedStep(uid), 2);
      await service.complete(uid);
      expect(await service.savedStep(uid), 0);
    });

    test('declining notifications is remembered per user', () async {
      final service = OnboardingService();
      expect(await service.notificationsDeclined(uid), isFalse);
      await service.setNotificationsDeclined(uid, true);
      expect(await service.notificationsDeclined(uid), isTrue);
      expect(await service.notificationsDeclined('other'), isFalse);
    });
  });

  group('AlertEngagementService honesty', () {
    test('with no residents and no simulation, the dashboard shows zero — not invented people', () async {
      final engagement = await AlertEngagementService().getZoneEngagement(
        'alert-x',
        zoneId: 'zone-empty',
        zoneName: 'Empty zone',
      );
      expect(engagement.totalResidents, 0);
      expect(engagement.residents, isEmpty);
    });

    test('simulated residents (debug only) are clearly labelled', () async {
      final service = AlertEngagementService();
      await service.simulateEngagement('alert-sim', 'z', ackRate: 0.5, seenRate: 0.5);
      final engagement = await service.getZoneEngagement('alert-sim', zoneId: 'z');
      expect(engagement.residents, isNotEmpty);
      expect(
        engagement.residents.every((r) => r.fullName.startsWith('Simulated resident')),
        isTrue,
      );
    });
  });

  group('PolicyAcceptanceScreen', () {
    testWidgets('accept stays disabled until the box is ticked', (tester) async {
      var accepted = 0;
      await tester.pumpWidget(MaterialApp(
        home: PolicyAcceptanceScreen(
          documents: requiredPolicies,
          onAccept: () async => accepted++,
        ),
      ));

      final button = find.byKey(const Key('policy_accept_button'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      final box = tester.widget<CheckboxListTile>(find.byKey(const Key('policy_agree_checkbox')));
      expect(box.value, isFalse, reason: 'consent must never be pre-ticked');

      await tester.tap(find.byKey(const Key('policy_agree_checkbox')));
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(accepted, 1);
    });

    testWidgets('lists each document and says when it is an update', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PolicyAcceptanceScreen(
          documents: [termsOfUse],
          isUpdate: true,
          onAccept: () async {},
        ),
      ));
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('We\'ve updated our terms'), findsOneWidget);
    });
  });

  group('OnboardingScreen', () {
    testWidgets('Skip jumps to the end; finishing calls onFinished', (tester) async {
      var finished = false;
      await tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(replay: true, onFinished: () => finished = true),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to SafeZone'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('You\'re set'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);

      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
    });

    testWidgets('area step degrades gracefully when areas can\'t load', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(replay: true, onFinished: () {}),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text('Your area'), findsOneWidget);
      expect(find.textContaining('Couldn\'t load areas'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
