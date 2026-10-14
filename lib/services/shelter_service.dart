import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../models/shelter.dart';
import '../models/shelter_resource.dart';
import 'profile_service.dart';
import 'supabase_service.dart';

class ShelterService {
  /// True when a query failed only because the approval columns do not exist
  /// yet (the workflow migration has not been run on this backend).
  static bool _missingApprovalColumn(PostgrestException e) =>
      e.code == '42703' || e.code == 'PGRST204';

  /// The public list: approved shelters only. RLS also lets owners and
  /// authorities read unapproved rows, so the filter is applied here too.
  Future<List<Shelter>> fetchShelters() async {
    final List rows;
    try {
      rows = await SupabaseService.client
          .from('shelters')
          .select()
          .eq('approval_status', 'approved');
    } on PostgrestException catch (e) {
      if (!_missingApprovalColumn(e)) rethrow;
      final all = await SupabaseService.client.from('shelters').select();
      return (all as List)
          .map((row) => Shelter.fromMap(row as Map<String, dynamic>))
          .toList();
    }
    return rows
        .map((row) => Shelter.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ─── Submission & review workflow ──────────────────────────────────────────

  /// Every shelter the signed-in user submitted or manages, any status.
  Future<List<Shelter>> fetchMyShelters() async {
    final me = SupabaseService.currentUserId;
    if (me == null) return [];
    final rows = await SupabaseService.client
        .from('shelters')
        .select()
        .or('submitted_by.eq.$me,managed_by.eq.$me')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Shelter.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Submissions waiting for an authority (oldest first).
  Future<List<Shelter>> fetchPendingShelters() async {
    final rows = await SupabaseService.client
        .from('shelters')
        .select()
        .eq('approval_status', 'pending')
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => Shelter.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// PostGIS accepts extended WKT for a geography column; note lng first.
  static String _point(double lat, double lng) => 'SRID=4326;POINT($lng $lat)';

  /// Files a new shelter as `pending`. It stays invisible to the public
  /// until an authority approves it.
  Future<void> submitShelter({
    required String name,
    required String type,
    required double latitude,
    required double longitude,
    required int capacity,
    String? address,
    String? description,
    String? contactPhone,
  }) async {
    final me = SupabaseService.currentUserId;
    if (me == null) throw StateError('Sign in to submit a shelter.');
    await SupabaseService.client.from('shelters').insert({
      'name': name,
      'type': type,
      'location': _point(latitude, longitude),
      'capacity': capacity,
      'address': address,
      'description': description,
      'contact_phone': contactPhone,
      'approval_status': 'pending',
      'submitted_by': me,
    });
  }

  /// Edits a shelter's details. For an approved shelter the owner may also
  /// change [status] and [occupancy]; for a pending / rejected one, saving
  /// re-queues it for review (the database trigger enforces that).
  Future<void> updateShelter(
    String id, {
    required String name,
    required String type,
    required double latitude,
    required double longitude,
    required int capacity,
    String? address,
    String? description,
    String? contactPhone,
    String? status,
    int? occupancy,
  }) async {
    final updated = await SupabaseService.client.from('shelters').update({
      'name': name,
      'type': type,
      'location': _point(latitude, longitude),
      'capacity': capacity,
      'address': address,
      'description': description,
      'contact_phone': contactPhone,
      'status': ?status,
      'occupancy': ?occupancy,
    }).eq('id', id).select();
    requireRowsAffected(updated, 'edit this shelter');
  }

  Future<void> approveShelter(String id) async {
    final updated = await SupabaseService.client
        .from('shelters')
        .update({'approval_status': 'approved'})
        .eq('id', id)
        .select();
    requireRowsAffected(updated, 'approve this shelter');
  }

  Future<void> rejectShelter(String id, String reason) async {
    final updated = await SupabaseService.client
        .from('shelters')
        .update({'approval_status': 'rejected', 'rejection_reason': reason})
        .eq('id', id)
        .select();
    requireRowsAffected(updated, 'reject this shelter');
  }

  /// Submitter takes back a pending or rejected submission.
  Future<void> withdrawSubmission(String id) async {
    final deleted = await SupabaseService.client
        .from('shelters')
        .delete()
        .eq('id', id)
        .select();
    requireRowsAffected(deleted, 'withdraw this shelter');
  }

  /// One shelter's current row — the shelter page re-reads this on
  /// pull-to-refresh so occupancy/status aren't stale from the list.
  Future<Shelter?> fetchShelter(String id) async {
    final row = await SupabaseService.client
        .from('shelters')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Shelter.fromMap(row);
  }

  /// Name of the person / organisation in `shelters.managed_by`, looked up
  /// in `profiles`. Returns null when the shelter has no manager or the
  /// profile can't be read — the detail sheet simply hides that row.
  Future<String?> fetchManagerName(String? profileId) async {
    if (profileId == null || profileId.isEmpty) return null;
    final names = await ProfileService.fetchNames([profileId]);
    final name = names[profileId];
    return (name == null || name == 'SafeZone user') ? null : name;
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
