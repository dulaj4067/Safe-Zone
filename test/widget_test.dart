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
import 'package:safezone/screens/family_circle_screen.dart';
import 'package:safezone/screens/home_screen.dart';
import 'package:safezone/services/activity_history_service.dart';
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
          ChangeNotifierProvider(create: (_) => ActivityHistoryService()),
        ],
        child: MaterialApp(
          // The SOS button's siren pulse loops forever, which would stop
          // pumpAndSettle from ever settling; it honours this flag.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const HomeScreen(zones: []),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Share my ETA'), findsOneWidget);
    expect(find.byTooltip('Emergency SOS'), findsOneWidget);

    await tester.tap(find.text('Share my ETA'));
    await tester.pumpAndSettle();

    expect(find.text('Family circle'), findsOneWidget);
    // No hardcoded contacts, and no risk-zone banner on this screen.
    expect(find.text('Asha Perera'), findsNothing);
    expect(find.textContaining('High risk'), findsNothing);
  });

  test('Family circle never shows placeholder members when signed out', () async {
    final provider = SafetyProvider();
    await provider.loadFamilyCircle();

    expect(provider.family, isEmpty);
    expect(provider.circleLocations, isEmpty);
    expect(provider.errorMessage, isNull);
  });

  testWidgets('Joining with a code closes the dialog without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SafetyProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showJoinWithCodeDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ZZZZ9999ZZZZ');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Join a family circle'), findsNothing);
    // Signed out in tests, so accepting fails with a readable message.
    expect(find.text('Sign in to join a family circle.'), findsOneWidget);
  });

  test('Invite links point at the public family-invite function', () {
    final link = SafetyProvider.inviteLinkFor('ABC123DEF456');

    expect(link.scheme, 'https');
    expect(link.host, 'frkwsgriwdezkvrmgsgf.supabase.co');
    expect(link.path, '/functions/v1/family-invite');
    expect(link.queryParameters['code'], 'ABC123DEF456');
  });

  test('Sharing can start in local demo mode without auth or GPS', () async {
    final provider = SafetyProvider();
    await provider.startSharingEta(currentRiskZone: sampleRiskZones.first);

    expect(provider.isSharing, isTrue);
    expect(provider.latestUpdate, isNotNull);
    expect(provider.errorMessage, isNull);
  });

  test('Broadcast can be sent in demo mode when auth is unavailable', () async {
    final provider = SafetyProvider();
    await provider.sendImSafeBroadcast(currentRiskZone: sampleRiskZones.first);

    expect(provider.lastBroadcastAt, isNotNull);
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
