import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../models/route_result.dart';

/// Wraps the free, keyless OSRM public routing API (router.project-osrm.org)
/// — no API key, no billing account, no key-restriction footguns to trip
/// over. It's a community-run demo instance (FOSSGIS), so per their usage
/// policy: keep requests to non-commercial use and under ~1 request per
/// second, which matches this app's usage pattern (one request per
/// shelter tap).
///
/// If you outgrow the demo server's rate limit later, the exact same
/// request shape works against a self-hosted OSRM instance — just change
/// [baseUrl] to point at it.
class RoutingService {
  final String baseUrl;
  RoutingService({this.baseUrl = 'https://router.project-osrm.org'});

  static String _profileFor(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return 'foot';
      case TravelMode.driving:
        return 'driving';
    }
  }

  /// Requests every alternative route OSRM offers between the two points
  /// (not just its single default pick) — needed so RouteHazardScorer has
  /// more than one candidate to compare against active disaster alerts.
  /// OSRM typically returns 1-3 routes, same as the old Google call did.
  Future<List<RouteResult>> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
    required TravelMode mode,
  }) async {
    final profile = _profileFor(mode);
    // OSRM's coordinate order is lon,lat — the opposite of LatLng's
    // lat,lng and of Google's lat,lng. Easy thing to get backwards.
    final coords =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.parse('$baseUrl/route/v1/$profile/$coords').replace(
      queryParameters: {
        'alternatives': 'true',
        'overview': 'full',
        'geometries': 'geojson',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw RouteException('Routing request failed (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final code = data['code'] as String?;
    if (code == 'NoRoute') {
      throw RouteException('No route found between those points.');
    }
    if (code != 'Ok') {
      throw RouteException(
        data['message'] as String? ?? 'Routing failed: $code',
      );
    }

    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw RouteException('No route found between those points.');
    }

    return routes.map((r) {
      final route = r as Map<String, dynamic>;
      // geojson geometry gives [lon, lat] pairs directly — no polyline
      // decoding needed, unlike the old Google integration.
      final coordinates = (route['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      return RouteResult(
        points: coordinates,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).round(),
      );
    }).toList();
  }
}

class RouteException implements Exception {
  final String message;
  RouteException(this.message);
  @override
  String toString() => message;
}