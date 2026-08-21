import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../models/route_result.dart';

/// Wraps the Google Directions API. Requires a Directions-enabled API key —
/// separate from (but can be the same project as) the Maps SDK key used
/// for GoogleMap widgets. Set via --dart-define=DIRECTIONS_API_KEY=... or
/// swap this out for OSRM/Mapbox if you'd rather not depend on Google's
/// Directions billing.
///
/// Note: this still calls Google's Directions REST API over plain HTTP —
/// that's unrelated to which map-rendering package is used, so switching
/// the app's map widgets to flutter_map didn't require dropping this.
/// LatLng here is now latlong2's (matching RouteResult/RouteProvider), not
/// google_maps_flutter's — that was the only change needed, since this
/// file only ever used LatLng's .latitude/.longitude, which both packages
/// provide identically.
class RoutingService {
  final String apiKey;
  RoutingService({required this.apiKey});
  Future<RouteResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    required TravelMode mode,
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': mode.apiValue,
      'key': apiKey,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw RouteException('Routing request failed (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String?;
    if (status == 'ZERO_RESULTS') {
      throw RouteException('No route found between those points.');
    }
    if (status != 'OK') {
      throw RouteException(
        data['error_message'] as String? ?? 'Routing failed: $status',
      );
    }
    final route = (data['routes'] as List).first as Map<String, dynamic>;
    final leg = (route['legs'] as List).first as Map<String, dynamic>;
    final encodedPolyline =
        route['overview_polyline']['points'] as String;
    return RouteResult(
      points: _decodePolyline(encodedPolyline),
      distanceMeters: (leg['distance']['value'] as num).toDouble(),
      durationSeconds: (leg['duration']['value'] as num).toInt(),
    );
  }
  /// Standard Google polyline algorithm decoder. Implemented inline to
  /// avoid pulling in an extra package for one small, stable function.
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
class RouteException implements Exception {
  final String message;
  RouteException(this.message);
  @override
  String toString() => message;
}