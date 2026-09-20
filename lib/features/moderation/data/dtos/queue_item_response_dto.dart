import '../../domain/queue_item_entity.dart';

/// Pure JSON mirror of one `ModerationQueueSerializer` row (Part P-038) —
/// same convention as every other `*ResponseDto` in this project: raw
/// wire field names, mapped to the domain entity only in [toEntity].
///
/// Wire shape (confirmed from `moderation/serializers.py`):
/// ```json
/// {
///   "id": 5,
///   "content_type": "post",
///   "object_id": 12,
///   "status": "pending",
///   "priority": "fast_path",
///   "created_at": "2026-09-20T10:00:00Z",
///   "age": 754,
///   "preview": {"preview_text": "...", "preview_image_url": null},
///   "submitter": {"business_name": "..."}
/// }
/// ```
/// `preview` can be `null` (content row deleted) and `submitter` is
/// OMITTED entirely — not sent as `null` — when the content object has no
/// `business` attribute; both are parsed as optional here.
class QueueItemResponseDto {
  const QueueItemResponseDto({
    required this.id,
    required this.contentType,
    required this.objectId,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.age,
    this.previewText,
    this.previewImageUrl,
    this.submitterBusinessName,
  });

  factory QueueItemResponseDto.fromJson(Map<String, dynamic> json) {
    final preview = json['preview'] as Map<String, dynamic>?;
    final submitter = json['submitter'] as Map<String, dynamic>?;
    return QueueItemResponseDto(
      id: json['id'] as int,
      contentType: json['content_type'] as String,
      objectId: json['object_id'] as int,
      status: json['status'] as String,
      priority: json['priority'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      age: json['age'] as int,
      previewText: preview?['preview_text'] as String?,
      previewImageUrl: preview?['preview_image_url'] as String?,
      submitterBusinessName: submitter?['business_name'] as String?,
    );
  }

  final int id;
  final String contentType;

  /// The underlying Post/Reel/Story id. Parsed to stay a faithful mirror
  /// of the wire shape, but not carried onto `QueueItem` — moderator
  /// actions always use the queue row's own [id].
  final int objectId;

  /// Raw wire string: `"pending"` | `"approved"` | `"rejected"`.
  final String status;

  /// Raw wire string: `"normal"` | `"fast_path"`.
  final String priority;

  final DateTime createdAt;

  /// Whole seconds since the item was queued, computed server-side.
  final int age;

  final String? previewText;
  final String? previewImageUrl;
  final String? submitterBusinessName;

  QueueItem toEntity() {
    return QueueItem(
      id: id,
      contentType: contentType,
      status: QueueItemStatus.fromWire(status),
      priority: QueuePriority.fromWire(priority),
      createdAt: createdAt,
      ageDuration: Duration(seconds: age),
      previewText: previewText,
      previewImageUrl: previewImageUrl,
      submitterBusinessName: submitterBusinessName,
    );
  }
}