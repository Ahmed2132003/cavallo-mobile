import 'message_status.dart';
import 'shared_content.dart';

/// Part P-076 — the kind of media a chat message carries.
///
/// Mirrors the backend's `Message.MediaType` (`"image"` / `"video"`).
/// The backend sets this from the file's SNIFFED content type, never
/// from anything the client sends, and leaves it `""` for a text-only
/// message — [fromRaw] maps that empty string (and anything
/// unrecognized) to `null`, meaning "no media".
enum ChatMediaType {
  image,
  video;

  static ChatMediaType? fromRaw(String? raw) {
    switch (raw) {
      case 'image':
        return ChatMediaType.image;
      case 'video':
        return ChatMediaType.video;
      default:
        return null;
    }
  }
}

/// Part P-074 STEP 2 — a single chat message.
///
/// Mirrors `MessageSerializer`'s exact JSON shape (`chat/serializers.py`):
/// `{id, conversation, sender, text, media, media_type, shared_content,
/// status, created_at}`. This is the identical wire shape `chat_event.dart`'s
/// `MessageReceived` already documents for the WebSocket path — the same
/// shape arrives over REST too (initial history fetch, fetch-since, and
/// the send response), so this entity is the one this feature's data
/// layer parses REST responses into.
///
/// Part P-076: [mediaUrl] / [mediaType] are additive and optional. A
/// text-only message has both `null`; a media-only message has an empty
/// [text].
///
/// Part P-077: [sharedContent] is additive and optional. `null` for any
/// message that shares nothing. A shared-content message may also carry
/// [text] (e.g. "check this out!"), but never media (the backend rejects
/// that combination).
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.status,
    required this.createdAt,
    this.mediaUrl,
    this.mediaType,
    this.sharedContent,
  });

  final int id;
  final int conversationId;
  final int senderId;
  final String text;
  final MessageStatus status;
  final DateTime createdAt;

  /// Absolute URL of the attached file, or `null` for a text-only message.
  final String? mediaUrl;

  /// `null` when the message has no media.
  final ChatMediaType? mediaType;

  /// Part P-077. `null` when the message shares no platform content.
  final SharedContent? sharedContent;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      conversationId: json['conversation'] as int,
      senderId: json['sender'] as int,
      text: json['text'] as String,
      status: MessageStatus.fromRaw(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      mediaUrl: json['media'] as String?,
      mediaType: ChatMediaType.fromRaw(json['media_type'] as String?),
      sharedContent: SharedContent.tryParse(json['shared_content']),
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
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      sharedContent: sharedContent,
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
          other.createdAt == createdAt &&
          other.mediaUrl == mediaUrl &&
          other.mediaType == mediaType &&
          other.sharedContent == sharedContent);

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    senderId,
    text,
    status,
    createdAt,
    mediaUrl,
    mediaType,
    sharedContent,
  );
}
