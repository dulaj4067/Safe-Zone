import 'package:latlong2/latlong.dart';

class EvacuationRoute {
  const EvacuationRoute({
    required this.id,
    required this.zoneId,
    required this.startPoint,
    required this.safeZonePoint,
    required this.routePolyline,
    required this.instructions,
    required this.lastUpdated,
  });

  final String id;
  final String zoneId;
  final LatLng startPoint;
  final LatLng safeZonePoint;
  final List<LatLng> routePolyline;
  final List<String> instructions;
  final DateTime lastUpdated;

  Map<String, dynamic> toJson() => {
        'id': id,
        'zoneId': zoneId,
        'startPoint': _pointToJson(startPoint),
        'safeZonePoint': _pointToJson(safeZonePoint),
        'routePolyline': routePolyline.map(_pointToJson).toList(),
        'instructions': instructions,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory EvacuationRoute.fromJson(Map<String, dynamic> json) =>
      EvacuationRoute(
        id: json['id'] as String,
        zoneId: json['zoneId'] as String,
        startPoint: _pointFromJson(json['startPoint'] as Map<String, dynamic>),
        safeZonePoint:
            _pointFromJson(json['safeZonePoint'] as Map<String, dynamic>),
        routePolyline: (json['routePolyline'] as List)
            .map((point) => _pointFromJson(point as Map<String, dynamic>))
            .toList(),
        instructions: (json['instructions'] as List? ?? []).cast<String>(),
        lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      );
}

Map<String, double> _pointToJson(LatLng point) =>
    {'latitude': point.latitude, 'longitude': point.longitude};

LatLng _pointFromJson(Map<String, dynamic> point) => LatLng(
      (point['latitude'] as num).toDouble(),
      (point['longitude'] as num).toDouble(),
    );