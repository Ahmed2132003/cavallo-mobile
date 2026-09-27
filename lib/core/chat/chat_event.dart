/// Part P-073 STEP 1 — incoming WebSocket event model for the chat feature.
///
/// A sealed type covering the three kinds of JSON payload the backend's
/// `ChatConsumer` (cavallo-app, `chat/consumers.py`, Parts P-067–P-071) ever
/// pushes down an already-open WebSocket connection:
///
///   - `chat_message()`     -> the raw serialized `Message` (P-068's
///                              `MessageSerializer` output), forwarded
///                              with NO wrapping and NO "type" field.
///   - `status_update()`    -> `{"message_id": <id>, "status": <str>}`,
///                              also with NO "type" field (P-069).
///   - `typing_indicator()` -> `{"is_typing": <bool>}`, also with NO
///                              "type" field (P-071).
///
/// IMPORTANT — locked-contract discovery made while implementing this file
/// (verified directly against `chat/consumers.py` on
/// github.com/Ahmed2132003/cavallo-app, commit `656288b`, the tip of
/// P-071): unlike the events the *client* sends to the server (which all
/// carry an explicit `{"type": "..."}` discriminator — `heartbeat`,
/// `typing`, `mark_delivered`, `mark_read`), the events the *server* sends
/// back to the client carry NO "type" field at all. `ChatConsumer.send()`
/// is called with exactly the three raw shapes above in
/// `chat_message()`/`status_update()`/`typing_indicator()`. This means
/// [ChatEvent.fromJson] below cannot switch on a "type" key — it has to
/// discriminate structurally, by which keys are present. The three shapes
/// are structurally disjoint (a raw `Message` always has `id`+`text`+
/// `sender`+`conversation`; a status update is exactly
/// `{message_id, status}`; a typing event is exactly `{is_typing}`), so
/// this is safe, but it is NOT what P-073's own master-plan spec assumed
/// ("a sealed type ... parsed from the raw WebSocket JSON messages
/// matching the backend's exact event shapes" is followed here; the
/// implicit assumption of a "type" tag on every frame is not).
///
/// Also NOTE (flagging, not silently absorbing): the master plan's spec
/// names the third variant `TypingIndicator(userId, isTyping)`, but
/// `typing_indicator()` in `chat/consumers.py` sends only `{"is_typing":
/// ...}` — no user id of any kind. This is consistent with the rest of the
/// backend's chat design (1:1 conversations only, and the server already
/// excludes the sender's own connection from ever receiving its own typing
/// broadcast back via `sender_channel_name` — see that method's
/// docstring), so on a 1:1 thread screen "who is typing" is always "the
/// other participant" and needs no id. [TypingIndicator] below therefore
/// has only an `isTyping` field. If a future part introduces group chats,
/// this shape (and the backend's) will both need revisiting together.
sealed class ChatEvent {
  const ChatEvent();

  /// Parses one already-JSON-decoded WebSocket frame (i.e. the result of
  /// `jsonDecode(text_data)`, NOT the raw string) into a [ChatEvent].
  ///
  /// Throws a [ChatEventParseException] if [json] doesn't match any of the
  /// three known shapes, or matches one but with a field of the wrong
  /// type/missing a required key. The connection manager (P-073 STEP 2)
  /// is expected to catch this per-frame and drop the single malformed
  /// frame rather than let one bad message take down the whole event
  /// stream — matching this consumer's own "malformed frame -> silent
  /// no-op" contract on the send side.
  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    // Typing: exactly one key, "is_typing", and it must be a real bool —
    // checked by key set, not just presence, so a differently-shaped
    // payload that happens to also carry an "is_typing" key (none of the
    // other two shapes ever would, per the backend source, but this keeps
    // the discriminator strict rather than merely "best effort") does not
    // get misclassified.
    if (json.length == 1 && json.containsKey('is_typing')) {
      final isTyping = json['is_typing'];
      if (isTyping is! bool) {
        throw ChatEventParseException(
          'typing_indicator frame: "is_typing" must be a bool, got '
          '${isTyping.runtimeType}',
          json,
        );
      }
      return TypingIndicator(isTyping: isTyping);
    }

    // Status update: exactly the two keys "message_id" and "status".
    if (json.length == 2 &&
        json.containsKey('message_id') &&
        json.containsKey('status')) {
      final messageId = json['message_id'];
      final status = json['status'];
      if (messageId is! int || status is! String) {
        throw ChatEventParseException(
          'status_update frame: expected {message_id: int, status: '
          'String}, got {message_id: ${messageId.runtimeType}, status: '
          '${status.runtimeType}}',
          json,
        );
      }
      return StatusUpdate(messageId: messageId, status: status);
    }

    // Otherwise: must be a raw serialized Message (P-068's
    // MessageSerializer output) — {id, conversation, sender, text,
    // status, created_at}. Every field is required by that serializer
    // (read_only_fields are still always present in the output; `text` is
    // the one client-writable field, but the server always echoes it
    // back), so all six are required here too.
    const requiredMessageKeys = {
      'id',
      'conversation',
      'sender',
      'text',
      'status',
      'created_at',
    };
    if (requiredMessageKeys.every(json.containsKey)) {
      final id = json['id'];
      final conversation = json['conversation'];
      final sender = json['sender'];
      final text = json['text'];
      final status = json['status'];
      final createdAtRaw = json['created_at'];

      if (id is! int ||
          conversation is! int ||
          sender is! int ||
          text is! String ||
          status is! String ||
          createdAtRaw is! String) {
        throw ChatEventParseException(
          'chat_message frame: one or more fields had an unexpected type',
          json,
        );
      }

      final DateTime createdAt;
      try {
        createdAt = DateTime.parse(createdAtRaw);
      } on FormatException {
        throw ChatEventParseException(
          'chat_message frame: "created_at" was not a valid ISO-8601 '
          'timestamp: $createdAtRaw',
          json,
        );
      }

      return MessageReceived(
        id: id,
        conversationId: conversation,
        senderId: sender,
        text: text,
        status: status,
        createdAt: createdAt,
      );
    }

    throw ChatEventParseException(
      'Unrecognized WebSocket event shape — matched none of '
      'chat_message / status_update / typing_indicator',
      json,
    );
  }
}

/// A new chat message pushed in real time (backend event: `chat_message`,
/// Part P-068). Carries the exact fields `MessageSerializer` emits.
///
/// [status] is a raw backend status string (`"sent"`, `"delivered"`, or
/// `"read"`, per `Message.Status` / P-069's `ALLOWED_TRANSITIONS`) rather
/// than an enum here — P-073 STEP 1 is model-only and intentionally does
/// not introduce a shared status enum; if/when P-074 (chat UI) needs one,
/// it should live in `lib/features/chat/` and convert from this string,
/// not be added to this core-layer file.
final class MessageReceived extends ChatEvent {
  const MessageReceived({
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
  final String status;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageReceived &&
          other.id == id &&
          other.conversationId == conversationId &&
          other.senderId == senderId &&
          other.text == text &&
          other.status == status &&
          other.createdAt == createdAt);

  @override
  int get hashCode =>
      Object.hash(id, conversationId, senderId, text, status, createdAt);

  @override
  String toString() =>
      'MessageReceived(id: $id, conversationId: $conversationId, '
      'senderId: $senderId, status: $status)';
}

/// A delivery-state transition for an existing message (backend event:
/// `status_update`, Part P-069). [status] is always `"delivered"` or
/// `"read"` in practice (P-069's `ALLOWED_TRANSITIONS` never broadcasts a
/// transition back to `"sent"`), but is left as a raw `String` here for
/// the same reason noted on [MessageReceived.status] above.
final class StatusUpdate extends ChatEvent {
  const StatusUpdate({required this.messageId, required this.status});

  final int messageId;
  final String status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StatusUpdate &&
          other.messageId == messageId &&
          other.status == status);

  @override
  int get hashCode => Object.hash(messageId, status);

  @override
  String toString() => 'StatusUpdate(messageId: $messageId, status: $status)';
}

/// The other participant's typing state changed (backend event:
/// `typing_indicator`, Part P-071). See this file's top-level doc comment
/// for why there is no `userId` field, unlike the master-plan spec's
/// originally-named `TypingIndicator(userId, isTyping)`.
final class TypingIndicator extends ChatEvent {
  const TypingIndicator({required this.isTyping});

  final bool isTyping;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TypingIndicator && other.isTyping == isTyping);

  @override
  int get hashCode => isTyping.hashCode;

  @override
  String toString() => 'TypingIndicator(isTyping: $isTyping)';
}

/// Thrown by [ChatEvent.fromJson] when a decoded WebSocket frame doesn't
/// match any recognized shape, or matches one with a field of the wrong
/// type. Carries the original decoded [json] for logging — never for
/// display to the user.
class ChatEventParseException implements Exception {
  const ChatEventParseException(this.message, this.json);

  final String message;
  final Map<String, dynamic> json;

  @override
  String toString() => 'ChatEventParseException: $message (payload: $json)';
}