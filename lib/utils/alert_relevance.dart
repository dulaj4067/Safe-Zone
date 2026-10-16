import 'package:latlong2/latlong.dart';

import '../models/alert.dart';

/// How much one alert matters to one person: severity weighted by how close
/// they are. One definition shared by the top banner (`AlertProvider`) and the
/// in-screen `LocationAlertBanner`, so both always agree on which single alert
/// is the most critical and nearest.
///
/// Beyond [rangeMultiplier] times an alert's own radius it is too far away to
/// matter at all, and the result is `null`.
const double kAlertRelevanceRangeMultiplier = 6.0;

double alertSeverityWeight(AlertSeverity severity) {
  switch (severity) {
    case AlertSeverity.red:
      return 100;
    case AlertSeverity.orange:
      return 50;
    case AlertSeverity.yellow:
      return 20;
    case AlertSeverity.green:
      return 5;
  }
}

/// Severity x proximity. Proximity is 1.0 anywhere inside the alert's radius
/// and decays toward 0 beyond it. With no position fix ([here] is null) only
/// severity counts.
double? alertRelevance(DisasterAlert alert, LatLng? here) {
  if (here == null) return alertSeverityWeight(alert.severity);
  final metres = const Distance()(here, LatLng(alert.centerLat, alert.centerLng));
  if (metres > alert.radiusMeters * kAlertRelevanceRangeMultiplier) return null;
  final proximity =
      metres <= alert.radiusMeters ? 1.0 : alert.radiusMeters / metres;
  return alertSeverityWeight(alert.severity) * proximity;
}
