/// Backend configuration, read from `--dart-define` / `--dart-define-from-file`
/// (see `config/dev.example.json`).
///
/// The Supabase URL and publishable key are *meant* to ship inside the app —
/// access control lives in Row Level Security, not in keeping these secret —
/// so the shared project is a sensible default and existing
/// `config/dev.json` files keep working. Never put the service-role key or
/// any other secret here: everything in a dart-define ends up in the APK.
library;

const String _kDefaultSupabaseUrl = 'https://frkwsgriwdezkvrmgsgf.supabase.co';
const String _kDefaultSupabasePublishableKey =
    'sb_publishable_1Ax1SZF9hldmiJ1kyi338w_BvOL4Gxd';

const String _supabaseUrlRaw = String.fromEnvironment('SUPABASE_URL');
const String _supabaseKeyRaw =
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

class AppConfig {
  const AppConfig._({required this.supabaseUrl, required this.supabasePublishableKey});

  final String supabaseUrl;
  final String supabasePublishableKey;

  /// Resolves and validates the configuration. Throws [StateError] with a
  /// message naming the bad value, so a misconfigured build fails at startup
  /// instead of with confusing network errors later.
  static AppConfig load() => resolve(
        url: _supabaseUrlRaw,
        publishableKey: _supabaseKeyRaw,
      );

  /// Separated from [load] so tests can exercise validation directly.
  static AppConfig resolve({required String url, required String publishableKey}) {
    final resolvedUrl = url.trim().isEmpty ? _kDefaultSupabaseUrl : url.trim();
    final resolvedKey = publishableKey.trim().isEmpty
        ? _kDefaultSupabasePublishableKey
        : publishableKey.trim();

    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError(
        'SUPABASE_URL must be an https URL (got "$resolvedUrl").',
      );
    }
    // The service-role key bypasses RLS entirely and must never be bundled.
    if (resolvedKey.startsWith('sb_secret_') || _looksLikeServiceRoleJwt(resolvedKey)) {
      throw StateError(
        'SUPABASE_PUBLISHABLE_KEY is a secret/service-role key. Use the '
        'publishable (anon) key — secret keys must never ship in the app.',
      );
    }
    return AppConfig._(supabaseUrl: resolvedUrl, supabasePublishableKey: resolvedKey);
  }

  static bool _looksLikeServiceRoleJwt(String key) =>
      key.split('.').length == 3 && key.contains('c2VydmljZV9yb2xl'); // "service_role" in base64
}
