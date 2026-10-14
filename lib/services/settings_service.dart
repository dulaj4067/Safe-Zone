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
  static const String _prefDataSaver = 'pref_a11y_data_saver';
  static const String _prefHaptics = 'pref_a11y_haptics';
  static const String _prefCaptions = 'pref_a11y_captions';
  static const String _prefGlareBoost = 'pref_a11y_glare_boost';
  static const String _prefLocale = 'pref_a11y_locale';

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

  Future<bool> getDataSaver() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefDataSaver) ?? false;
  }

  Future<void> saveDataSaver(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDataSaver, enabled);
  }

  Future<bool> getHaptics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefHaptics) ?? true;
  }

  Future<void> saveHaptics(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefHaptics, enabled);
  }

  Future<bool> getCaptions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefCaptions) ?? true;
  }

  Future<void> saveCaptions(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefCaptions, enabled);
  }

  Future<bool> getGlareBoost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefGlareBoost) ?? false;
  }

  Future<void> saveGlareBoost(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefGlareBoost, enabled);
  }

  Future<String> getLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefLocale) ?? 'en';
  }

  Future<void> saveLocaleCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLocale, code);
  }
}
