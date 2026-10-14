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

  /// Creates the account and returns its user id, or null on failure (see
  /// [error]). The profile row is created server-side by the
  /// `handle_new_user` trigger; the role is always assigned by the server.
  Future<String?> register({
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
        // The link in the confirmation email lands on the auth-callback
        // Edge Function, which opens the app (not the project's Site URL).
        emailRedirectTo: authCallbackUrl,
        data: {
          'full_name': fullName,
          'phone': phone,
        },
      );

      // If the project requires email confirmation, signUp succeeds but
      // returns no session yet. Either way we treat the call as successful
      // so the UI can show the "check your email" message.
      final user = response.user;
      if (user != null) {
        // Supabase returns a user with no identities when the email is
        // already registered (to avoid revealing which emails exist).
        if (user.identities != null && user.identities!.isEmpty) {
          _error = 'An account with this email already exists. Try signing in.';
          return null;
        }
        if (response.session != null) {
          // Signed in immediately (email confirmation off): make sure the
          // profile has the details from the form. Role is never sent.
          try {
            await SupabaseService.client.from('profiles').upsert({
              'id': user.id,
              'full_name': fullName,
              'phone': phone,
            });
          } catch (e) {
            debugPrint('register: profile upsert failed: $e');
          }
        }
        _error = null;
        return user.id;
      }

      _error = 'Registration failed. Please try again.';
      return null;
    } on AuthException catch (e) {
      // handle_new_user rejects a phone number that's already registered;
      // Supabase Auth reports that as a generic database error.
      _error = e.message.contains('Database error saving new user')
          ? 'This mobile number is already registered. Sign in instead, or use a different number.'
          : e.message;
      return null;
    } catch (_) {
      _error = "Couldn't reach the server. Check your connection and try again.";
      return null;
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

  /// `https://PROJECT.supabase.co/functions/v1/auth-callback`
  static String get authCallbackUrl {
    final api = Uri.parse(SupabaseService.client.rest.url);
    return '${api.origin}/functions/v1/auth-callback';
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
}
