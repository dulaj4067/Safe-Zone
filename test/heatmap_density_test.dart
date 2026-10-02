import 'package:flutter_test/flutter_test.dart';
import 'package:safezone/models/incident.dart';
import 'package:safezone/widgets/heatmap_layer.dart';

Incident _at(
  double lat,
  double lng, {
  bool sos = false,
  IncidentStatus status = IncidentStatus.verified,
}) => Incident(
  id: '$lat,$lng',
  reporterId: 'r',
  category: IncidentCategory.waterlogging,
  latitude: lat,
  longitude: lng,
  status: status,
  credibilityScore: 0,
  isSos: sos,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('isolated reports in different towns stay cool, not max red', () {
    // Matara, Kalutara, Kandy — tens of km apart.
    final d = HeatmapLayer.densities([
      _at(5.956, 80.536),
      _at(6.585, 79.961),
      _at(7.251, 80.344),
    ]);
    for (final v in d) {
      expect(HeatmapLayer.intensity(v), lessThan(0.3));
    }
  });

  test('a tight cluster reads as a hotspot', () {
    final cluster = [
      for (var i = 0; i < 5; i++) _at(6.9556 + i * 0.001, 79.9222 + i * 0.001),
    ];
    final d = HeatmapLayer.densities(cluster);
    expect(HeatmapLayer.intensity(d[2]), greaterThan(0.9));
  });

  test('nearby reports reinforce each other across any grid boundary', () {
    // The two Kelaniya reports in the live data, ~2.4 km apart.
    final alone = HeatmapLayer.densities([_at(6.9556, 79.9222)]).single;
    final paired = HeatmapLayer.densities([
      _at(6.9556, 79.9222),
      _at(6.9615, 79.9010),
    ]).first;
    expect(paired, greaterThan(alone));
  });

  test('SOS weighs more than a routine report; pending a bit less', () {
    expect(
      HeatmapLayer.weightOf(_at(7, 80, sos: true)),
      greaterThan(HeatmapLayer.weightOf(_at(7, 80))),
    );
    expect(
      HeatmapLayer.weightOf(_at(7, 80, status: IncidentStatus.pending)),
      lessThan(HeatmapLayer.weightOf(_at(7, 80))),
    );
  });
}
