import 'message_status.dart';

/// Part P-074 STEP 2 — a single chat message.
///
/// Mirrors `MessageSerializer`'s exact JSON shape (`chat/serializers.py`):
/// `{id, conversation, sender, text, status, created_at}`. This is the
/// identical wire shape `chat_event.dart`'s `MessageReceived` already
/// documents for the WebSocket path — the same shape arrives over REST
/// too (initial history fetch, fetch-since, and the send response), so
/// this entity is the one this feature's data layer parses REST
/// responses into.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int conversationId;
  final int senderId;
  final String text;
  final MessageStatus status;
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      conversationId: json['conversation'] as int,
      senderId: json['sender'] as int,
      text: json['text'] as String,
      status: MessageStatus.fromRaw(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Returns a copy with [status] replaced. Not used by this step's
  /// repositories — placed here because a `StatusUpdate` WebSocket event
  /// (P-073) arriving for an already-loaded message is exactly the case
  /// this exists for, and that consumption happens in P-074's later
  /// presentation-layer steps (the message thread screen), not here.
  Message copyWithStatus(MessageStatus newStatus) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      text: text,
      status: newStatus,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == id &&
          other.conversationId == conversationId &&
          other.senderId == senderId &&
          other.text == text &&
          other.status == status &&
          other.createdAt == createdAt);

  @override
  int get hashCode =>
      Object.hash(id, conversationId, senderId, text, status, createdAt);
}