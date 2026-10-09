import 'message_status.dart';
import 'message.dart';
import 'shared_content.dart';

/// Part P-074 STEP 2 — the other participant in a 1:1 conversation, as
/// shown on the Conversation List screen.
///
/// Mirrors `ConversationListSerializer.get_other_participant`'s exact
/// JSON shape (`chat/serializers.py`): `{id, account_type,
/// display_name}`.
class ConversationParticipantSummary {
  const ConversationParticipantSummary({
    required this.id,
    required this.accountType,
    required this.displayName,
  });

  final int id;

  /// Raw backend account-type string (e.g. `"business"` / `"customer"`)
  /// — kept as a raw `String` rather than a shared enum: this project
  /// already owns an account-type concept elsewhere (the `accounts`
  /// app), and duplicating/importing it into `features/chat/domain` is
  /// out of this part's scope.
  final String accountType;

  /// Already fully resolved server-side by
  /// `_resolve_conversation_participant_display_name` (business name,
  /// then customer display name, then email, in that order) — this
  /// layer does not re-derive it.
  final String displayName;

  factory ConversationParticipantSummary.fromJson(Map<String, dynamic> json) {
    return ConversationParticipantSummary(
      id: json['id'] as int,
      accountType: json['account_type'] as String,
      displayName: json['display_name'] as String,
    );
  }
}

/// A conversation's last message, as shown as the list-row preview.
/// Mirrors `ConversationListSerializer.get_last_message`'s exact JSON
/// shape.
class LastMessagePreview {
  const LastMessagePreview({
    required this.id,
    required this.text,
    required this.senderId,
    required this.status,
    required this.createdAt,
    this.mediaType,
    this.sharedContentType,
  });

  final int id;
  final String text;

  /// Part P-076. `null` for a text-only last message.
  final ChatMediaType? mediaType;

  /// Part P-077. `null` when the last message shares nothing. Parsed
  /// from the backend's `shared_content_type` string (`"post"` /
  /// `"reel"` / `"product"` / `""`).
  final SharedContentType? sharedContentType;
  final int senderId;
  final MessageStatus status;
  final DateTime createdAt;

  factory LastMessagePreview.fromJson(Map<String, dynamic> json) {
    return LastMessagePreview(
      id: json['id'] as int,
      text: json['text'] as String,
      senderId: json['sender_id'] as int,
      status: MessageStatus.fromRaw(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      mediaType: ChatMediaType.fromRaw(json['media_type'] as String?),
      sharedContentType: SharedContentType.fromRaw(
        json['shared_content_type'] as String?,
      ),
    );
  }

  /// Part P-076 / P-077 — what the conversation-list row shows. A
  /// media-only or shared-content-only message has blank [text], so it
  /// falls back to a short label instead of an empty subtitle. Text
  /// always wins when present (a captioned photo, or "check this out!"
  /// sent together with a shared product, shows its text).
  String get previewText {
    if (text.isNotEmpty) return text;
    switch (mediaType) {
      case ChatMediaType.image:
        return 'Photo';
      case ChatMediaType.video:
        return 'Video';
      case null:
        break;
    }
    switch (sharedContentType) {
      case SharedContentType.post:
        return 'Shared a post';
      case SharedContentType.reel:
        return 'Shared a reel';
      case SharedContentType.product:
        return 'Shared a product';
      case null:
        return text;
    }
  }
}

/// Part P-074 STEP 2 — one row on the Conversation List screen.
///
/// Mirrors `ConversationListSerializer`'s exact JSON shape
/// (`chat/serializers.py`): `{id, other_participant, last_message,
/// unread_count, created_at}`. Deliberately distinct from the plain
/// `ConversationSerializer` shape `ConversationStartView` returns
/// (`{id, created_at, updated_at, participant_ids}`) — see
/// `ConversationRepository.startConversation`'s own doc comment for why
/// that response is not parsed into this class.
class Conversation {
  const Conversation({
    required this.id,
    required this.otherParticipant,
    required this.lastMessage,
    required this.unreadCount,
    required this.createdAt,
  });

  final int id;

  /// Null only in the defensive fallback the backend itself documents as
  /// "should never happen" (`get_other_participant` returning `None`) —
  /// every real `Conversation` always has exactly 2 participants per
  /// P-066's creation flow.
  final ConversationParticipantSummary? otherParticipant;

  /// Null for a brand-new conversation with no messages sent yet.
  final LastMessagePreview? lastMessage;

  final int unreadCount;
  final DateTime createdAt;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final otherParticipantRaw =
        json['other_participant'] as Map<String, dynamic>?;
    final lastMessageRaw = json['last_message'] as Map<String, dynamic>?;

    return Conversation(
      id: json['id'] as int,
      otherParticipant:
          otherParticipantRaw == null
              ? null
              : ConversationParticipantSummary.fromJson(otherParticipantRaw),
      lastMessage:
          lastMessageRaw == null
              ? null
              : LastMessagePreview.fromJson(lastMessageRaw),
      unreadCount: json['unread_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
