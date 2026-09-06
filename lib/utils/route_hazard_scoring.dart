import 'package:latlong2/latlong.dart';

import '../models/alert.dart';
import '../models/route_result.dart';

/// Scores candidate routes by how much they pass through active disaster
/// alert zones, and ranks them so the safest-and-shortest option comes
/// first — the Directions/OSRM API has no concept of these zones on its
/// own, so this is what actually keeps routing away from them.
///
/// Red zones are treated as near-inviolable: a route that avoids red
/// entirely always ranks above one that doesn't, regardless of distance.
/// Orange/yellow/green are weighted more softly — a route is only
/// preferred over a shorter one when it meaningfully reduces exposure to
/// those, not for a few meters saved.
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

  static bool _crossesRed(RouteResult route) =>
      route.worstHazardSeverity == AlertSeverity.red;

  static double _weightedScore(RouteResult route) {
    if (route.worstHazardSeverity == null) return route.distanceMeters;
    return route.distanceMeters +
        (route.hazardMeters * _severityWeight(route.worstHazardSeverity!));
  }

  /// Annotates each candidate with its hazard exposure and returns them
  /// ranked safest-and-shortest first. Ranking is two-tier: routes that
  /// avoid red entirely always come before ones that don't (tier 1), and
  /// within each tier, routes are ordered by weighted distance/hazard
  /// score (tier 2) — so red is only ever crossed when literally every
  /// alternative crosses it too.
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

    annotated.sort((a, b) {
      final aRed = _crossesRed(a) ? 1 : 0;
      final bRed = _crossesRed(b) ? 1 : 0;
      if (aRed != bRed) return aRed.compareTo(bRed);
      return _weightedScore(a).compareTo(_weightedScore(b));
    });

    return annotated;
  }
}