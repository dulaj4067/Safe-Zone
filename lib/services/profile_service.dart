import '../models/app_user.dart';
import 'supabase_service.dart';

/// Lookups against `profiles` that screens deep in the widget tree need
/// without being handed the signed-in [AppUser] from AppShell.
class ProfileService {
  static String? _cachedRoleUserId;
  static UserRole? _cachedRole;

  /// The signed-in user's role, fetched once per signed-in user. Null when
  /// signed out or the profile can't be read. Only for client-side UI
  /// gating — RLS policies are the real enforcement.
  static Future<UserRole?> currentUserRole() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;
    if (_cachedRoleUserId == userId && _cachedRole != null) return _cachedRole;
    try {
      final row = await SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      _cachedRoleUserId = userId;
      _cachedRole = UserRole.fromDb(row['role'] as String? ?? 'member');
      return _cachedRole;
    } catch (_) {
      return null;
    }
  }

  /// Display names for [ids] (e.g. the other person in each message
  /// thread). Missing or unreadable profiles are simply absent.
  static Future<Map<String, String>> fetchNames(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return {};
    try {
      final rows = await SupabaseService.client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', unique);
      return {
        for (final r in rows as List)
          (r as Map<String, dynamic>)['id'] as String:
              (r['full_name'] as String?)?.trim().isNotEmpty == true
                  ? r['full_name'] as String
                  : 'SafeZone user',
      };
    } catch (_) {
      return {};
    }
  }
}
