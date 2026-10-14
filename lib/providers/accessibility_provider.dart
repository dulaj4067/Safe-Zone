import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/admin_strings.dart';
import '../services/settings_service.dart';

/// Inclusion preferences used by authority/admin screens.
class AccessibilityProvider extends ChangeNotifier {
  AccessibilityProvider({SettingsService? settings})
      : _settings = settings ?? SettingsService() {
    load();
  }

  final SettingsService _settings;

  bool dataSaver = false;
  bool hapticsEnabled = true;
  bool captionsEnabled = true;
  bool glareBoost = false;
  String localeCode = 'en';
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get isRtl => localeCode == 'ar';
  Locale get locale => Locale(localeCode);
  AdminStrings get strings => AdminStrings.forCode(localeCode);

  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  Future<void> load() async {
    dataSaver = await _settings.getDataSaver();
    hapticsEnabled = await _settings.getHaptics();
    captionsEnabled = await _settings.getCaptions();
    glareBoost = await _settings.getGlareBoost();
    localeCode = await _settings.getLocaleCode();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDataSaver(bool value) async {
    dataSaver = value;
    notifyListeners();
    await _settings.saveDataSaver(value);
  }

  Future<void> setHaptics(bool value) async {
    hapticsEnabled = value;
    notifyListeners();
    await _settings.saveHaptics(value);
  }

  Future<void> setCaptions(bool value) async {
    captionsEnabled = value;
    notifyListeners();
    await _settings.saveCaptions(value);
  }

  Future<void> setGlareBoost(bool value) async {
    glareBoost = value;
    notifyListeners();
    await _settings.saveGlareBoost(value);
  }

  Future<void> setLocaleCode(String code) async {
    localeCode = code;
    notifyListeners();
    await _settings.saveLocaleCode(code);
  }

  /// Optional haptic pulse. Never plays sound — OS volume/silent mode wins.
  Future<void> pulseHaptic() async {
    if (!hapticsEnabled) return;
    await HapticFeedback.mediumImpact();
  }
}

AdminStrings adminStringsOf(BuildContext context) {
  try {
    return context.watch<AccessibilityProvider>().strings;
  } catch (_) {
    return AdminStrings.en;
  }
}

String localeCodeOf(BuildContext context) {
  try {
    return context.watch<AccessibilityProvider>().localeCode;
  } catch (_) {
    return 'en';
  }
}
