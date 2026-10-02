import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safezone/modules/preparedness_hub/models/checklist_item.dart';
import 'package:safezone/modules/preparedness_hub/models/evacuation_route.dart';
import 'package:safezone/modules/preparedness_hub/models/preparedness_guide.dart';
import 'package:safezone/modules/preparedness_hub/models/preparedness_reminder.dart';
import 'package:safezone/modules/preparedness_hub/services/preparedness_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'preparedness content starts empty and persists in the local cache',
    () async {
      final repository = LocalPreparednessRepository();
      expect(await repository.getGuides(), isEmpty);
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
