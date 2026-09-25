import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safezone/models/alert.dart';
import 'package:safezone/providers/alert_provider.dart';
import 'package:safezone/widgets/alert_banner.dart';
import 'package:safezone/widgets/context_recall_card.dart';
import 'package:safezone/widgets/session_history_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DisasterAlert createAlert({
    required String id,
    required String title,
    AlertSeverity severity = AlertSeverity.orange,
    String? instructions,
  }) {
    final now = DateTime.now();
    return DisasterAlert(
      id: id,
      title: title,
      instructions: instructions ?? 'Stay indoors and follow safety instructions.',
      severity: severity,
      status: AlertStatus.active,
      alertType: 'flood',
      centerLat: 6.9271,
      centerLng: 79.8612,
      radiusMeters: 2000,
      source: 'official',
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Context Recall – One-Tap Acknowledgment Tests', () {
    testWidgets('Citizen can acknowledge an alert with one tap', (WidgetTester tester) async {
      final alertProvider = AlertProvider();
      final alert = createAlert(id: 'alert_1', title: 'Severe Flash Flood Warning');

      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: alertProvider,
          child: MaterialApp(
            home: Scaffold(
              body: ContextRecallCard(
                alerts: [alert],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure Context Recall card and title are present
      expect(find.text('Context Recall'), findsOneWidget);
      expect(find.text('Severe Flash Flood Warning'), findsOneWidget);

      // Verify the one-tap Acknowledge button is visible
      final ackButtonFinder = find.byKey(const ValueKey('ack_btn_alert_1'));
      expect(ackButtonFinder, findsOneWidget);
      expect(find.text('Acknowledge'), findsOneWidget);

      // Single tap to acknowledge
      await tester.tap(ackButtonFinder);
      await tester.pumpAndSettle();

      // State updates immediately to Acknowledged
      expect(find.byKey(const ValueKey('ack_done_alert_1')), findsOneWidget);
      expect(find.text('Acknowledged'), findsOneWidget);
      expect(find.byKey(const ValueKey('ack_btn_alert_1')), findsNothing);

      // Verify provider has recorded the acknowledgment
      expect(alertProvider.isAlertAcknowledged('alert_1'), isTrue);
    });

    testWidgets('Context Recall card has a hard maximum of 4 items', (WidgetTester tester) async {
      final alertProvider = AlertProvider();
      final alerts = List.generate(
        7,
        (i) => createAlert(
          id: 'alert_$i',
          title: 'Emergency Warning Level $i',
          severity: i % 2 == 0 ? AlertSeverity.red : AlertSeverity.orange,
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: alertProvider,
          child: MaterialApp(
            home: Scaffold(
              body: ContextRecallCard(
                alerts: alerts,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // First 4 items should be rendered
      expect(find.text('Emergency Warning Level 0'), findsOneWidget);
      expect(find.text('Emergency Warning Level 1'), findsOneWidget);
      expect(find.text('Emergency Warning Level 2'), findsOneWidget);
      expect(find.text('Emergency Warning Level 3'), findsOneWidget);

      // Items beyond index 3 (items 4, 5, 6) must NOT be rendered
      expect(find.text('Emergency Warning Level 4'), findsNothing);
      expect(find.text('Emergency Warning Level 5'), findsNothing);
      expect(find.text('Emergency Warning Level 6'), findsNothing);

      // Badge displays hard limit count
      expect(find.text('4 ACTIVE'), findsOneWidget);
    });

    testWidgets('No scrolling inside the recall card', (WidgetTester tester) async {
      final alertProvider = AlertProvider();
      final alerts = List.generate(
        4,
        (i) => createAlert(id: 'alert_$i', title: 'Warning $i'),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: alertProvider,
          child: MaterialApp(
            home: Scaffold(
              body: ContextRecallCard(
                alerts: alerts,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final recallCardFinder = find.byKey(const ValueKey('context_recall_card'));
      expect(recallCardFinder, findsOneWidget);

      // Assert that there is NO Scrollable widget inside ContextRecallCard
      final scrollableInsideCard = find.descendant(
        of: recallCardFinder,
        matching: find.byType(Scrollable),
      );
      expect(scrollableInsideCard, findsNothing);
    });

    testWidgets('Recall card is visually distinct from the session history list', (WidgetTester tester) async {
      final alertProvider = AlertProvider();
      final alert = createAlert(id: 'a1', title: 'Cyclone Red Alert', severity: AlertSeverity.red);

      final sessionEntries = [
        SessionHistoryEntry(
          id: 's1',
          title: 'Route check-in',
          occurredAt: DateTime(2024, 1, 10, 8, 30),
        ),
      ];

      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: alertProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ContextRecallCard(alerts: [alert]),
                  SessionHistoryList(sessions: sessionEntries),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Context Recall card visual distinctions
      expect(find.text('Context Recall'), findsOneWidget);
      expect(find.byIcon(Icons.crisis_alert_rounded), findsOneWidget);
      expect(find.text('1 ACTIVE'), findsOneWidget);

      // Session history elements
      expect(find.text('Session history'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);

      // Session history uses numbered CircleAvatar, Context Recall does not
      expect(find.byType(CircleAvatar), findsOneWidget); // only from SessionHistoryList
      final circleAvatarInRecall = find.descendant(
        of: find.byKey(const ValueKey('context_recall_card')),
        matching: find.byType(CircleAvatar),
      );
      expect(circleAvatarInRecall, findsNothing);

      // Context Recall has one-tap Acknowledge button, Session history does not
      expect(find.byKey(const ValueKey('ack_btn_a1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SessionHistoryList),
          matching: find.text('Acknowledge'),
        ),
        findsNothing,
      );
    });

    testWidgets('AlertBanner exposes a direct one-tap acknowledgment button', (WidgetTester tester) async {
      final alertProvider = AlertProvider();
      final alert = createAlert(id: 'banner_alert', title: 'Severe Storm Alert', severity: AlertSeverity.red);

      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: alertProvider,
          child: MaterialApp(
            home: Scaffold(
              body: AlertBanner(
                alert: alert,
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify one-tap button on banner
      final bannerAckButton = find.byKey(const ValueKey('banner_ack_banner_alert'));
      expect(bannerAckButton, findsOneWidget);
      expect(find.text('Acknowledge'), findsOneWidget);

      // Tap acknowledge with 1 tap directly on banner
      await tester.tap(bannerAckButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Status updates on banner
      expect(find.text('ACKNOWLEDGED'), findsOneWidget);
      expect(alertProvider.isAlertAcknowledged('banner_alert'), isTrue);
    });
  });
}
