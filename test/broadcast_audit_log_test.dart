import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safezone/models/alert.dart';
import 'package:safezone/models/broadcast_audit_entry.dart';
import 'package:safezone/screens/broadcast_audit_log_screen.dart';
import 'package:safezone/services/broadcast_audit_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Broadcast Audit Log - Service Unit Tests', () {
    test('Logs creation, dispatch, resolution, and archival actions to SharedPreferences',
        () async {
      final service = BroadcastAuditService();

      final log1 = await service.logAction(
        alertId: 'alert-1',
        alertTitle: 'Severe Flood Warning',
        action: BroadcastAuditAction.created,
        severity: AlertSeverity.red,
        zoneName: 'Kelani Basin',
      );

      final log2 = await service.logAction(
        alertId: 'alert-1',
        alertTitle: 'Severe Flood Warning',
        action: BroadcastAuditAction.dispatched,
        details: 'Dispatched across Push Notification, SMS Broadcast, Siren Trigger',
        severity: AlertSeverity.red,
        zoneName: 'Kelani Basin',
      );

      expect(log1.alertId, equals('alert-1'));
      expect(log2.action, equals(BroadcastAuditAction.dispatched));

      final allLogs = await service.getAuditLogs();
      expect(allLogs.length, equals(2));
      expect(allLogs.first.action, equals(BroadcastAuditAction.dispatched));
      expect(allLogs.last.action, equals(BroadcastAuditAction.created));
    });

    test('Filters logs by BroadcastAuditAction', () async {
      final service = BroadcastAuditService();

      await service.logAction(
        alertId: 'alert-1',
        alertTitle: 'Flood Warning',
        action: BroadcastAuditAction.created,
      );
      await service.logAction(
        alertId: 'alert-2',
        alertTitle: 'Landslide Warning',
        action: BroadcastAuditAction.resolved,
      );

      final createdLogs =
          await service.getLogsByAction(BroadcastAuditAction.created);
      final resolvedLogs =
          await service.getLogsByAction(BroadcastAuditAction.resolved);

      expect(createdLogs.length, equals(1));
      expect(createdLogs.first.alertTitle, equals('Flood Warning'));

      expect(resolvedLogs.length, equals(1));
      expect(resolvedLogs.first.alertTitle, equals('Landslide Warning'));
    });

    test('Clears all recorded audit logs', () async {
      final service = BroadcastAuditService();

      await service.logAction(
        alertId: 'alert-1',
        alertTitle: 'Cyclone Warning',
        action: BroadcastAuditAction.created,
      );
      expect((await service.getAuditLogs()).length, equals(1));

      await service.clearAuditLogs();
      expect((await service.getAuditLogs()).length, equals(0));
    });
  });

  group('Broadcast Audit Log - Screen Widget Tests', () {
    testWidgets('Renders BroadcastAuditLogScreen with recorded audit entries and badges',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = BroadcastAuditService();
      await service.logAction(
        alertId: 'alert-101',
        alertTitle: 'Critical River Surge Warning',
        action: BroadcastAuditAction.dispatched,
        details: 'Dispatched across Push Notification, SMS Broadcast',
        severity: AlertSeverity.red,
        zoneName: 'Kelani Basin Zone',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BroadcastAuditLogScreen(auditService: service),
        ),
      );

      await tester.pumpAndSettle();

      // Verify screen title and audit content
      expect(find.text('Broadcast Audit Log'), findsOneWidget);
      expect(find.text('Critical River Surge Warning'), findsOneWidget);
      expect(find.text('DISPATCHED'), findsOneWidget);
      expect(find.text('Dispatched across Push Notification, SMS Broadcast'), findsOneWidget);
      expect(find.text('By Authority Admin'), findsOneWidget);
      expect(find.text('Kelani Basin Zone'), findsOneWidget);
    });

    testWidgets('Filters audit items using action ChoiceChips',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = BroadcastAuditService();
      await service.logAction(
        alertId: 'alert-1',
        alertTitle: 'Flood Alert Alpha',
        action: BroadcastAuditAction.created,
      );
      await service.logAction(
        alertId: 'alert-2',
        alertTitle: 'Landslide Alert Beta',
        action: BroadcastAuditAction.resolved,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BroadcastAuditLogScreen(auditService: service),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Flood Alert Alpha'), findsOneWidget);
      expect(find.text('Landslide Alert Beta'), findsOneWidget);

      // Tap 'Resolved' filter chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Resolved'));
      await tester.pumpAndSettle();

      expect(find.text('Landslide Alert Beta'), findsOneWidget);
      expect(find.text('Flood Alert Alpha'), findsNothing);
    });
  });
}
