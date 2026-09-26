import 'package:flutter/foundation.dart';

import '../models/alert.dart';
import '../models/zone.dart';
import '../services/alert_service.dart';
import '../services/supabase_service.dart';

class AlertFormProvider extends ChangeNotifier {
  final AlertService _service;

  AlertFormProvider({AlertService? service})
      : _service = service ?? AlertService();

  String title = '';
  String alertType = 'flood';
  AlertSeverity severity = AlertSeverity.yellow;
  String? instructions;
  Zone? selectedZone;
  double? customLat;
  double? customLng;
  int radiusMeters = 2000;

  // Broadcast Delivery Channels (enabled by default for maximum reach across all connectivity states)
  bool dispatchPush = true;
  bool dispatchSms = true;
  bool dispatchSiren = true;

  bool _isSubmitting = false;
  String? _submitError;
  DisasterAlert? _lastCreated;
  BroadcastDispatchResult? _lastDispatchResult;

  bool get isSubmitting => _isSubmitting;
  String? get submitError => _submitError;
  DisasterAlert? get lastCreated => _lastCreated;
  BroadcastDispatchResult? get lastDispatchResult => _lastDispatchResult;

  int get selectedChannelsCount =>
      (dispatchPush ? 1 : 0) + (dispatchSms ? 1 : 0) + (dispatchSiren ? 1 : 0);

  bool get hasSelectedChannel => selectedChannelsCount > 0;

  /// Story 3 AC: submission is disabled unless title, severity, a
  /// zone or custom center point, and at least one dispatch channel are present.
  bool get isValid {
    final hasLocation =
        selectedZone != null || (customLat != null && customLng != null);
    return title.trim().isNotEmpty && hasLocation && hasSelectedChannel;
  }

  void togglePush(bool value) {
    dispatchPush = value;
    notifyListeners();
  }

  void toggleSms(bool value) {
    dispatchSms = value;
    notifyListeners();
  }

  void toggleSiren(bool value) {
    dispatchSiren = value;
    notifyListeners();
  }

  void selectAllChannels() {
    dispatchPush = true;
    dispatchSms = true;
    dispatchSiren = true;
    notifyListeners();
  }

  void updateTitle(String value) {
    title = value;
    notifyListeners();
  }

  void updateAlertType(String value) {
    alertType = value;
    notifyListeners();
  }

  void updateSeverity(AlertSeverity value) {
    severity = value;
    notifyListeners();
  }

  void updateInstructions(String value) {
    instructions = value;
    notifyListeners();
  }

  void selectZone(Zone? zone) {
    selectedZone = zone;
    if (zone != null) {
      customLat = null;
      customLng = null;
    }
    notifyListeners();
  }

  void setCustomCenter(double lat, double lng) {
    customLat = lat;
    customLng = lng;
    selectedZone = null;
    notifyListeners();
  }

  void updateRadius(int meters) {
    radiusMeters = meters;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (!isValid || SupabaseService.currentUserId == null) {
      _submitError = 'Fill in all required fields before submitting.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _submitError = null;
    notifyListeners();

    try {
      final lat = customLat ?? selectedZone!.centroidLat!;
      final lng = customLng ?? selectedZone!.centroidLng!;

      final draft = DisasterAlert(
        id: '', // ignored on insert
        title: title.trim(),
        alertType: alertType,
        severity: severity,
        status: AlertStatus.active,
        affectedZoneId: selectedZone?.id,
        centerLat: lat,
        centerLng: lng,
        radiusMeters: radiusMeters,
        instructions: instructions,
        source: 'manual',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _lastCreated = await _service.createAlert(draft);
      _lastDispatchResult = await _service.dispatchMultiChannelBroadcast(
        alert: _lastCreated!,
        sendPush: dispatchPush,
        sendSms: dispatchSms,
        triggerSiren: dispatchSiren,
      );
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      // If this fails with a permission error, it's most likely the RLS
      // "Authority can insert alerts" policy rejecting a non-authority
      // user — client-side role gating should normally prevent reaching
      // this screen at all, but RLS is the real enforcement.
      _submitError = 'Failed to create alert: $e';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    title = '';
    alertType = 'flood';
    severity = AlertSeverity.yellow;
    instructions = null;
    selectedZone = null;
    customLat = null;
    customLng = null;
    radiusMeters = 2000;
    dispatchPush = true;
    dispatchSms = true;
    dispatchSiren = true;
    _submitError = null;
    _lastCreated = null;
    _lastDispatchResult = null;
    notifyListeners();
  }
}
