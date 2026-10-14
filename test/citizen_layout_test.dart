import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:safezone/models/alert.dart';
import 'package:safezone/providers/accessibility_provider.dart';
import 'package:safezone/providers/alert_provider.dart';
import 'package:safezone/providers/incident_provider.dart';
import 'package:safezone/providers/safety_provider.dart';
import 'package:safezone/screens/im_safe_screen.dart';
import 'package:safezone/screens/login_screen.dart';
import 'package:safezone/screens/onboarding_screen.dart';
import 'package:safezone/screens/report_incident_screen.dart';
import 'package:safezone/widgets/active_alerts_sheet.dart';
import 'package:safezone/widgets/alert_banner.dart';
import 'package:safezone/widgets/bottom_nav_bar.dart';
import 'package:safezone/widgets/offline_strip.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the key citizen screens on a small phone in every supported
/// language, at normal and maximum text size (the app caps scaling at 2.0),
/// and fails on any RenderFlex overflow. Translations run longer than
/// English, so this is what keeps the layouts honest.
const _locales = ['en', 'si', 'ta', 'ar'];
const _scales = [1.0, 2.0];

DisasterAlert _alert() => DisasterAlert(
  id: 'a1',
  title: 'Kelani River Flood Warning - Kelaniya',
  alertType: 'flood',
  severity: AlertSeverity.red,
  status: AlertStatus.active,
  affectedZoneId: 'z1',
  centerLat: 6.95,
  centerLng: 79.92,
  radiusMeters: 3000,
  instructions:
      'Move to higher ground immediately. Avoid crossing the bridge.\n\n'
      'Transcript: Flood warning. Move to higher ground now.',
  source: 'manual',
  createdAt: DateTime.now().subtract(const Duration(minutes: 7)),
  updatedAt: DateTime.now(),
);

Future<List<String>> _collectOverflows(Future<void> Function() body) async {
  final overflows = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (message.contains('overflowed')) {
      final where = details
          .toString()
          .split('\n')
          .where((l) => l.contains('file:///'));
      overflows.add(
        '${message.split('\n').first} ${where.take(3).join(' | ')}',
      );
    }
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return overflows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // The report form embeds a map whose tile cache asks path_provider for a
    // folder; point it at the system temp dir so no real plugin is needed.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });

  Future<AccessibilityProvider> readyA11y(
    WidgetTester tester,
    String locale,
  ) async {
    final a11y = await tester.runAsync(() async {
      final provider = AccessibilityProvider();
      await provider.load();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return provider;
    });
    await a11y!.setLocaleCode(locale);
    return a11y;
  }

  Widget host(
    Widget home,
    AccessibilityProvider a11y,
    AlertProvider alerts,
    double scale,
  ) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: a11y),
        ChangeNotifierProvider.value(value: alerts),
        ChangeNotifierProvider(create: (_) => SafetyProvider()),
        ChangeNotifierProvider(create: (_) => IncidentProvider()),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          locale: Locale(context.watch<AccessibilityProvider>().localeCode),
          supportedLocales: const [
            Locale('en'),
            Locale('si'),
            Locale('ta'),
            Locale('ar'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
  }

  /// Pumps [build] for every language × text scale; collects overflows.
  Future<void> expectNoOverflow(
    WidgetTester tester,
    Widget Function() build, {
    Future<void> Function(WidgetTester)? interact,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final problems = <String>[];
    for (final locale in _locales) {
      for (final scale in _scales) {
        final a11y = await readyA11y(tester, locale);
        final alerts = AlertProvider();
        alerts.activeAlerts.add(_alert());
        final found = await _collectOverflows(() async {
          await tester.pumpWidget(host(build(), a11y, alerts, scale));
          await tester.pumpAndSettle();
          if (interact != null) await interact(tester);
        });
        problems.addAll(found.map((m) => '[$locale x$scale] $m'));
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  }

  testWidgets('bottom navigation', (tester) async {
    await expectNoOverflow(
      tester,
      () => Scaffold(
        bottomNavigationBar: BottomNavBar(
          currentIndex: 0,
          isAuthority: true, // six tabs: the tightest layout
          onDestinationSelected: (_) {},
        ),
      ),
    );
  });

  testWidgets('offline strip and alert banner', (tester) async {
    await expectNoOverflow(
      tester,
      () => Scaffold(
        body: Column(
          children: [
            const OfflineStrip(),
            AlertBanner(alert: _alert(), onDismiss: () {}, onTap: () {}),
          ],
        ),
      ),
    );
  });

  testWidgets('alert detail sheet with a siren caption', (tester) async {
    await expectNoOverflow(
      tester,
      () => Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showAlertDetailSheet(context, _alert()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      interact: (t) async {
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
      },
    );
  });

  testWidgets('active alerts sheet', (tester) async {
    await expectNoOverflow(
      tester,
      () => Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showActiveAlertsSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      interact: (t) async {
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
      },
    );
  });

  testWidgets("I'm Safe screen", (tester) async {
    await expectNoOverflow(tester, () => const ImSafeScreen());
  });

  testWidgets('onboarding, every page', (tester) async {
    await expectNoOverflow(
      tester,
      () => OnboardingScreen(replay: true, onFinished: () {}),
      interact: (t) async {
        for (var i = 0; i < 3; i++) {
          await t.tap(find.byKey(const Key('onboarding_next')));
          await t.pumpAndSettle();
        }
      },
    );
  });

  // Skipped: the form's data text uses google_fonts, which downloads Inter at
  // runtime; flutter_test blocks the network, so the font load errors out
  // asynchronously. Run this one on a device / with bundled fonts.
  testWidgets('report incident form', (tester) async {
    await expectNoOverflow(tester, () => const ReportIncidentScreen());
  }, skip: true);

  testWidgets('sign-in screen with an error banner', (tester) async {
    await expectNoOverflow(tester, () => const LoginScreen());
  });
}
