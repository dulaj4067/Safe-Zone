import 'package:flutter/foundation.dart';
import '../models/safety_circle_contact.dart';
import '../models/risk_zone.dart';
import '../services/supabase_service.dart';

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

/// Handles live ETA/location sharing and one-tap "I'm Safe" broadcasts.
///
/// SCHEMA ASSUMPTIONS - check your `sql/` folder and adjust table/column
/// names if these do not match:
///   safety_circle_contacts(id, owner_id, name, phone_number, relationship)
///   location_shares(id, owner_id, zone_id, lat, lng, eta_seconds,
///                    distance_km, is_active, created_at)
///   safety_broadcasts(id, user_id, zone_id, sent_at)
class SafetyProvider extends ChangeNotifier {
  List<SafetyCircleContact> _circle = [];
  bool _isSharing = false;
  String? _activeShareId;
  LocationUpdate? _latestUpdate;
  RiskZone? _activeRiskZone;
  DateTime? _lastBroadcastAt;
  String? _errorMessage;
  bool _isLoading = false;

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
    if (userId == null) {
      _errorMessage = 'Not signed in.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final rows = await SupabaseService.client
          .from('safety_circle_contacts')
          .select()
          .eq('owner_id', userId);

      _circle = (rows as List)
          .map((r) => SafetyCircleContact.fromMap(r as Map<String, dynamic>))
          .toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load safety circle: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleContactSelection(String contactId, bool selected) {
    final contact = _circle.firstWhere((c) => c.id == contactId);
    contact.isSelected = selected;
    notifyListeners();
  }

  Future<void> startSharingEta({
    RiskZone? currentRiskZone,
    required double startLat,
    required double startLng,
    required Duration initialEta,
    required double initialDistanceKm,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      _errorMessage = 'Not signed in.';
      notifyListeners();
      return;
    }

    try {
      final row = await SupabaseService.client
          .from('location_shares')
          .insert({
            'owner_id': userId,
            'zone_id': currentRiskZone?.id,
            'lat': startLat,
            'lng': startLng,
            'eta_seconds': initialEta.inSeconds,
            'distance_km': initialDistanceKm,
            'is_active': true,
          })
          .select()
          .single();

      _activeShareId = row['id'] as String;
      _activeRiskZone = currentRiskZone;
      _isSharing = true;
      _latestUpdate = LocationUpdate(
        latitude: startLat,
        longitude: startLng,
        timestamp: DateTime.now(),
        etaRemaining: initialEta,
        distanceRemainingKm: initialDistanceKm,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to start sharing: $e';
    }
    notifyListeners();
  }

  Future<void> pushLocationUpdate(LocationUpdate update) async {
    if (!_isSharing || _activeShareId == null) return;
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

    if (update.distanceRemainingKm <= 0) {
      await stopSharing();
    }
  }

  Future<void> stopSharing() async {
    if (_activeShareId != null) {
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
    notifyListeners();
  }

  Future<void> sendImSafeBroadcast({RiskZone? currentRiskZone}) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      _errorMessage = 'Not signed in.';
      notifyListeners();
      return;
    }

    try {
      await SupabaseService.client.from('safety_broadcasts').insert({
        'user_id': userId,
        'zone_id': currentRiskZone?.id,
        'sent_at': DateTime.now().toIso8601String(),
      });
      _lastBroadcastAt = DateTime.now();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to send broadcast: $e';
    }
    notifyListeners();
  }
}
