import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safezone/models/alert.dart';
import 'package:safezone/models/incident.dart';
import 'package:safezone/providers/alert_provider.dart';
import 'package:safezone/providers/incident_provider.dart';
import 'package:safezone/providers/safety_provider.dart';
import 'package:safezone/screens/home_screen.dart';
import 'package:safezone/screens/incidents_screen.dart';
import 'package:safezone/widgets/context_recall_card.dart';
import 'package:safezone/widgets/session_history_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DisasterAlert createAlert({
    required String id,
    required String title,
    AlertSeverity severity = AlertSeverity.red,
    String? instructions,
  }) {
    final now = DateTime.now();
    return DisasterAlert(
      id: id,
      title: title,
      instructions: instructions ?? 'Follow critical emergency evacuation protocols.',
      severity: severity,
      status: AlertStatus.active,
      alertType: 'flood',
      centerLat: 6.9271,
      centerLng: 79.8612,
      radiusMeters: 2500,
      source: 'official',
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Offline Last-Known Alerts Feature Tests', () {
    testWidgets('Offline recall card retains last-known critical alerts when offline', (WidgetTester tester) async {
      final alert = createAlert(id: 'crit_1', title: 'Severe Dam Break Flood Warning', severity: AlertSeverity.red);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextRecallCard(
              key: const ValueKey('offline_last_known_alerts_card'),
              alerts: [alert],
              maxItems: 2,
              title: 'Last-Known Alerts',
              subtitle: 'Offline critical alert recall',
              isOffline: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('offline_last_known_alerts_card')), findsOneWidget);
      expect(find.text('Last-Known Alerts'), findsOneWidget);
      expect(find.text('Offline critical alert recall'), findsOneWidget);
      expect(find.text('Severe Dam Break Flood Warning'), findsOneWidget);
      expect(find.text('1 OFFLINE'), findsOneWidget);
    });

    testWidgets('Offline recall card enforces a hard limit of 2 items maximum', (WidgetTester tester) async {
      final alerts = [
        createAlert(id: 'crit_1', title: 'Critical Alert 1', severity: AlertSeverity.red),
        createAlert(id: 'crit_2', title: 'Critical Alert 2', severity: AlertSeverity.red),
        createAlert(id: 'crit_3', title: 'Critical Alert 3', severity: AlertSeverity.red),
        createAlert(id: 'crit_4', title: 'Critical Alert 4', severity: AlertSeverity.red),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextRecallCard(
              key: const ValueKey('offline_last_known_alerts_card'),
              alerts: alerts,
              maxItems: 2,
              isOffline: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Only first 2 items must appear
      expect(find.text('Critical Alert 1'), findsOneWidget);
      expect(find.text('Critical Alert 2'), findsOneWidget);

      // 3rd and 4th items must NOT appear due to the 2 items maximum hard limit
      expect(find.text('Critical Alert 3'), findsNothing);
      expect(find.text('Critical Alert 4'), findsNothing);
      expect(find.text('2 OFFLINE'), findsOneWidget);
    });

    testWidgets('No scrolling inside the recall/offline card', (WidgetTester tester) async {
      final alerts = [
        createAlert(id: 'crit_1', title: 'Critical Alert 1', severity: AlertSeverity.red),
        createAlert(id: 'crit_2', title: 'Critical Alert 2', severity: AlertSeverity.red),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextRecallCard(
              key: const ValueKey('offline_last_known_alerts_card'),
              alerts: alerts,
              maxItems: 2,
              isOffline: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const ValueKey('offline_last_known_alerts_card'));
      expect(cardFinder, findsOneWidget);

      // Verify there is NO Scrollable widget inside the card
      final scrollableInCard = find.descendant(
        of: cardFinder,
        matching: find.byType(Scrollable),
      );
      expect(scrollableInCard, findsNothing);
    });

    testWidgets('Offline recall card is visually distinct from session history list', (WidgetTester tester) async {
      final alert = createAlert(id: 'crit_1', title: 'Critical Surge', severity: AlertSeverity.red);
      final sessions = [
        SessionHistoryEntry(id: 'sess_1', title: 'Shelter route', occurredAt: DateTime.now()),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ContextRecallCard(
                  key: const ValueKey('offline_last_known_alerts_card'),
                  alerts: [alert],
                  maxItems: 2,
                  isOffline: true,
                ),
                SessionHistoryList(sessions: sessions),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Card has crisis alert icon and warm styling
      expect(find.byIcon(Icons.crisis_alert_rounded), findsOneWidget);
      expect(find.text('1 OFFLINE'), findsOneWidget);

      // Session history uses numbered CircleAvatar; offline card does not
      expect(find.byType(CircleAvatar), findsOneWidget);
      final avatarInCard = find.descendant(
        of: find.byKey(const ValueKey('offline_last_known_alerts_card')),
        matching: find.byType(CircleAvatar),
      );
      expect(avatarInCard, findsNothing);
    });

    testWidgets('Home Screen does NOT render recall card to preserve map visible area', (WidgetTester tester) async {
      final alertProvider = AlertProvider();
      final alert = createAlert(id: 'crit_1', title: 'Critical Warning 1', severity: AlertSeverity.red);
      alertProvider.activeAlerts.add(alert);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AlertProvider>.value(value: alertProvider),
            ChangeNotifierProvider(create: (_) => IncidentProvider()),
            ChangeNotifierProvider(create: (_) => SafetyProvider()),
          ],
          child: const MaterialApp(
            home: HomeScreen(zones: []),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Home Screen should NOT have ContextRecallCard or offline card
      expect(find.byType(ContextRecallCard), findsNothing);
      expect(find.byKey(const ValueKey('offline_last_known_alerts_card')), findsNothing);
      expect(find.byKey(const ValueKey('context_recall_card')), findsNothing);
    });

    testWidgets('Incidents/Alerts screen displays last-known critical alerts when offline', (WidgetTester tester) async {
      final alertProvider = AlertProvider();
      final incidentProvider = IncidentProvider();

      final redAlert1 = createAlert(id: 'red_1', title: 'Severe Flash Flood Emergency', severity: AlertSeverity.red);
      final redAlert2 = createAlert(id: 'red_2', title: 'River Overflow Critical Alert', severity: AlertSeverity.red);
      final orangeAlert = createAlert(id: 'ora_1', title: 'Moderate Rain Warning', severity: AlertSeverity.orange);

      alertProvider.activeAlerts.addAll([redAlert1, redAlert2, orangeAlert]);
      alertProvider.setOffline(true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AlertProvider>.value(value: alertProvider),
            ChangeNotifierProvider<IncidentProvider>.value(value: incidentProvider),
          ],
          child: const MaterialApp(
            home: IncidentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final offlineCardFinder = find.byKey(const ValueKey('offline_last_known_alerts_card'));
      expect(offlineCardFinder, findsOneWidget);
      expect(find.text('Last-Known Alerts'), findsOneWidget);

      // The 2 critical red alerts are visible inside the offline card
      expect(
        find.descendant(of: offlineCardFinder, matching: find.text('Severe Flash Flood Emergency')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: offlineCardFinder, matching: find.text('River Overflow Critical Alert')),
        findsOneWidget,
      );

      // Non-critical alert is excluded from offline critical card
      expect(find.text('Moderate Rain Warning'), findsNothing);

      // Badge displays 2 OFFLINE
      expect(find.text('2 OFFLINE'), findsOneWidget);
    });

    testWidgets('Incidents/Alerts screen hides offline card when online', (WidgetTester tester) async {
      final alertProvider = AlertProvider();
      final incidentProvider = IncidentProvider();

      final redAlert = createAlert(id: 'red_1', title: 'Severe Flash Flood Emergency', severity: AlertSeverity.red);
      alertProvider.activeAlerts.add(redAlert);
      alertProvider.setOffline(false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AlertProvider>.value(value: alertProvider),
            ChangeNotifierProvider<IncidentProvider>.value(value: incidentProvider),
          ],
          child: const MaterialApp(
            home: IncidentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Offline card must NOT appear when online
      expect(find.byKey(const ValueKey('offline_last_known_alerts_card')), findsNothing);
    });
  });
}
