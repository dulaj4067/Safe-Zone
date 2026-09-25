import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safezone/services/activity_history_service.dart';
import 'package:safezone/services/tile_cache_service.dart';

void main() {
  group('TileCachePolicy', () {
    test('removes stale entries and keeps newest entries within the bound', () {
      final now = DateTime(2026, 9, 23);
      final entries = List.generate(
        5,
        (index) => TileCacheEntry(
          key: 'tile-$index',
          lastAccessed: now.subtract(Duration(days: index)),
        ),
      );

      final kept = const TileCachePolicy(maxEntries: 2, stalePeriod: Duration(days: 3))
          .evict(entries, now: now);

      expect(kept.map((entry) => entry.key), ['tile-0', 'tile-1']);
    });
  });

  group('ActivityHistoryService', () {
    late ActivityHistoryService history;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      history = ActivityHistoryService(
        preferences: await SharedPreferences.getInstance(),
      );
      await history.load();
    });

    test('deduplicates and orders most recent activity first', () async {
      await history.record(id: 'incidents', title: 'Incidents', section: 'Incidents');
      await history.record(id: 'route', title: 'Route to safety', section: 'Shelters');
      await history.record(id: 'incidents', title: 'Incidents', section: 'Incidents');

      expect(history.entries.map((entry) => entry.id), ['incidents', 'route']);
    });

    test('caps history at four entries and marks interruption locally', () async {
      for (var i = 0; i < 6; i++) {
        await history.record(id: 'section-$i', title: 'Section $i', section: 'Section');
      }
      await history.markInterrupted();

      expect(history.entries, hasLength(4));
      expect(history.entries.first.id, 'section-5');
      expect(history.entries.first.interrupted, isTrue);
    });
  });
}
