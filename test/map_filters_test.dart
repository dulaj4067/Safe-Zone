import 'package:flutter_test/flutter_test.dart';
import 'package:safezone/models/alert.dart';
import 'package:safezone/models/incident.dart';
import 'package:safezone/models/shelter.dart';
import 'package:safezone/widgets/map_filter_sheet.dart';

DisasterAlert _alert(String id, AlertSeverity severity) => DisasterAlert(
  id: id,
  title: id,
  alertType: 'flood',
  severity: severity,
  status: AlertStatus.active,
  centerLat: 6.9,
  centerLng: 79.9,
  radiusMeters: 1000,
  source: 'test',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Incident _incident(
  String id,
  IncidentCategory category, {
  bool sos = false,
  IncidentStatus status = IncidentStatus.pending,
}) => Incident(
  id: id,
  reporterId: 'r',
  category: category,
  latitude: 6.9,
  longitude: 79.9,
  status: status,
  credibilityScore: 0,
  isSos: sos,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Shelter _shelter(String id, String status) =>
    Shelter(id: id, name: id, latitude: 6.9, longitude: 79.9, status: status);

void main() {
  const everythingOff = MapFilters(
    alerts: false,
    incidents: false,
    shelters: false,
    family: false,
  );

  test('critical alerts stay visible even with alerts turned off', () {
    final visible = everythingOff.visibleAlerts([
      _alert('red', AlertSeverity.red),
      _alert('orange', AlertSeverity.orange),
    ]);
    expect(visible.map((a) => a.id), ['red']);
  });

  test(
    'active SOS and trapped-person reports bypass every incident filter',
    () {
      final filters = everythingOff.copyWith(
        hiddenCategories: IncidentCategory.values.toSet(),
      );
      final visible = filters.visibleIncidents([
        _incident('sos', IncidentCategory.blockedRoad, sos: true),
        _incident('trapped', IncidentCategory.trappedPerson),
        _incident('road', IncidentCategory.blockedRoad),
        _incident(
          'old-sos',
          IncidentCategory.other,
          sos: true,
          status: IncidentStatus.resolved,
        ),
      ]);
      expect(visible.map((i) => i.id), ['sos', 'trapped']);
    },
  );

  test('category and active-only filters apply to routine reports', () {
    const filters = MapFilters(
      hiddenCategories: {IncidentCategory.powerOutage},
    );
    final visible = filters.visibleIncidents([
      _incident('water', IncidentCategory.waterlogging),
      _incident('power', IncidentCategory.powerOutage),
      _incident(
        'fixed',
        IncidentCategory.waterlogging,
        status: IncidentStatus.resolved,
      ),
    ]);
    expect(visible.map((i) => i.id), ['water']);
  });

  test('open-only shelter filter and the changed-count badge', () {
    const filters = MapFilters(openSheltersOnly: true);
    final visible = filters.visibleShelters([
      _shelter('a', 'open'),
      _shelter('b', 'full'),
    ]);
    expect(visible.map((s) => s.id), ['a']);
    expect(filters.changedCount, 1);
    expect(const MapFilters().changedCount, 0);
  });
}
