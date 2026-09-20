/// Part P-040 scope: the clean domain representation of one row in the
/// moderator review queue — no transport concerns (no raw JSON keys, no
/// DTO types) cross this boundary, same rule as `user_entity.dart`.
///
/// Shaped from the REAL `moderation.serializers.ModerationQueueSerializer`
/// (Part P-038), confirmed by reading `moderation/serializers.py` and
/// `moderation/models.py` on GitHub — not guessed:
/// `{id, content_type, object_id, status, priority, created_at, age,
/// preview: {preview_text, preview_image_url} | null,
/// submitter?: {business_name}}`.
///
/// The queue is deliberately content-type-agnostic on the backend (a row
/// can point at a Post, a Reel or a Story), so [QueueItem.contentType] is
/// kept as a plain [String] (e.g. `"post"`) rather than an enum: a new
/// content type added in Phase 7/8 must not require a change here.
library;

/// Mirrors `moderation.models.ModerationQueue.Priority` exactly
/// (`"normal"` / `"fast_path"`).
enum QueuePriority {
  normal,
  fastPath;

  /// Parses the backend's raw `priority` string. Throws [FormatException]
  /// on anything unrecognized rather than silently defaulting — an
  /// unknown value means the backend contract changed underneath this
  /// app, and a moderator must not see a silently wrong priority.
  static QueuePriority fromWire(String value) {
    switch (value) {
      case 'normal':
        return QueuePriority.normal;
      case 'fast_path':
        return QueuePriority.fastPath;
      default:
        throw FormatException(
          'Unknown moderation priority from backend: $value',
        );
    }
  }

  /// Inverse of [fromWire] — used for the `?priority=` filter on
  /// `GET /api/v1/moderation/queue/`.
  String toWire() {
    switch (this) {
      case QueuePriority.normal:
        return 'normal';
      case QueuePriority.fastPath:
        return 'fast_path';
    }
  }
}

/// Mirrors `moderation.models.ModerationQueue.Status` exactly
/// (`"pending"` / `"approved"` / `"rejected"`). The list endpoint only
/// ever returns `pending` rows; `approved`/`rejected` appear in the
/// response of the approve/reject calls.
enum QueueItemStatus {
  pending,
  approved,
  rejected;

  /// Parses the backend's raw `status` string. Throws [FormatException]
  /// on anything unrecognized, same reasoning as [QueuePriority.fromWire].
  static QueueItemStatus fromWire(String value) {
    switch (value) {
      case 'pending':
        return QueueItemStatus.pending;
      case 'approved':
        return QueueItemStatus.approved;
      case 'rejected':
        return QueueItemStatus.rejected;
      default:
        throw FormatException('Unknown moderation status from backend: $value');
    }
  }
}

/// One moderation queue row, as far as the presentation layer needs to
/// know. Constructed only by `QueueItemResponseDto.toEntity()`.
class QueueItem {
  const QueueItem({
    required this.id,
    required this.contentType,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.ageDuration,
    this.previewText,
    this.previewImageUrl,
    this.submitterBusinessName,
  });

  /// The queue row's own id (`ModerationQueue.id`) — this is the id used
  /// in `/queue/{id}/approve/` and `/queue/{id}/reject/`, NOT the id of
  /// the underlying Post/Reel/Story.
  final int id;

  /// The backend's content-type model name, e.g. `"post"`, `"reel"`,
  /// `"story"`. Kept as a raw string on purpose — see the module
  /// docstring.
  final String contentType;

  final QueueItemStatus status;
  final QueuePriority priority;
  final DateTime createdAt;

  /// How long the item had been waiting **at the moment the backend
  /// answered** (`age` is whole seconds, computed server-side). It does
  /// not tick on its own — it is refreshed whenever the queue is
  /// re-fetched.
  final Duration ageDuration;

  /// From the content object's `get_moderation_preview()`. `null` when
  /// the backend sent `preview: null` (the content row no longer
  /// exists) or when the preview carries no text.
  final String? previewText;

  /// `null` when the content has no image (the backend's generic default
  /// preview never has one) or when `preview` itself is `null`.
  final String? previewImageUrl;

  /// `null` when the backend omitted the `submitter` key (the content
  /// object exposes no `business` attribute).
  final String? submitterBusinessName;

  /// Convenience for sorting and badges — a `fast_path` item is one the
  /// moderator should see first (Stories, Phase 8).
  bool get isFastPath => priority == QueuePriority.fastPath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueItem &&
          other.id == id &&
          other.contentType == contentType &&
          other.status == status &&
          other.priority == priority &&
          other.createdAt == createdAt &&
          other.ageDuration == ageDuration &&
          other.previewText == previewText &&
          other.previewImageUrl == previewImageUrl &&
          other.submitterBusinessName == submitterBusinessName);

  @override
  int get hashCode => Object.hash(
    id,
    contentType,
    status,
    priority,
    createdAt,
    ageDuration,
    previewText,
    previewImageUrl,
    submitterBusinessName,
  );

  @override
  String toString() =>
      'QueueItem(id: $id, contentType: $contentType, status: $status, '
      'priority: $priority, ageDuration: $ageDuration)';
}