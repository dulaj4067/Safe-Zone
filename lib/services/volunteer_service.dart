import '../models/volunteer_task.dart';
import 'supabase_service.dart';

/// Reads/writes `volunteer_tasks` and `volunteer_assignments`.
class VolunteerService {
  /// Every task (optionally just one shelter's), newest first, with the
  /// ids of who's signed up embedded via the assignments foreign key.
  Future<List<VolunteerTask>> fetchTasks({String? shelterId}) async {
    var query = SupabaseService.client
        .from('volunteer_tasks')
        .select('*, volunteer_assignments(volunteer_id)');
    if (shelterId != null) query = query.eq('shelter_id', shelterId);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => VolunteerTask.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> signUp(String taskId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw StateError('Sign in to volunteer.');
    await SupabaseService.client.from('volunteer_assignments').insert({
      'task_id': taskId,
      'volunteer_id': userId,
    });
  }

  Future<void> withdraw(String taskId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final deleted = await SupabaseService.client
        .from('volunteer_assignments')
        .delete()
        .eq('task_id', taskId)
        .eq('volunteer_id', userId)
        .select();
    requireRowsAffected(deleted, 'withdraw from this task');
  }

  Future<void> createTask({
    required String title,
    String? description,
    String? shelterId,
    String? zoneId,
    required int volunteersNeeded,
  }) async {
    await SupabaseService.client.from('volunteer_tasks').insert({
      'title': title,
      'description': description,
      'shelter_id': shelterId,
      'zone_id': zoneId,
      'volunteers_needed': volunteersNeeded,
      'status': VolunteerTaskStatus.open.dbValue,
      'created_by': SupabaseService.currentUserId,
    });
  }

  Future<void> updateStatus(String taskId, VolunteerTaskStatus status) async {
    final updated = await SupabaseService.client
        .from('volunteer_tasks')
        .update({'status': status.dbValue})
        .eq('id', taskId)
        .select();
    requireRowsAffected(updated, 'change this task');
  }
}
