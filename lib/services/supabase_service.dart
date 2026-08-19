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

  static String? get currentUserId => client.auth.currentUser?.id;
}
