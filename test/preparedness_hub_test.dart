import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safezone/modules/preparedness_hub/services/preparedness_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('guides and evacuation routes persist in the local cache', () async {
    final repository = LocalPreparednessRepository();
    final guides = await repository.getGuides();
    expect(guides, isNotEmpty);

    final updated = guides.first.copyWith(
      title: 'Updated flood guide',
      updatedAt: DateTime(2026, 9, 26),
    );
    await repository.saveGuide(updated);
    await repository.archiveGuide(updated.id);

    final reopenedRepository = LocalPreparednessRepository();
    final persistedGuide = (await reopenedRepository.getGuides()).firstWhere(
      (guide) => guide.id == updated.id,
    );
    expect(persistedGuide.title, 'Updated flood guide');
    expect(persistedGuide.isArchived, isTrue);
    expect(await reopenedRepository.getRoutes(), isNotEmpty);
  });

  test('personalized checklist matches household risk factors', () async {
    final repository = LocalPreparednessRepository();
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
    final reminders = await repository.getReminders();

    final zoneReminders = repository.remindersForZone(reminders, 'zone-demo');
    expect(zoneReminders, isNotEmpty);
    expect(
      zoneReminders.every(
        (reminder) =>
            reminder.zoneTags.isEmpty ||
            reminder.zoneTags.contains('zone-demo'),
      ),
      isTrue,
    );
  });
}
