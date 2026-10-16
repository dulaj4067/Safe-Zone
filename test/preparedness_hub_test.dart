import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safezone/models/app_user.dart';
import 'package:safezone/modules/preparedness_hub/models/checklist_item.dart';
import 'package:safezone/modules/preparedness_hub/models/disaster_history_record.dart';
import 'package:safezone/modules/preparedness_hub/models/evacuation_route.dart';
import 'package:safezone/modules/preparedness_hub/models/preparedness_guide.dart';
import 'package:safezone/modules/preparedness_hub/models/preparedness_reminder.dart';
import 'package:safezone/modules/preparedness_hub/providers/preparedness_provider.dart';
import 'package:safezone/modules/preparedness_hub/screens/checklist_screen.dart';
import 'package:safezone/modules/preparedness_hub/services/preparedness_repository.dart';
import 'package:safezone/modules/preparedness_hub/services/disaster_history_samples.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'preparedness guides include starters and custom content persists locally',
    () async {
      final repository = LocalPreparednessRepository();
      expect(await repository.getGuides(), isNotEmpty);
      expect(await repository.getRoutes(), isEmpty);

      final guide = PreparednessGuide(
        id: 'guide-test',
        title: 'Flood readiness',
        category: GuideCategory.flood,
        bodyContent: 'Move documents to higher ground.',
        coverImageUrl: '',
        zoneTags: const ['zone-test'],
        createdBy: 'authority-test',
        createdAt: DateTime(2026, 9, 26),
        updatedAt: DateTime(2026, 9, 26),
        isArchived: false,
      );
      await repository.saveGuide(guide);
      await repository.archiveGuide(guide.id);

      final route = EvacuationRoute(
        id: 'route-test',
        zoneId: 'zone-test',
        startPoint: const LatLng(1, 1),
        safeZonePoint: const LatLng(2, 2),
        routePolyline: const [LatLng(1, 1), LatLng(2, 2)],
        instructions: const ['Follow the signed route.'],
        lastUpdated: DateTime(2026, 9, 26),
      );
      await repository.saveRoute(route);

      final reopenedRepository = LocalPreparednessRepository();
      final persistedGuide = (await reopenedRepository.getGuides()).firstWhere(
        (persisted) => persisted.id == guide.id,
      );
      expect(persistedGuide.title, 'Flood readiness');
      expect(persistedGuide.isArchived, isTrue);
      expect((await reopenedRepository.getRoutes()).single.id, route.id);
    },
  );

  test(
    'starter preparedness guides cover common disaster categories',
    () async {
      final guides = await LocalPreparednessRepository().getGuides();

      expect(
        guides.map((guide) => guide.category),
        containsAll([
          GuideCategory.flood,
          GuideCategory.fire,
          GuideCategory.earthquake,
          GuideCategory.landslide,
          GuideCategory.tsunami,
          GuideCategory.cyclone,
        ]),
      );
      expect(guides.every((guide) => guide.zoneTags.isEmpty), isTrue);
      expect(
        guides
            .firstWhere((guide) => guide.category == GuideCategory.fire)
            .bodyContent,
        contains('Never re-enter a burning building.'),
      );
    },
  );

  test('disaster history records persist and are filtered by zone', () async {
    final repository = LocalPreparednessRepository();
    final flood = DisasterHistoryRecord(
      id: 'history-flood-test',
      zoneId: 'zone-test',
      disasterType: 'Flood',
      date: DateTime(2025, 5, 10),
      severity: 'high',
      summary: 'The river overflowed after heavy rain.',
      sourceEventId: 'EMDAT-flood-test',
    );
    final storm = DisasterHistoryRecord(
      id: 'history-storm-test',
      zoneId: 'zone-other',
      disasterType: 'Storm',
      date: DateTime(2024, 11, 2),
      severity: 'moderate',
      summary: 'Strong winds damaged several roofs.',
    );
    final national = DisasterHistoryRecord(
      id: 'history-national-test',
      zoneId: null,
      disasterType: 'Drought',
      date: DateTime(2019, 1),
      datePrecision: DisasterDatePrecision.month,
      severity: null,
      summary: '',
      locationDescription: 'Several provinces',
      sourceEventId: '2019-9389-LKA',
      sourceName: 'EM-DAT, CRED / UCLouvain',
      totalAffected: 12000,
    );
    final secondDistrictCopy = DisasterHistoryRecord(
      id: 'history-flood-zone-copy',
      zoneId: 'zone-other',
      disasterType: flood.disasterType,
      date: flood.date,
      severity: flood.severity,
      summary: flood.summary,
      sourceEventId: flood.sourceEventId,
    );

    await repository.saveHistoryRecord(flood);
    await repository.saveHistoryRecord(storm);
    await repository.saveHistoryRecord(national);
    await repository.saveHistoryRecord(secondDistrictCopy);

    final reopenedRepository = LocalPreparednessRepository();
    final zoneHistory = await reopenedRepository.getHistory('zone-test');
    final zoneSampleRecords = zoneHistory.where((record) => record.isSample);
    expect(
      zoneHistory.map((record) => record.id),
      containsAll([flood.id, national.id]),
    );
    expect(zoneSampleRecords, hasLength(3));
    expect(zoneHistory, hasLength(5));
    expect(
      (await reopenedRepository.getHistory(
        'zone-other',
      )).map((record) => record.id),
      containsAll([
        storm.id,
        national.id,
        secondDistrictCopy.id,
        ...disasterHistorySamples.map((record) => record.id),
      ]),
    );
    expect(
      (await reopenedRepository.getHistory(
        'unknown-zone',
      )).where((record) => !record.isSample).single.id,
      national.id,
    );
    final countryHistory = await reopenedRepository.getCountryHistory();
    expect(countryHistory, hasLength(6));
    expect(countryHistory.where((record) => record.isSample), hasLength(3));
    expect(
      countryHistory.where(
        (record) => record.sourceEventId == flood.sourceEventId,
      ),
      hasLength(1),
    );
    final restoredNational = countryHistory.singleWhere(
      (record) => record.id == national.id,
    );
    expect(restoredNational.datePrecision, DisasterDatePrecision.month);
    expect(restoredNational.toJson()['date'], '2019-01');
    expect(restoredNational.severity, isNull);
    expect(restoredNational.sourceEventId, national.sourceEventId);
    expect(restoredNational.totalAffected, 12000);
  });

  test(
    'fictional disaster samples are never written to Supabase content',
    () async {
      final repository = LocalPreparednessRepository();
      final sample = (await repository.getCountryHistory()).firstWhere(
        (record) => record.isSample,
      );

      await expectLater(repository.saveHistoryRecord(sample), throwsStateError);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('preparedness.history.v1'), isNull);
    },
  );

  test('personalized checklist matches household risk factors', () async {
    final repository = LocalPreparednessRepository();
    for (final item in [
      const ChecklistItem(
        id: 'check-flood',
        title: 'Flood-safe locations',
        description: '',
        riskFactorTags: ['riverside'],
      ),
      const ChecklistItem(
        id: 'check-support',
        title: 'Household support needs',
        description: '',
        riskFactorTags: ['elderly-household'],
      ),
      const ChecklistItem(
        id: 'check-vehicle',
        title: 'No-vehicle evacuation plan',
        description: '',
        riskFactorTags: ['no-vehicle'],
      ),
    ]) {
      await repository.saveChecklistItem(item);
    }
    final checklist = await repository.generateChecklistForProfile({
      'locationType': 'riverside',
      'householdSize': '5',
      'hasElderlyMember': true,
      'hasDisabledMember': true,
      'hasVehicle': false,
    });

    expect(checklist, isNotEmpty);
    expect(
      checklist.any((item) => item.riskFactorTags.contains('riverside')),
      isTrue,
    );
    expect(
      checklist.any(
        (item) => item.riskFactorTags.contains('elderly-household'),
      ),
      isTrue,
    );
    expect(
      checklist.any((item) => item.riskFactorTags.contains('no-vehicle')),
      isTrue,
    );
  });

  test(
    'checklist generation accepts dropdown values from a saved profile',
    () async {
      final repository = LocalPreparednessRepository();
      await repository.saveChecklistItem(
        const ChecklistItem(
          id: 'check-elderly-saved-profile',
          title: 'Plan support for older household members',
          description: '',
          riskFactorTags: ['elderly-household'],
        ),
      );
      await repository.saveChecklistItem(
        const ChecklistItem(
          id: 'check-disabled-saved-profile',
          title: 'Plan support for household members with disabilities',
          description: '',
          riskFactorTags: ['disabled-household'],
        ),
      );

      final checklist = await repository.generateChecklistForProfile({
        'locationType': 'hillside',
        'householdSize': '1-2',
        'hasElderlyMember': 'yes',
        'hasDisabledMember': 'yes',
        'hasVehicle': true,
      });

      expect(
        checklist.map((item) => item.id),
        containsAll([
          'check-elderly-saved-profile',
          'check-disabled-saved-profile',
        ]),
      );
    },
  );

  test('starter checklist generates for a general household profile', () async {
    final repository = LocalPreparednessRepository();

    final checklist = await repository.generateChecklistForProfile({
      'locationType': 'urban',
      'householdSize': '3-4',
      'hasElderlyMember': false,
      'hasDisabledMember': false,
      'hasVehicle': true,
    });

    expect(checklist, isNotEmpty);
    expect(
      checklist.any(
        (item) => item.id == 'starter-checklist-emergency-contacts',
      ),
      isTrue,
    );
    expect(
      checklist.any((item) => item.id == 'starter-checklist-flood-route'),
      isFalse,
    );
  });

  test('starter checklist generates for hillside support needs', () async {
    final repository = LocalPreparednessRepository();

    final checklist = await repository.generateChecklistForProfile({
      'locationType': 'hillside',
      'householdSize': '1-2',
      'hasElderlyMember': 'yes',
      'hasDisabledMember': 'yes',
      'hasVehicle': true,
    });
    final ids = checklist.map((item) => item.id);

    expect(ids, contains('starter-checklist-emergency-contacts'));
    expect(ids, contains('starter-checklist-household-support'));
    expect(ids, isNot(contains('starter-checklist-flood-route')));
    expect(ids, isNot(contains('starter-checklist-no-vehicle-transport')));
  });

  testWidgets('checklist generates automatically after profile dropdowns', (
    tester,
  ) async {
    final repository = LocalPreparednessRepository();
    await repository.saveChecklistItem(
      const ChecklistItem(
        id: 'check-riverside',
        title: 'Riverside flood plan',
        description: 'Identify higher ground.',
        riskFactorTags: ['riverside'],
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PreparednessProvider(repository: repository),
        child: MaterialApp(
          home: ChecklistScreen(
            currentUser: AppUser(
              id: 'user-test',
              fullName: 'Test User',
              phone: '',
              role: UserRole.member,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> selectStringDropdown(int index, String value) async {
      final field = find.byType(DropdownButtonFormField<String>).at(index);
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last);
      await tester.pumpAndSettle();
    }

    await selectStringDropdown(0, 'Riverside / flood plain');
    await selectStringDropdown(1, '3-4 people');
    await selectStringDropdown(2, 'No');
    await selectStringDropdown(3, 'No');

    final vehicleField = find.byType(DropdownButtonFormField<bool>);
    await tester.ensureVisible(vehicleField);
    await tester.tap(vehicleField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('No').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Riverside flood plan'), findsOneWidget);
  });

  test('zone-targeted reminders are filtered for the member zone', () async {
    final repository = LocalPreparednessRepository();
    expect(await repository.getReminders(), isEmpty);
    for (final reminder in [
      PreparednessReminder(
        id: 'reminder-zone',
        title: 'Zone drill',
        message: 'Practice the evacuation route.',
        scheduledDate: DateTime(2026, 10, 15),
        recurrence: ReminderRecurrence.monthly,
        zoneTags: const ['zone-test'],
      ),
      PreparednessReminder(
        id: 'reminder-other-zone',
        title: 'Other zone drill',
        message: 'Practice the evacuation route.',
        scheduledDate: DateTime(2026, 10, 20),
        recurrence: ReminderRecurrence.none,
        zoneTags: const ['zone-other'],
      ),
    ]) {
      await repository.saveReminder(reminder);
    }
    final reminders = await repository.getReminders();

    final zoneReminders = repository.remindersForZone(reminders, 'zone-test');
    expect(zoneReminders, hasLength(1));
    expect(
      zoneReminders.every(
        (reminder) =>
            reminder.zoneTags.isEmpty ||
            reminder.zoneTags.contains('zone-test'),
      ),
      isTrue,
    );
  });
}
