import 'package:shared_preferences/shared_preferences.dart';

/// Persistence for the handful of Settings toggles that don't have an
/// existing home in a domain service (compare [AlertService], which
/// backs the alert-delivery preferences).
///
/// NOTE: unlike the alert-delivery preferences, none of these three currently
/// gate any real behaviour elsewhere in the app — there's no background
/// high-accuracy location beacon, no auto-escalation pipeline, and no
/// external dispatch-relay integration to turn on or off. Persisting them
/// here at least means the toggle a citizen/authority sets survives an app
/// restart instead of silently resetting, but building the underlying
/// features is separate, larger work.
class SettingsService {
  static const String _prefLiveLocationBeacon = 'pref_live_location_beacon';
  static const String _prefAutoEscalateSos = 'pref_auto_escalate_sos';
  static const String _prefAutoRelayDispatch = 'pref_auto_relay_dispatch';

  Future<bool> getLiveLocationBeacon() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefLiveLocationBeacon) ?? true;
  }

  Future<void> saveLiveLocationBeacon(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefLiveLocationBeacon, enabled);
  }

  Future<bool> getAutoEscalateSos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefAutoEscalateSos) ?? true;
  }

  Future<void> saveAutoEscalateSos(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoEscalateSos, enabled);
  }

  Future<bool> getAutoRelayDispatch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefAutoRelayDispatch) ?? false;
  }

  Future<void> saveAutoRelayDispatch(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoRelayDispatch, enabled);
  }
}
