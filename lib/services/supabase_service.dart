import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper so the rest of the app doesn't call Supabase.instance
/// directly everywhere. Call [SupabaseService.init] once in main() before
/// runApp.
class SupabaseService {
  SupabaseService._();

  static Future<void> init({
    required String url,
    required String publishableKey,
  }) async {
    await Supabase.initialize(url: url, anonKey: publishableKey);
  }

  static SupabaseClient get client => Supabase.instance.client;

  static String? get currentUserId {
    try {
      return client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }
}

/// Row-level security makes a denied UPDATE/DELETE succeed silently with
/// zero rows affected, so callers chain `.select()` and pass the result
/// here to turn that into a real error instead of a false success.
void requireRowsAffected(List<dynamic> rows, String action) {
  if (rows.isEmpty) {
    throw StateError('You don\'t have permission to $action.');
  }
}
