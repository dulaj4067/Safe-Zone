import 'package:latlong2/latlong.dart';

import '../models/alert.dart';
import '../models/route_result.dart';

/// Scores candidate routes by how much they pass through active disaster
/// alert zones, and ranks them so the safest-and-shortest option comes
/// first — the Directions API has no concept of these zones on its own,
/// so this is what actually keeps routing away from them.
///
/// Severity is weighted so a route is only preferred over a shorter one
/// when it meaningfully reduces exposure to a higher-severity zone — a
/// route that's merely a few meters longer isn't worth avoiding a minor
/// green-tier advisory for, but distance saved by cutting through a
/// red-tier zone is never worth it unless every alternative does too.
class RouteHazardScorer {
  static const Distance _distance = Distance();

  static double _severityWeight(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.red:
        return 8.0;
      case AlertSeverity.orange:
        return 4.0;
      case AlertSeverity.yellow:
        return 1.5;
      case AlertSeverity.green:
        return 0.3;
    }
  }

  /// Meters of [points] that fall inside any of [activeAlerts]'s
  /// geofences, and the single worst severity touched.
  static ({double hazardMeters, AlertSeverity? worst}) _exposure(
    List<LatLng> points,
    List<DisasterAlert> activeAlerts,
  ) {
    if (points.length < 2 || activeAlerts.isEmpty) {
      return (hazardMeters: 0, worst: null);
    }

    double hazardMeters = 0;
    AlertSeverity? worst;

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final segmentLength = _distance(a, b);
      final midpoint = LatLng(
        (a.latitude + b.latitude) / 2,
        (a.longitude + b.longitude) / 2,
      );

      // A segment counts as "in" a zone if its midpoint falls inside the
      // alert's radius — good enough at typical polyline vertex spacing
      // without needing full segment/circle intersection math.
      for (final alert in activeAlerts) {
        final center = LatLng(alert.centerLat, alert.centerLng);
        if (_distance(midpoint, center) <= alert.radiusMeters) {
          hazardMeters += segmentLength;
          if (worst == null || alert.severity.index > worst.index) {
            worst = alert.severity;
          }
          break; // don't double-count a segment covered by 2+ zones
        }
      }
    }

    return (hazardMeters: hazardMeters, worst: worst);
  }

  static double _scoreFor(RouteResult route) {
    if (route.worstHazardSeverity == null) return route.distanceMeters;
    return route.distanceMeters +
        (route.hazardMeters * _severityWeight(route.worstHazardSeverity!));
  }

  /// Annotates each candidate with its hazard exposure and returns them
  /// sorted safest-and-shortest first.
  static List<RouteResult> rank(
    List<RouteResult> candidates,
    List<DisasterAlert> activeAlerts,
  ) {
    final annotated = candidates.map((route) {
      final exposure = _exposure(route.points, activeAlerts);
      return route.copyWith(
        hazardMeters: exposure.hazardMeters,
        worstHazardSeverity: exposure.worst,
      );
    }).toList();

    annotated.sort((a, b) => _scoreFor(a).compareTo(_scoreFor(b)));
    return annotated;
  }
}