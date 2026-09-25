import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safezone/services/activity_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resume tracker caps at 4 entries and dedupes by ref', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = ActivityHistoryService(preferences: prefs);

    for (var i = 0; i < 5; i++) {
      await service.record(
        id: 'route-${i + 1}',
        title: 'Draft ${i + 1}',
        section: 'Shelters',
        type: ResumeItemType.route,
        subtitle: 'Route in progress',
        routeOrDraftRef: 'route-${i + 1}',
      );
    }

    await service.record(
      id: 'route-3',
      title: 'Draft 3 updated',
      section: 'Shelters',
      type: ResumeItemType.route,
      subtitle: 'Updated route',
      routeOrDraftRef: 'route-3',
    );

    expect(service.entries.length, 4);
    expect(service.entries.map((e) => e.id).contains('route-3'), isTrue);
    expect(service.entries.map((e) => e.id).contains('route-1'), isFalse);
    expect(service.entries.first.title, 'Draft 3 updated');
  });

  test('resume tracker persists and marks interruptions locally', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = ActivityHistoryService(preferences: prefs);

    await service.record(
      id: 'hazard-204',
      title: 'Hazard report #204 — photo pending',
      section: 'Home',
      type: ResumeItemType.report,
      subtitle: 'Draft in progress',
      routeOrDraftRef: 'hazard-204',
    );

    await service.markInterrupted();

    expect(service.entries.first.interrupted, isTrue);
    final raw = prefs.getStringList('safezone_local_activity_history');
    expect(raw, isNotNull);
    expect(jsonDecode(raw!.first)['interrupted'], isTrue);
  });
}
