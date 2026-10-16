import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coordination_message.dart';
import 'shelter_service.dart';
import 'supabase_service.dart';
import 'volunteer_service.dart';

/// Someone a shelter manager can open a new conversation with.
class MessageContact {
  final String shelterId;
  final String shelterName;
  final String userId;

  const MessageContact({
    required this.shelterId,
    required this.shelterName,
    required this.userId,
  });
}

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
        .order('created_at', ascending: false)
        .limit(500);
    // Newest 500 only (a long-running chat should not load in full); shown
    // oldest-first.
    return (rows as List)
        .map((r) => CoordinationMessage.fromMap(r as Map<String, dynamic>))
        .toList()
        .reversed
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

    final messages = [
      for (final r in rows as List) CoordinationMessage.fromMap(r as Map<String, dynamic>),
    ];

    // Unread messages per thread, counted across every fetched row.
    final unread = <String, int>{};
    for (final msg in messages) {
      final other = msg.otherParty(me);
      if (other != null && msg.isUnreadFor(me)) {
        final key = '${msg.shelterId}|$other';
        unread[key] = (unread[key] ?? 0) + 1;
      }
    }

    final seen = <String>{};
    final conversations = <ConversationSummary>[];
    for (final msg in messages) {
      final other = msg.otherParty(me);
      if (other == null) continue;
      final key = '${msg.shelterId}|$other';
      if (seen.add(key)) {
        conversations.add(ConversationSummary(
          shelterId: msg.shelterId,
          otherUserId: other,
          lastMessage: msg,
          unreadCount: unread[key] ?? 0,
        ));
      }
    }
    return conversations;
  }

  /// Messages sent to the signed-in user that they haven't opened. Returns 0
  /// when the unread column doesn't exist yet rather than failing.
  Future<int> fetchUnreadCount() async {
    final me = SupabaseService.currentUserId;
    if (me == null) return 0;
    try {
      final rows = await SupabaseService.client
          .from('coordination_messages')
          .select('id')
          .eq('recipient_id', me)
          .isFilter('read_at', null);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Marks everything the other person sent in this thread as read.
  Future<void> markThreadRead({
    required String shelterId,
    required String otherUserId,
  }) async {
    final me = SupabaseService.currentUserId;
    if (me == null) return;
    try {
      await SupabaseService.client
          .from('coordination_messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('shelter_id', shelterId)
          .eq('sender_id', otherUserId)
          .eq('recipient_id', me)
          .isFilter('read_at', null);
    } catch (_) {
      // Read receipts are a nicety; never block the conversation on them.
    }
  }

  /// People a shelter manager can start a conversation with: volunteers
  /// signed up to tasks at shelters they manage. Empty for everyone else.
  Future<List<MessageContact>> fetchStartableContacts() async {
    final me = SupabaseService.currentUserId;
    if (me == null) return [];
    final shelters = (await ShelterService().fetchMyShelters())
        .where((s) => s.managedBy == me)
        .toList();
    final contacts = <MessageContact>[];
    final seen = <String>{};
    for (final shelter in shelters) {
      final tasks = await VolunteerService().fetchTasks(shelterId: shelter.id);
      for (final task in tasks) {
        for (final id in task.volunteerIds) {
          if (id != me && seen.add('${shelter.id}|$id')) {
            contacts.add(MessageContact(
              shelterId: shelter.id,
              shelterName: shelter.name,
              userId: id,
            ));
          }
        }
      }
    }
    return contacts;
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
