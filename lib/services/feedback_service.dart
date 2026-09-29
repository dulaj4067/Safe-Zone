import '../models/feedback_entry.dart';
import 'supabase_service.dart';

/// Citizen feedback over `feedback_forms`.
class FeedbackService {
  Future<void> submit({
    required int rating,
    String? needs,
    String? zoneId,
  }) async {
    await SupabaseService.client.from('feedback_forms').insert({
      'submitted_by': SupabaseService.currentUserId,
      'rating': rating,
      'needs': (needs == null || needs.trim().isEmpty) ? null : needs.trim(),
      'zone_id': zoneId,
    });
  }

  /// Newest first. RLS returns everything for authorities and only the
  /// caller's own rows for everyone else.
  Future<List<FeedbackEntry>> fetchRecent({int limit = 200}) async {
    final rows = await SupabaseService.client
        .from('feedback_forms')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => FeedbackEntry.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}
