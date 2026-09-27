import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coordination_message.dart';
import 'supabase_service.dart';

/// Shelter-scoped one-to-one messaging over `coordination_messages`. A
/// thread is identified by (shelter, the other person).
class CoordinationService {
  RealtimeChannel? _channel;

  Future<List<CoordinationMessage>> fetchThread({
    required String shelterId,
    required String otherUserId,
  }) async {
    final me = SupabaseService.currentUserId;
    if (me == null) return [];
    final rows = await SupabaseService.client
        .from('coordination_messages')
        .select()
        .eq('shelter_id', shelterId)
        .or('and(sender_id.eq.$me,recipient_id.eq.$otherUserId),'
            'and(sender_id.eq.$otherUserId,recipient_id.eq.$me)')
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => CoordinationMessage.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<CoordinationMessage> send({
    required String shelterId,
    required String recipientId,
    required String message,
  }) async {
    final row = await SupabaseService.client
        .from('coordination_messages')
        .insert({
          'shelter_id': shelterId,
          'sender_id': SupabaseService.currentUserId,
          'recipient_id': recipientId,
          'message': message,
        })
        .select()
        .single();
    return CoordinationMessage.fromMap(row);
  }

  /// One entry per (shelter, other person), latest message first. Reads the
  /// most recent 300 messages involving the signed-in user — RLS already
  /// limits rows to ones they sent or received.
  Future<List<ConversationSummary>> fetchConversations() async {
    final me = SupabaseService.currentUserId;
    if (me == null) return [];
    final rows = await SupabaseService.client
        .from('coordination_messages')
        .select()
        .or('sender_id.eq.$me,recipient_id.eq.$me')
        .order('created_at', ascending: false)
        .limit(300);

    final seen = <String>{};
    final conversations = <ConversationSummary>[];
    for (final r in rows as List) {
      final msg = CoordinationMessage.fromMap(r as Map<String, dynamic>);
      final other = msg.otherParty(me);
      if (other == null) continue;
      if (seen.add('${msg.shelterId}|$other')) {
        conversations.add(ConversationSummary(
          shelterId: msg.shelterId,
          otherUserId: other,
          lastMessage: msg,
        ));
      }
    }
    return conversations;
  }

  /// Live inserts for one shelter's messages; the caller filters to its
  /// own thread. Requires coordination_messages in the supabase_realtime
  /// publication (added by sql/coordination_features_migration.sql).
  void subscribeToShelter(
    String shelterId,
    void Function(CoordinationMessage message) onInsert,
  ) {
    unsubscribe();
    _channel = SupabaseService.client
        .channel('coordination:$shelterId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'coordination_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shelter_id',
            value: shelterId,
          ),
          callback: (payload) =>
              onInsert(CoordinationMessage.fromMap(payload.newRecord)),
        )
        .subscribe();
  }

  void unsubscribe() {
    final channel = _channel;
    if (channel != null) SupabaseService.client.removeChannel(channel);
    _channel = null;
  }
}
