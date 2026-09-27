import '../models/shelter.dart';
import '../models/shelter_resource.dart';
import 'profile_service.dart';
import 'supabase_service.dart';

class ShelterService {
  Future<List<Shelter>> fetchShelters() async {
    final rows = await SupabaseService.client.from('shelters').select();
    return (rows as List)
        .map((row) => Shelter.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Name of the person / organisation in `shelters.managed_by`, looked up
  /// in `profiles`. Returns null when the shelter has no manager or the
  /// profile can't be read — the detail sheet simply hides that row.
  Future<String?> fetchManagerName(String? profileId) async {
    if (profileId == null || profileId.isEmpty) return null;
    try {
      final row = await SupabaseService.client
          .from('profiles')
          .select('full_name')
          .eq('id', profileId)
          .maybeSingle();
      final name = row?['full_name'] as String?;
      return (name == null || name.trim().isEmpty) ? null : name;
    } catch (_) {
      return null;
    }
  }

  // ─── Supplies (shelter_resources) ──────────────────────────────────────────

  Future<List<ShelterResource>> fetchResources(String shelterId) async {
    final rows = await SupabaseService.client
        .from('shelter_resources')
        .select()
        .eq('shelter_id', shelterId);
    final resources = (rows as List)
        .map((r) => ShelterResource.fromMap(r as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.type.index.compareTo(b.type.index));
    return resources;
  }

  /// Whether the signed-in user may edit this shelter's supplies: its
  /// manager, or any authority. Mirrors the RLS policy in
  /// sql/coordination_features_migration.sql, which is the real enforcement.
  Future<bool> canManageShelter(Shelter shelter) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;
    if (shelter.managedBy == userId) return true;
    final role = await ProfileService.currentUserRole();
    return role?.isAuthority ?? false;
  }

  Future<void> addResource({
    required String shelterId,
    required ResourceType type,
    required double quantity,
    required String unit,
  }) async {
    await SupabaseService.client.from('shelter_resources').insert({
      'shelter_id': shelterId,
      'resource_type': type.name,
      'quantity': quantity,
      'unit': unit,
    });
  }

  Future<void> updateResource(
    String resourceId, {
    required double quantity,
    required String unit,
  }) async {
    final updated = await SupabaseService.client.from('shelter_resources').update({
      'quantity': quantity,
      'unit': unit,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', resourceId).select();
    requireRowsAffected(updated, 'update this supply');
  }

  Future<void> deleteResource(String resourceId) async {
    final deleted = await SupabaseService.client
        .from('shelter_resources')
        .delete()
        .eq('id', resourceId)
        .select();
    requireRowsAffected(deleted, 'remove this supply');
  }
}
