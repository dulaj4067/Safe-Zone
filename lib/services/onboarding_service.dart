import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// Tracks first-run onboarding per user.
///
/// Completion lives on the profile (`profiles.onboarding_completed_at`) so it
/// follows the account to a new phone; existing accounts were backfilled as
/// complete by the migration. Progress through the steps is local, so an
/// interrupted onboarding resumes where it stopped. If the server column
/// isn't there yet (migration not applied) the local flag is used alone.
class OnboardingService {
  OnboardingService({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;
  Future<SharedPreferences> get _prefs async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  static String _doneKey(String uid) => 'onboarding_v1_done_$uid';
  static String _stepKey(String uid) => 'onboarding_v1_step_$uid';
  static String _notifDeclinedKey(String uid) => 'onboarding_v1_notif_declined_$uid';

  Future<bool> needsOnboarding(String userId) async {
    final prefs = await _prefs;
    final localDone = prefs.getBool(_doneKey(userId)) ?? false;
    try {
      final row = await SupabaseService.client
          .from('profiles')
          .select('onboarding_completed_at')
          .eq('id', userId)
          .maybeSingle();
      if (row?['onboarding_completed_at'] != null) {
        await prefs.setBool(_doneKey(userId), true);
        return false;
      }
      if (localDone) {
        // Finished offline earlier — record it on the profile now.
        unawaited(_markServerComplete(userId));
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('OnboardingService: using local state only: $e');
      return !localDone;
    }
  }

  Future<int> savedStep(String userId) async =>
      (await _prefs).getInt(_stepKey(userId)) ?? 0;

  Future<void> saveStep(String userId, int step) async =>
      (await _prefs).setInt(_stepKey(userId), step);

  /// Marks onboarding finished. Local state is updated first so the user is
  /// never sent back through onboarding because the network failed.
  Future<void> complete(String userId) async {
    final prefs = await _prefs;
    await prefs.setBool(_doneKey(userId), true);
    await prefs.remove(_stepKey(userId));
    await _markServerComplete(userId);
  }

  Future<void> _markServerComplete(String userId) async {
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'onboarding_completed_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', userId)
          .isFilter('onboarding_completed_at', null);
    } catch (e) {
      debugPrint('OnboardingService: server completion not saved yet: $e');
    }
  }

  /// Whether the user chose "Not now" for notifications during onboarding,
  /// in which case the app doesn't fire the system prompt by itself.
  Future<bool> notificationsDeclined(String userId) async =>
      (await _prefs).getBool(_notifDeclinedKey(userId)) ?? false;

  Future<void> setNotificationsDeclined(String userId, bool declined) async =>
      (await _prefs).setBool(_notifDeclinedKey(userId), declined);
}

