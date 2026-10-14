import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Name of the town / suburb at a location, for the map's area label.
///
/// Uses OpenStreetMap Nominatim reverse geocoding. To respect its usage
/// policy and the user's privacy:
///   * coordinates are rounded to 2 decimals (~1 km) before sending, and
///     results are cached per rounded cell, so normal movement rarely
///     triggers a request;
///   * requests are spaced at least 1.1 s apart and identify the app;
///   * failures return null — callers fall back to the nearest district.
/// Point GEOCODING_BASE_URL (dart-define) at another Nominatim-compatible
/// server for production volumes.
class PlaceNameService {
  PlaceNameService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? kGeocodingBaseUrl;

  static const String kGeocodingBaseUrl = String.fromEnvironment(
    'GEOCODING_BASE_URL',
    defaultValue: 'https://nominatim.openstreetmap.org',
  );
  static const String _userAgent =
      'SafeZone-SriLanka/1.0 (+https://github.com/dulaj4067/Safe-Zone)';

  final http.Client _client;
  final String baseUrl;
  final Map<String, String?> _cache = {};
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  static String cellKey(LatLng p) =>
      '${p.latitude.toStringAsFixed(2)},${p.longitude.toStringAsFixed(2)}';

  Future<String?> placeNameFor(LatLng position) async {
    final key = cellKey(position);
    if (_cache.containsKey(key)) return _cache[key];

    final wait = const Duration(milliseconds: 1100) -
        DateTime.now().difference(_lastRequest);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    _lastRequest = DateTime.now();

    final parts = key.split(',');
    final uri = Uri.parse('$baseUrl/reverse').replace(queryParameters: {
      'format': 'jsonv2',
      'lat': parts[0],
      'lon': parts[1],
      'zoom': '14',
      'accept-language': 'en',
    });
    try {
      final res = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null; // not cached: may recover
      final name = placeNameFromNominatim(jsonDecode(res.body));
      _cache[key] = name;
      return name;
    } catch (e) {
      debugPrint('PlaceNameService: $e');
      return null;
    }
  }

  /// Picks the most useful local name from a Nominatim reverse response:
  /// the neighbourhood-to-town level a person would recognise.
  static String? placeNameFromNominatim(Object? body) {
    if (body is! Map) return null;
    final address = body['address'];
    if (address is! Map) return null;
    for (final field in const [
      'suburb',
      'village',
      'town',
      'city_district',
      'city',
      'municipality',
      'hamlet',
      'county',
      'state_district',
    ]) {
      final value = address[field];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
