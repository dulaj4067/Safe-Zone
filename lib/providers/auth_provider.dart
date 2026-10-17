import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/error_messages.dart';
import '../services/supabase_service.dart';

/// Manages Supabase Auth state: login, register, logout, password reset and
/// email confirmation.
///
/// Exposes [isBusy] and [error] so the UI can react without any
/// additional local state. Wires to Supabase's own [onAuthStateChange]
/// stream so [isSignedIn] stays in sync across the whole app.
class AuthProvider extends ChangeNotifier {
  /// [auth] defaults to the app's Supabase client; tests pass their own.
  AuthProvider({GoTrueClient? auth}) : _auth = auth ?? SupabaseService.client.auth {
    // Mirror Supabase auth changes so widgets rebuild automatically.
    _auth.onAuthStateChange.listen((data) {
      _session = data.session;
      // A password-reset link opened the app: the user is signed in with a
      // short-lived recovery session and must choose a new password before
      // carrying on (see [isPasswordRecovery]).
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _passwordRecovery = true;
      } else if (data.event == AuthChangeEvent.signedOut) {
        _passwordRecovery = false;
      }
      notifyListeners();
    });
    _session = _auth.currentSession;
  }

  final GoTrueClient _auth;
  Session? _session;
  bool _isBusy = false;
  String? _error;
  bool _passwordRecovery = false;
  String? _unconfirmedEmail;

  bool get isSignedIn => _session != null;

  /// True after a password-reset link signed the user in, until they set a
  /// new password (or sign out).
  bool get isPasswordRecovery => _passwordRecovery && isSignedIn;

  /// The email of the last sign-in that failed because the address isn't
  /// confirmed yet, so the login screen can offer to resend the email.
  String? get unconfirmedEmail => _unconfirmedEmail;
  bool get isBusy => _isBusy;
  String? get error => _error;
  Session? get session => _session;

  // ─── Auth Actions ──────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    _setBusy(true);
    try {
      await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      _error = null;
      _unconfirmedEmail = null;
      return true;
    } on AuthException catch (e) {
      if (e.code == 'email_not_confirmed') {
        _unconfirmedEmail = email;
        _error = "Please confirm your email first. Open the link we sent you. "
            "Can't find it? Check spam, or resend it below.";
      } else {
        _unconfirmedEmail = null;
        _error = friendlyAuthMessage(e);
      }
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
      final response = await _auth.signUp(
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
          : friendlyAuthMessage(e);
      return null;
    } catch (_) {
      _error = kNetworkError;
      return null;
    } finally {
      _setBusy(false);
    }
  }

  /// Emails a password-reset link. Always reports success for a well-formed
  /// request so the screen never reveals whether an account exists; returns
  /// false only when the request itself failed (network, rate limit).
  Future<bool> sendPasswordReset(String email) async {
    _setBusy(true);
    try {
      await _auth.resetPasswordForEmail(
        email,
        redirectTo: authCallbackUrl,
      );
      _error = null;
      return true;
    } on AuthException catch (e) {
      _error = friendlyAuthMessage(e);
      return false;
    } catch (_) {
      _error = kNetworkError;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Sets a new password for the signed-in user (after a reset link) and
  /// ends recovery mode. Returns false with [error] set on failure.
  Future<bool> updatePassword(String newPassword) async {
    _setBusy(true);
    try {
      await _auth.updateUser(
        UserAttributes(password: newPassword),
      );
      _passwordRecovery = false;
      _error = null;
      return true;
    } on AuthException catch (e) {
      _error = friendlyAuthMessage(e);
      return false;
    } catch (_) {
      _error = kNetworkError;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Sends the sign-up confirmation email again.
  Future<bool> resendConfirmation(String email) async {
    _setBusy(true);
    try {
      await _auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: authCallbackUrl,
      );
      _error = null;
      return true;
    } on AuthException catch (e) {
      _error = e.statusCode == '429'
          ? 'Please wait a minute before asking for another email.'
          : friendlyAuthMessage(e);
      return false;
    } catch (_) {
      _error = kNetworkError;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> logout() async {
    _setBusy(true);
    try {
      await _auth.signOut();
      _error = null;
    } catch (_) {
      // Ignore sign-out errors; local session is cleared regardless.
    } finally {
      _setBusy(false);
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Clears the error banner. Safe to call after the provider is gone (a
  /// screen closing at app teardown schedules this for the next frame).
  void clearError() {
    if (_disposed || _error == null) return;
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
