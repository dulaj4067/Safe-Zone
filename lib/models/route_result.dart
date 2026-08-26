import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

import 'alert.dart';

enum TravelMode { walking, driving }

extension TravelModeApi on TravelMode {
  String get apiValue => name; // 'walking' | 'driving' match Directions API
}

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final int durationSeconds;

  /// Meters of this route that fall inside an active disaster alert's
  /// geofence, and the most severe zone touched (if any) — populated by
  /// RouteHazardScorer.rank() after routes come back from the Directions
  /// API, which has no concept of these zones on its own. Zero/null on a
  /// route that hasn't been scored against alerts.
  final double hazardMeters;
  final AlertSeverity? worstHazardSeverity;

  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.hazardMeters = 0,
    this.worstHazardSeverity,
  });

  bool get passesThroughHazard => worstHazardSeverity != null;

  RouteResult copyWith({
    double? hazardMeters,
    AlertSeverity? worstHazardSeverity,
  }) {
    return RouteResult(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      hazardMeters: hazardMeters ?? this.hazardMeters,
      worstHazardSeverity: worstHazardSeverity ?? this.worstHazardSeverity,
    );
  }

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get durationLabel {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return '${hours}h ${rem}min';
  }

  /// flutter_map's LatLngBounds has a ready-made fromPoints constructor,
  /// so this no longer needs manual min/max tracking.
  LatLngBounds get bounds => LatLngBounds.fromPoints(points);
}