import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

/// Manages Supabase Auth state: login, register, logout.
///
/// Exposes [isBusy] and [error] so the UI can react without any
/// additional local state. Wires to Supabase's own [onAuthStateChange]
/// stream so [isSignedIn] stays in sync across the whole app.
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    // Mirror Supabase auth changes so widgets rebuild automatically.
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      notifyListeners();
    });
    _session = SupabaseService.client.auth.currentSession;
  }

  Session? _session;
  bool _isBusy = false;
  String? _error;

  bool get isSignedIn => _session != null;
  bool get isBusy => _isBusy;
  String? get error => _error;
  Session? get session => _session;

  // ─── Auth Actions ──────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    _setBusy(true);
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _error = null;
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'An unexpected error occurred. Please try again.';
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    _setBusy(true);
    try {
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
        },
      );

      // If the project requires email confirmation, signUp succeeds but
      // returns no session yet. Either way we treat the call as successful
      // so the UI can show the "check your email" message.
      if (response.user != null) {
        // Attempt to upsert the profile row immediately (only works if the
        // session was issued i.e. email-confirmation is disabled).
        try {
          await SupabaseService.client.from('profiles').upsert({
            'id': response.user!.id,
            'full_name': fullName,
            'phone': phone,
            'role': 'member',
          });
        } catch (_) {
          // Profile upsert might fail when there's no active session yet
          // (email confirmation pending). The DB trigger / confirmation
          // webhook should handle creation in that case — ignore silently.
        }
        _error = null;
        return true;
      }

      _error = 'Registration failed. Please try again.';
      return false;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'An unexpected error occurred. Please try again.';
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> logout() async {
    _setBusy(true);
    try {
      await SupabaseService.client.auth.signOut();
      _error = null;
    } catch (_) {
      // Ignore sign-out errors; local session is cleared regardless.
    } finally {
      _setBusy(false);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
}
