// Basic smoke test — verifies the app starts without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:safezone/main.dart';
import 'package:safezone/models/risk_zone.dart';
import 'package:safezone/providers/alert_provider.dart';
import 'package:safezone/providers/incident_provider.dart';
import 'package:safezone/providers/safety_provider.dart';
import 'package:safezone/screens/home_screen.dart';

void main() {
  setUpAll(() async {
    // Initialise Supabase before the widget tree is pumped so that
    // SupabaseService.client is available during the test.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://frkwsgriwdezkvrmgsgf.supabase.co',
      anonKey: 'sb_publishable_1Ax1SZF9hldmiJ1kyi338w_BvOL4Gxd',
    );
  });

  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const DisasterApp());
    // Let async init settle.
    await tester.pump(const Duration(seconds: 1));
    // The app should render without an unhandled exception.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home screen exposes the ETA sharing action', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AlertProvider()),
          ChangeNotifierProvider(create: (_) => IncidentProvider()),
          ChangeNotifierProvider(create: (_) => SafetyProvider()),
        ],
        child: MaterialApp(
          home: const HomeScreen(zones: []),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Share my ETA'), findsOneWidget);

    await tester.tap(find.text('Share my ETA'));
    await tester.pumpAndSettle();

    expect(find.text('Share Live Location'), findsOneWidget);
  });

  test('Safety circle falls back to demo contacts when backend data is unavailable', () async {
    final provider = SafetyProvider();
    await provider.loadSafetyCircle();

    expect(provider.circle, isNotEmpty);
    expect(provider.errorMessage, isNull);
  });

  test('Sharing can start in local demo mode without auth or GPS', () async {
    final provider = SafetyProvider();
    await provider.startSharingEta(currentRiskZone: sampleRiskZones.first);

    expect(provider.isSharing, isTrue);
    expect(provider.latestUpdate, isNotNull);
    expect(provider.errorMessage, isNull);
  });
}
