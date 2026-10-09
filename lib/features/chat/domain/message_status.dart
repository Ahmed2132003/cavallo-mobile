/// Part P-074 STEP 2 — a typed wrapper around the backend's raw
/// message-delivery status string (`Message.status` in `chat/models.py`,
/// per P-069's `ALLOWED_TRANSITIONS`: `sent` -> `delivered` -> `read`).
///
/// `lib/core/chat/chat_event.dart` (P-073) deliberately keeps `status` as
/// a raw `String` on `MessageReceived`/`StatusUpdate` — its own doc
/// comment says a shared status enum, if one is ever needed, belongs in
/// `lib/features/chat/` (this file), not in `core`. This is that enum.
enum MessageStatus {
  sent,
  delivered,
  read,

  /// A status string the backend sent that this build doesn't recognize.
  /// Chosen over throwing, so one unexpected value can't take down an
  /// entire message-list/history parse — matches
  /// `ChatConnectionManager._onMalformedFrame`'s own "drop the one bad
  /// frame, don't crash the whole stream" philosophy.
  unknown;

  /// Parses the raw backend string (`"sent"`, `"delivered"`, `"read"`).
  factory MessageStatus.fromRaw(String raw) {
    switch (raw) {
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      default:
        return MessageStatus.unknown;
    }
  }
}
