import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safezone/models/alert.dart';
import 'package:safezone/models/alert_engagement.dart';
import 'package:safezone/models/zone.dart';
import 'package:safezone/providers/alert_provider.dart';
import 'package:safezone/screens/broadcast_dashboard_screen.dart';
import 'package:safezone/services/alert_engagement_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ZoneAlertEngagement Model - Calculations & Thresholds', () {
    test('Calculates seen and acknowledged percentages accurately', () {
      const engagement = ZoneAlertEngagement(
        alertId: 'alert-1',
        zoneId: 'zone-kelani',
        zoneName: 'Kelani Basin Zone',
        totalResidents: 20,
        seenCount: 16,
        acknowledgedCount: 12,
      );

      expect(engagement.seenPercentage, 80.0);
      expect(engagement.acknowledgedPercentage, 60.0);
      expect(engagement.unreachedCount, 4);
      expect(engagement.unreachedPercentage, 20.0);
    });

    test('Handles 0 total residents gracefully without dividing by zero', () {
      const engagement = ZoneAlertEngagement(
        alertId: 'alert-2',
        zoneName: 'Empty Zone',
        totalResidents: 0,
        seenCount: 0,
        acknowledgedCount: 0,
      );

      expect(engagement.seenPercentage, 0.0);
      expect(engagement.acknowledgedPercentage, 0.0);
      expect(engagement.unreachedCount, 0);
      expect(engagement.needsFurtherAction, isFalse);
      expect(engagement.urgency, EngagementUrgency.optimal);
    });

    test('Detects when further action is needed (acknowledged < 50% or seen < 60%)', () {
      const lowAck = ZoneAlertEngagement(
        alertId: 'alert-3',
        zoneName: 'Zone A',
        totalResidents: 10,
        seenCount: 7, // 70% seen
        acknowledgedCount: 4, // 40% ack (< 50%)
      );
      expect(lowAck.needsFurtherAction, isTrue);
      expect(lowAck.urgency, EngagementUrgency.warning);
      expect(lowAck.actionRecommendation, contains('Moderate reach'));

      const criticalAck = ZoneAlertEngagement(
        alertId: 'alert-4',
        zoneName: 'Zone B',
        totalResidents: 10,
        seenCount: 3, // 30% seen (< 50%)
        acknowledgedCount: 2, // 20% ack (< 40%)
      );
      expect(criticalAck.needsFurtherAction, isTrue);
      expect(criticalAck.urgency, EngagementUrgency.critical);
      expect(criticalAck.actionRecommendation, contains('Critical'));
      expect(criticalAck.actionRecommendation, contains('Further action needed'));

      const highReach = ZoneAlertEngagement(
        alertId: 'alert-5',
        zoneName: 'Zone C',
        totalResidents: 10,
        seenCount: 9, // 90% seen
        acknowledgedCount: 8, // 80% ack
      );
      expect(highReach.needsFurtherAction, isFalse);
      expect(highReach.urgency, EngagementUrgency.optimal);
      expect(highReach.actionRecommendation, contains('Optimal response'));
    });
  });

  group('AlertEngagementService - Tracking & Simulation', () {
    test('Records seen and acknowledged receipts in SharedPreferences', () async {
      final service = AlertEngagementService();
      const alertId = 'test-alert-99';
      const userId1 = 'user-abc';
      const userId2 = 'user-xyz';

      expect(await service.hasUserSeen(alertId, userId1), isFalse);
      expect(await service.hasUserAcknowledged(alertId, userId1), isFalse);

      await service.markSeen(alertId, userId1);
      expect(await service.hasUserSeen(alertId, userId1), isTrue);
      expect(await service.hasUserAcknowledged(alertId, userId1), isFalse);

      await service.markAcknowledged(alertId, userId2);
      expect(await service.hasUserSeen(alertId, userId2), isTrue);
      expect(await service.hasUserAcknowledged(alertId, userId2), isTrue);
    });

    test('Simulates response rates accurately for authority testing', () async {
      final service = AlertEngagementService();
      const alertId = 'test-alert-sim';

      await service.simulateEngagement(
        alertId,
        'zone-1',
        ackRate: 0.8,
        seenRate: 0.9,
      );

      final engagement = await service.getZoneEngagement(
        alertId,
        zoneId: 'zone-1',
        zoneName: 'Test Zone 1',
      );

      expect(engagement.totalResidents, greaterThan(0));
      expect(engagement.acknowledgedPercentage, closeTo(80.0, 1.0));
      expect(engagement.seenPercentage, closeTo(90.0, 1.0));
      expect(engagement.needsFurtherAction, isFalse);
    });
  });

  group('BroadcastDashboardScreen - Engagement Widget Tests', () {
    testWidgets('Renders resident seen and acknowledged percentages in dashboard card',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final alert = DisasterAlert(
        id: 'alert-live-1',
        title: 'Severe Flood Warning',
        alertType: 'flood',
        severity: AlertSeverity.red,
        status: AlertStatus.active,
        affectedZoneId: 'zone-kelani',
        centerLat: 6.95,
        centerLng: 79.91,
        radiusMeters: 3000,
        instructions: 'Evacuate low lying areas immediately.',
        source: 'manual',
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      );

      final zone = Zone(
        id: 'zone-kelani',
        name: 'Kelani Basin Zone',
        centroidLat: 6.95,
        centroidLng: 79.91,
      );

      final provider = AlertProvider();
      // Simulate low acknowledgment (e.g. 20% ack, 40% seen)
      await provider.simulateZoneEngagement(
        alert.id,
        zone.id,
        ackRate: 0.2,
        seenRate: 0.4,
      );

      // Add alert directly to provider's active list
      provider.activeAlerts.add(alert);

      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: provider,
          child: MaterialApp(
            home: BroadcastDashboardScreen(zones: [zone]),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify dashboard elements
      expect(find.text('Broadcast Dashboard'), findsOneWidget);
      expect(find.text('Severe Flood Warning'), findsOneWidget);
      expect(find.text('Kelani Basin Zone'), findsOneWidget);
      expect(find.text('Acknowledged'), findsOneWidget);
      expect(find.text('Seen / Opened'), findsOneWidget);
      expect(find.text('FURTHER ACTION NEEDED'), findsOneWidget);
      expect(find.text('Resident Breakdown'), findsOneWidget);
    });
  });
}
