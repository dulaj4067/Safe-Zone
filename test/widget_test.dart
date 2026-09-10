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
import 'package:safezone/widgets/session_history_list.dart';

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

  testWidgets('Session history is paginated manually and never auto-loads on scroll', (WidgetTester tester) async {
    final sessions = [
      SessionHistoryEntry(id: '1', title: 'Morning check-in', occurredAt: DateTime(2024, 1, 10, 9, 0)),
      SessionHistoryEntry(id: '2', title: 'Risk-zone route', occurredAt: DateTime(2024, 1, 11, 9, 0)),
      SessionHistoryEntry(id: '3', title: 'Shelter reroute', occurredAt: DateTime(2024, 1, 12, 9, 0)),
      SessionHistoryEntry(id: '4', title: 'Evening check-in', occurredAt: DateTime(2024, 1, 13, 9, 0)),
      SessionHistoryEntry(id: '5', title: 'Night watch', occurredAt: DateTime(2024, 1, 14, 9, 0)),
      SessionHistoryEntry(id: '6', title: 'Old session', occurredAt: DateTime(2024, 1, 15, 9, 0)),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SessionHistoryList(
          sessions: sessions,
          pageSize: 3,
        ),
      ),
    );

    expect(find.text('Morning check-in'), findsOneWidget);
    expect(find.text('Risk-zone route'), findsOneWidget);
    expect(find.text('Shelter reroute'), findsOneWidget);
    expect(find.text('Evening check-in'), findsNothing);
    expect(find.text('Load more'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();

    expect(find.text('Evening check-in'), findsNothing);

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Evening check-in'), findsOneWidget);
    expect(find.text('Night watch'), findsOneWidget);
    expect(find.text('Old session'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });
}
