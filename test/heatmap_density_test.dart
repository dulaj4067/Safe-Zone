import 'package:flutter_test/flutter_test.dart';
import 'package:safezone/models/incident.dart';
import 'package:safezone/widgets/heatmap_layer.dart';

Incident _at(
  double lat,
  double lng, {
  bool sos = false,
  IncidentStatus status = IncidentStatus.verified,
  int confirmations = 0,
}) => Incident(
  id: '$lat,$lng',
  reporterId: 'r',
  category: IncidentCategory.waterlogging,
  latitude: lat,
  longitude: lng,
  status: status,
  credibilityScore: confirmations,
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

  test('a lone report is green, a few are orange, a big cluster is red', () {
    List<Incident> cluster(int n) => [
      for (var i = 0; i < n; i++) _at(6.9556 + i * 0.0004, 79.9222 + i * 0.0004),
    ];
    double peak(int n) =>
        HeatmapLayer.densities(cluster(n)).map(HeatmapLayer.intensity).reduce((a, b) => a > b ? a : b);

    expect(peak(1), lessThan(0.15), reason: 'lone report stays green');
    expect(peak(5), inInclusiveRange(0.3, 0.7), reason: 'a handful is mid-scale');
    expect(peak(14), greaterThan(0.9), reason: 'a dozen-plus is red');
    expect(peak(5), greaterThan(peak(1)));
    expect(peak(14), greaterThan(peak(5)));
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

  test('SOS weighs more than a routine report', () {
    expect(
      HeatmapLayer.weightOf(_at(7, 80, sos: true)),
      greaterThan(HeatmapLayer.weightOf(_at(7, 80))),
    );
  });

  group('only confirmed reports heat the map', () {
    double w(IncidentStatus status, [int confirmations = 0]) =>
        HeatmapLayer.weightOf(_at(7, 80, status: status, confirmations: confirmations));

    test('an unconfirmed pending report is barely there', () {
      expect(w(IncidentStatus.pending), lessThanOrEqualTo(0.25));
      expect(w(IncidentStatus.pending), lessThan(w(IncidentStatus.verified)));
    });

    test('community confirmations lift a pending report up to a verified one', () {
      expect(w(IncidentStatus.pending, 2), greaterThan(w(IncidentStatus.pending, 0)));
      expect(w(IncidentStatus.pending, 4), w(IncidentStatus.verified));
      // ...and cap there, however many pile on.
      expect(w(IncidentStatus.pending, 9), w(IncidentStatus.verified));
    });

    test('community confirmations also strengthen a verified report, to a cap', () {
      expect(w(IncidentStatus.verified, 3), greaterThan(w(IncidentStatus.verified)));
      expect(w(IncidentStatus.verified, 50), w(IncidentStatus.verified, 5));
    });

    test('rejected and resolved reports add no heat', () {
      expect(w(IncidentStatus.rejected, 4), 0);
      expect(w(IncidentStatus.resolved, 4), 0);
    });

    test('a pile of unconfirmed reports stays cooler than a few confirmed ones', () {
      double peak(List<Incident> list) =>
          HeatmapLayer.densities(list).reduce((a, b) => a > b ? a : b);
      final unconfirmed = [
        for (var i = 0; i < 6; i++)
          _at(6.9556 + i * 0.0004, 79.9222, status: IncidentStatus.pending),
      ];
      final confirmed = [
        for (var i = 0; i < 6; i++)
          _at(6.9556 + i * 0.0004, 79.9222, status: IncidentStatus.pending, confirmations: 3),
      ];
      expect(peak(unconfirmed), lessThan(2.5));
      expect(peak(confirmed), greaterThan(peak(unconfirmed) * 2));
    });
  });
}
