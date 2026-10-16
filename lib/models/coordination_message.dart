/// One `coordination_messages` row — a message between two people about a
/// specific shelter (e.g. a citizen and that shelter's manager).
class CoordinationMessage {
  final String id;
  final String? shelterId;
  final String senderId;
  final String? recipientId;
  final String message;
  final DateTime createdAt;

  /// When the recipient opened it; null while unread (or on a database
  /// without sql/messaging_privacy_and_unread_migration.sql).
  final DateTime? readAt;

  CoordinationMessage({
    required this.id,
    this.shelterId,
    required this.senderId,
    this.recipientId,
    required this.message,
    required this.createdAt,
    this.readAt,
  });

  factory CoordinationMessage.fromMap(Map<String, dynamic> map) {
    return CoordinationMessage(
      id: map['id'] as String,
      shelterId: map['shelter_id'] as String?,
      senderId: map['sender_id'] as String,
      recipientId: map['recipient_id'] as String?,
      message: map['message'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      readAt: map['read_at'] != null
          ? DateTime.tryParse(map['read_at'] as String)?.toLocal()
          : null,
    );
  }

  /// True when this message was sent to [myId] and not opened yet.
  bool isUnreadFor(String myId) => recipientId == myId && readAt == null;

  /// Whoever isn't [myId] in this message.
  String? otherParty(String myId) => senderId == myId ? recipientId : senderId;

  bool isBetween(String a, String b) =>
      (senderId == a && recipientId == b) || (senderId == b && recipientId == a);
}

/// The inbox's one-line view of a thread: the latest message with one
/// person about one shelter.
class ConversationSummary {
  final String? shelterId;
  final String otherUserId;
  final CoordinationMessage lastMessage;

  /// Messages in this thread sent to the signed-in user and not yet opened.
  final int unreadCount;

  ConversationSummary({
    required this.shelterId,
    required this.otherUserId,
    required this.lastMessage,
    this.unreadCount = 0,
  });
}
