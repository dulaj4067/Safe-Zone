import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focus_app/models/incident.dart';
import 'package:focus_app/providers/incident_provider.dart';
import 'package:focus_app/screens/edit_incident_screen.dart';

void main() {
  group('Incident Model - Citizen Edit & Serialization', () {
    test('copyWith properly copies and updates fields', () {
      final original = Incident(
        id: 'test-123',
        reporterId: 'user-456',
        category: IncidentCategory.waterlogging,
        description: 'Road flooded 2 feet deep',
        latitude: 6.9271,
        longitude: 79.8612,
        status: IncidentStatus.pending,
        credibilityScore: 2,
        isSos: false,
        createdAt: DateTime(2026, 8, 26, 10, 0),
        updatedAt: DateTime(2026, 8, 26, 10, 0),
      );

      final updated = original.copyWith(
        description: 'Water has completely receded',
        status: IncidentStatus.resolved,
      );

      expect(updated.id, 'test-123');
      expect(updated.reporterId, 'user-456');
      expect(updated.description, 'Water has completely receded');
      expect(updated.status, IncidentStatus.resolved);
      expect(updated.category, IncidentCategory.waterlogging);
    });

    test('toUpdateMap generates valid payload with PostGIS EWKT', () {
      final incident = Incident(
        id: 'test-123',
        reporterId: 'user-456',
        category: IncidentCategory.blockedRoad,
        description: 'Fallen tree cleared from road',
        latitude: 6.9271,
        longitude: 79.8612,
        status: IncidentStatus.resolved,
        credibilityScore: 3,
        isSos: false,
        createdAt: DateTime(2026, 8, 26, 10, 0),
        updatedAt: DateTime(2026, 8, 26, 10, 0),
      );

      final map = incident.toUpdateMap();
      expect(map['category'], 'blocked_road');
      expect(map['description'], 'Fallen tree cleared from road');
      expect(map['status'], 'resolved');
      expect(map['location'], 'SRID=4326;POINT(79.8612 6.9271)');
      expect(map['is_sos'], false);
      expect(map['updated_at'], isNotNull);
    });
  });

  group('IncidentProvider Filter Logic', () {
    test('Filter toggling works correctly', () {
      final provider = IncidentProvider();
      expect(provider.myReportsFilter, isFalse);
      expect(provider.statusFilter, isNull);

      provider.setMyReportsFilter(true);
      expect(provider.myReportsFilter, isTrue);

      provider.setStatusFilter(IncidentStatus.resolved);
      expect(provider.statusFilter, IncidentStatus.resolved);

      provider.clearFilters();
      expect(provider.myReportsFilter, isFalse);
      expect(provider.statusFilter, isNull);
    });
  });

  group('EditIncidentScreen Widget Test', () {
    testWidgets('Renders EditIncidentScreen with existing incident values', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final incident = Incident(
        id: 'inc-999',
        reporterId: 'user-111',
        category: IncidentCategory.waterlogging,
        description: 'Rising water near Main Street bridge',
        latitude: 6.9615,
        longitude: 79.9010,
        status: IncidentStatus.pending,
        credibilityScore: 1,
        isSos: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => IncidentProvider()),
          ],
          child: MaterialApp(
            home: EditIncidentScreen(incident: incident),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header, description, and delete button
      expect(find.text('Edit Incident Report'), findsOneWidget);
      expect(find.text('Rising water near Main Street bridge'), findsOneWidget);
      expect(find.text('Incident Status'), findsOneWidget);
      expect(find.text('Mark as Resolved'), findsOneWidget);
      expect(find.text('SAVE INCIDENT CHANGES'), findsOneWidget);
      expect(find.text('Delete Incident Report'), findsOneWidget);
    });
  });
}
