import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:safezone/l10n/app_strings.dart';
import 'package:safezone/models/incident.dart';
import 'package:safezone/providers/accessibility_provider.dart';
import 'package:safezone/screens/onboarding_screen.dart';
import 'package:safezone/widgets/bottom_nav_bar.dart';
import 'package:safezone/widgets/im_safe_broadcast_button.dart';
import 'package:safezone/widgets/offline_strip.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('catalog integrity', () {
    final catalogs = AppStrings.catalogs;
    final english = catalogs['en']!;

    test('every language defines exactly the keys English does', () {
      for (final entry in catalogs.entries.where((e) => e.key != 'en')) {
        final missing = english.keys.toSet().difference(entry.value.keys.toSet());
        final extra = entry.value.keys.toSet().difference(english.keys.toSet());
        expect(missing, isEmpty, reason: '${entry.key} is missing keys');
        expect(extra, isEmpty, reason: '${entry.key} has keys English lacks');
      }
    });

    test('no translation is blank and placeholders match English', () {
      final placeholder = RegExp(r'\{[a-zA-Z]+\}');
      for (final entry in catalogs.entries) {
        for (final key in english.keys) {
          final text = entry.value[key]!;
          expect(text.trim(), isNotEmpty, reason: '${entry.key}.$key is blank');
          final want = placeholder.allMatches(english[key]!).map((m) => m.group(0)).toSet();
          final got = placeholder.allMatches(text).map((m) => m.group(0)).toSet();
          expect(got, want, reason: '${entry.key}.$key placeholders differ from English');
        }
      }
    });

    test('every incident category and severity has a label in every language', () {
      for (final code in catalogs.keys) {
        final s = AppStrings.forCode(code);
        for (final c in IncidentCategory.values) {
          expect(s.category(c), isNot(startsWith('cat_')), reason: '$code ${c.name}');
        }
        for (final sev in ['green', 'yellow', 'orange', 'red']) {
          expect(s.t('sev_$sev'), isNot(startsWith('sev_')), reason: '$code $sev');
        }
      }
    });

    test('unknown keys fall back to English, then to the key itself', () {
      expect(AppStrings.si.t('definitely-not-a-key'), 'definitely-not-a-key');
      expect(AppStrings.forCode('xx').t('navHome'), 'Home');
    });

    test('placeholders are filled and relative times are localized', () {
      expect(AppStrings.en.f('sentAt', {'time': '10:42'}), 'Sent at 10:42');
      final now = DateTime(2026, 10, 15, 12);
      expect(AppStrings.en.timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
      expect(AppStrings.en.timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(AppStrings.en.timeAgo(now, now: now), 'Just now');
      expect(AppStrings.ta.timeAgo(now.subtract(const Duration(days: 2)), now: now), isNot(contains('{')));
    });
  });

  /// The provider loads saved settings from its constructor; wait for that to
  /// finish so it can't overwrite a language a test sets straight afterwards.
  Future<AccessibilityProvider> readyA11y(WidgetTester tester) async {
    final a11y = await tester.runAsync(() async {
      final provider = AccessibilityProvider();
      await provider.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return provider;
    });
    return a11y!;
  }

  Widget app(Widget child, AccessibilityProvider a11y) => ChangeNotifierProvider.value(
        value: a11y,
        child: Builder(
          builder: (context) => MaterialApp(
            locale: Locale(context.watch<AccessibilityProvider>().localeCode),
            supportedLocales: const [Locale('en'), Locale('si'), Locale('ta'), Locale('ar')],
            // Same delegates as main.dart: the Default* ones only know English.
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: child, bottomNavigationBar: null),
          ),
        ),
      );

  testWidgets('bottom navigation follows the chosen language', (tester) async {
    final a11y = await readyA11y(tester);
    await tester.pumpWidget(app(
      BottomNavBar(currentIndex: 0, isAuthority: false, onDestinationSelected: (_) {}),
      a11y,
    ));
    expect(find.text('Home'), findsWidgets);

    await a11y.setLocaleCode('si');
    await tester.pumpAndSettle();
    expect(find.text('මුල් පිටුව'), findsWidgets);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('offline strip uses words and an icon, in the chosen language', (tester) async {
    final a11y = await readyA11y(tester);
    await a11y.setLocaleCode('ar');
    await tester.pumpWidget(app(const OfflineStrip(), a11y));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.text(AppStrings.ar.t('offlineBanner')), findsOneWidget);
    // Arabic switches the layout right-to-left automatically.
    final dir = Directionality.of(tester.element(find.byType(OfflineStrip)));
    expect(dir, TextDirection.rtl);
  });

  testWidgets('I\'m Safe button exposes tap and long-press to assistive tech', (tester) async {
    final handle = tester.ensureSemantics();
    final a11y = await readyA11y(tester);
    var sent = 0;
    await tester.pumpWidget(app(
      Center(
        child: ImSafeBroadcastButton(onConfirmed: () async {
          sent++;
          return true;
        }),
      ),
      a11y,
    ));

    final node = tester.getSemantics(find.byType(ImSafeBroadcastButton));
    final data = node.getSemanticsData();
    expect(data.label, "I'm Safe");
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.longPress), isTrue);

    // What TalkBack's double-tap does: perform the semantic tap action.
    tester.semantics.tap(find.semantics.byLabel("I'm Safe"));
    await tester.pumpAndSettle();
    expect(sent, 1, reason: 'a screen-reader double-tap sends without a 900ms hold');
    handle.dispose();
  });

  testWidgets('onboarding language chips switch the whole screen live', (tester) async {
    final a11y = await readyA11y(tester);
    await tester.pumpWidget(app(
      OnboardingScreen(replay: true, onFinished: () {}),
      a11y,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to SafeZone'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('தமிழ்'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.ta.t('obWelcome')), findsOneWidget);
    expect(find.text('Welcome to SafeZone'), findsNothing);
    expect(a11y.localeCode, 'ta');
  });
}
