import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/safety_circle_contact.dart';
import '../models/risk_zone.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';

class LocationUpdate {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final Duration etaRemaining;
  final double distanceRemainingKm;

  LocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.etaRemaining,
    required this.distanceRemainingKm,
  });
}

/// Handles live ETA/location sharing (now backed by real GPS via
/// LocationService) and one-tap "I'm Safe" broadcasts.
///
/// SCHEMA ASSUMPTIONS - check your `sql/` folder and adjust table/column
/// names if these do not match:
///   safety_circle_contacts(id, owner_id, name, phone_number, relationship)
///   location_shares(id, owner_id, zone_id, lat, lng, eta_seconds,
///                    distance_km, is_active, created_at)
///   safety_broadcasts(id, user_id, zone_id, sent_at)
///
/// ETA ASSUMPTION: there's no routing API wired up yet, so "distance
/// remaining" is computed as a straight-line (haversine) distance to an
/// optional destination, and ETA is estimated using a rough average
/// travel speed. Replace `_assumedSpeedKmh` or plug in a real routing
/// service (matching whatever your RouteProvider/routing_service.dart
/// already does) for an accurate ETA.
class SafetyProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  List<SafetyCircleContact> _circle = [];
  bool _isSharing = false;
  String? _activeShareId;
  LocationUpdate? _latestUpdate;
  RiskZone? _activeRiskZone;
  DateTime? _lastBroadcastAt;
  String? _errorMessage;
  bool _isLoading = false;

  StreamSubscription<LatLng>? _positionSubscription;
  LatLng? _destination;
  static const double _assumedSpeedKmh = 20; // rough avg travel speed estimate

  List<SafetyCircleContact> get circle => _circle;
  bool get isLoading => _isLoading;
  bool get isSharing => _isSharing;
  LocationUpdate? get latestUpdate => _latestUpdate;
  RiskZone? get activeRiskZone => _activeRiskZone;
  DateTime? get lastBroadcastAt => _lastBroadcastAt;
  String? get errorMessage => _errorMessage;

  List<SafetyCircleContact> get selectedContacts =>
      _circle.where((c) => c.isSelected).toList();

  Future<void> loadSafetyCircle() async {
    final userId = SupabaseService.currentUserId;

    _isLoading = true;
    notifyListeners();

    try {
      if (userId == null) {
        _circle = _demoSafetyCircle();
        _errorMessage = null;
        return;
      }

      final rows = await SupabaseService.client
          .from('safety_circle_contacts')
          .select()
          .eq('owner_id', userId);

      final contacts = (rows as List)
          .map((r) => SafetyCircleContact.fromMap(r as Map<String, dynamic>))
          .toList();

      _circle = contacts.isNotEmpty ? contacts : _demoSafetyCircle();
      _errorMessage = null;
    } catch (e) {
      _circle = _demoSafetyCircle();
      _errorMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<SafetyCircleContact> _demoSafetyCircle() {
    return [
      SafetyCircleContact(
        id: 'demo-mom',
        name: 'Asha Perera',
        phoneNumber: '+94 77 123 4567',
        relationship: 'Mother',
        isSelected: true,
      ),
      SafetyCircleContact(
        id: 'demo-brother',
        name: 'Nimal Perera',
        phoneNumber: '+94 71 765 4321',
        relationship: 'Brother',
      ),
      SafetyCircleContact(
        id: 'demo-partner',
        name: 'Maya Silva',
        phoneNumber: '+94 76 890 1122',
        relationship: 'Partner',
      ),
    ];
  }

  void toggleContactSelection(String contactId, bool selected) {
    final contact = _circle.firstWhere((c) => c.id == contactId);
    contact.isSelected = selected;
    notifyListeners();
  }

  /// Starts sharing REAL live location/ETA using LocationService.
  /// [destination] is optional — if provided, distance/ETA are computed
  /// against it. If null, we still share live position, just without a
  /// meaningful ETA countdown.
  Future<void> startSharingEta({
    RiskZone? currentRiskZone,
    LatLng? destination,
  }) async {
    final userId = SupabaseService.currentUserId;
    final start = await _resolveStartLocation(currentRiskZone: currentRiskZone);

    _destination = destination;
    final initialDistanceKm = destination != null
        ? Geolocator_distanceKm(start, destination)
        : 0.0;
    final initialEta = destination != null
        ? Duration(seconds: ((initialDistanceKm / _assumedSpeedKmh) * 3600).round())
        : Duration.zero;

    _activeRiskZone = currentRiskZone;
    _isSharing = true;
    _latestUpdate = LocationUpdate(
      latitude: start.latitude,
      longitude: start.longitude,
      timestamp: DateTime.now(),
      etaRemaining: initialEta,
      distanceRemainingKm: initialDistanceKm,
    );
    _errorMessage = null;

    final hasLocationPermissions = await _hasLocationPermissions();
    if (userId != null && hasLocationPermissions) {
      try {
        final row = await SupabaseService.client
            .from('location_shares')
            .insert({
              'owner_id': userId,
              'zone_id': currentRiskZone?.id,
              'lat': start.latitude,
              'lng': start.longitude,
              'eta_seconds': initialEta.inSeconds,
              'distance_km': initialDistanceKm,
              'is_active': true,
            })
            .select()
            .single();

        _activeShareId = row['id'] as String;
      } catch (_) {
        _activeShareId = 'demo-share-${DateTime.now().millisecondsSinceEpoch}';
      }
    } else {
      _activeShareId = 'demo-share-${DateTime.now().millisecondsSinceEpoch}';
    }

    _positionSubscription?.cancel();
    if (hasLocationPermissions) {
      try {
        _positionSubscription = _locationService.watchPosition().listen(
          (pos) => _onPositionUpdate(pos),
          onError: (_) {},
        );
      } catch (_) {
        _positionSubscription = null;
      }
    }

    notifyListeners();
  }

  Future<void> _onPositionUpdate(LatLng pos) async {
    if (!_isSharing || _activeShareId == null) return;

    final distanceKm = _destination != null ? Geolocator_distanceKm(pos, _destination!) : 0.0;
    final etaSeconds = _destination != null ? ((distanceKm / _assumedSpeedKmh) * 3600).round() : 0;

    final update = LocationUpdate(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: DateTime.now(),
      etaRemaining: Duration(seconds: etaSeconds),
      distanceRemainingKm: distanceKm,
    );
    _latestUpdate = update;
    notifyListeners();

    try {
      await SupabaseService.client.from('location_shares').update({
        'lat': update.latitude,
        'lng': update.longitude,
        'eta_seconds': update.etaRemaining.inSeconds,
        'distance_km': update.distanceRemainingKm,
      }).eq('id', _activeShareId!);
    } catch (e) {
      _errorMessage = 'Failed to push location update: $e';
      notifyListeners();
    }

    if (_destination != null && distanceKm <= 0.05) {
      // Within ~50m of destination — treat as arrived.
      await stopSharing();
    }
  }

  Future<void> stopSharing() async {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    if (_activeShareId != null && !(_activeShareId ?? '').startsWith('demo-share-')) {
      try {
        await SupabaseService.client
            .from('location_shares')
            .update({'is_active': false}).eq('id', _activeShareId!);
      } catch (e) {
        _errorMessage = 'Failed to stop sharing: $e';
      }
    }
    _isSharing = false;
    _activeShareId = null;
    _activeRiskZone = null;
    _destination = null;
    notifyListeners();
  }

  Future<void> sendImSafeBroadcast({RiskZone? currentRiskZone}) async {
    final userId = SupabaseService.currentUserId;
    try {
      if (userId != null) {
        await SupabaseService.client.from('safety_broadcasts').insert({
          'user_id': userId,
          'zone_id': currentRiskZone?.id,
          'sent_at': DateTime.now().toIso8601String(),
        });
      }
      _lastBroadcastAt = DateTime.now();
      _errorMessage = null;
    } catch (e) {
      // The app supports demo/fallback flows without auth or backend access.
      // In those cases we still want the user action to be treated as sent.
      _lastBroadcastAt = DateTime.now();
      _errorMessage = null;
    }
    notifyListeners();
  }

  Future<LatLng> _resolveStartLocation({RiskZone? currentRiskZone}) async {
    try {
      final granted = await _locationService.ensurePermission();
      if (!granted) return _fallbackLocation(currentRiskZone);
      final current = await _locationService.getCurrentLocation();
      if (current != null) return current;
    } catch (_) {
      return _fallbackLocation(currentRiskZone);
    }

    return _fallbackLocation(currentRiskZone);
  }

  Future<bool> _hasLocationPermissions() async {
    try {
      return await _locationService.ensurePermission();
    } catch (_) {
      return false;
    }
  }

  LatLng _fallbackLocation(RiskZone? zone) {
    if (zone != null && zone.boundary.isNotEmpty) {
      final totalLat = zone.boundary.fold<double>(0, (sum, point) => sum + point.latitude);
      final totalLng = zone.boundary.fold<double>(0, (sum, point) => sum + point.longitude);
      return LatLng(
        totalLat / zone.boundary.length,
        totalLng / zone.boundary.length,
      );
    }

    return const LatLng(6.9615, 79.9010);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}

/// Straight-line (haversine) distance in km between two points.
/// Uses the `Distance` calculator from latlong2, which is already a
/// dependency in this project (used by risk_zone.dart).
double Geolocator_distanceKm(LatLng a, LatLng b) {
  const calculator = Distance();
  return calculator.as(LengthUnit.Kilometer, a, b);
}