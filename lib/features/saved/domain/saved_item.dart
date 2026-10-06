/// Part P-113 (STEP 3B): what the Saved screen knows about one bookmark.
///
/// The backend (`SaveSerializer`, social/serializers.py) returns, for every
/// row of `GET /api/v1/saves/me/`:
///
/// ```json
/// {
///   "id": 12,
///   "content_type": "post" | "reel" | "product",
///   "object_id": 345,
///   "preview": {"preview_text": "...", "preview_image_url": "..." | null}
///             | null,
///   "created_at": "2026-10-05T10:00:00Z"
/// }
/// ```
///
/// `preview` is `null` when the saved target no longer exists. Such an item is
/// [isUnavailable]: the screen shows it as "no longer available" and does not
/// open anything when it is tapped.
enum SavedContentType {
  post('post'),
  reel('reel'),
  product('product');

  const SavedContentType(this.wireValue);

  /// The exact `content_type` string the backend sends and accepts
  /// (`SAVE_ALLOWED_CONTENT_TYPES`).
  final String wireValue;

  /// The type for a backend `content_type` string, or null for a value this
  /// app does not know (a future backend type must not crash the screen).
  static SavedContentType? fromWire(Object? value) {
    for (final SavedContentType type in SavedContentType.values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return null;
  }
}

class SavedItem {
  const SavedItem({
    required this.id,
    required this.contentType,
    required this.objectId,
    this.previewText,
    this.previewImageUrl,
    this.createdAt,
  });

  /// The id of the Save row (not of the saved content).
  final int id;

  final SavedContentType contentType;

  /// The id of the saved Post, Reel or Product. Used for the detail route and
  /// for unsaving.
  final int objectId;

  /// `preview.preview_text`; null only when the whole `preview` is null.
  final String? previewText;

  final String? previewImageUrl;

  final DateTime? createdAt;

  /// True when the backend sent `preview: null` (the target is gone).
  bool get isUnavailable => previewText == null;

  /// Parses one row of the saved list. Returns null (the row is skipped) when
  /// the row is malformed or its `content_type` is not one this app knows.
  static SavedItem? tryFromJson(Map<String, dynamic> json) {
    final SavedContentType? type = SavedContentType.fromWire(
      json['content_type'],
    );
    final Object? id = json['id'];
    final Object? objectId = json['object_id'];
    if (type == null || id is! int || objectId is! int) {
      return null;
    }

    String? text;
    String? imageUrl;
    final Object? preview = json['preview'];
    if (preview is Map<String, dynamic>) {
      text = preview['preview_text'] as String? ?? '';
      final String? rawUrl = preview['preview_image_url'] as String?;
      imageUrl = (rawUrl == null || rawUrl.isEmpty) ? null : rawUrl;
    }

    return SavedItem(
      id: id,
      contentType: type,
      objectId: objectId,
      previewText: text,
      previewImageUrl: imageUrl,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedItem &&
          other.id == id &&
          other.contentType == contentType &&
          other.objectId == objectId &&
          other.previewText == previewText &&
          other.previewImageUrl == previewImageUrl &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    contentType,
    objectId,
    previewText,
    previewImageUrl,
    createdAt,
  );

  @override
  String toString() =>
      'SavedItem(id: $id, ${contentType.wireValue}:$objectId, '
      'unavailable: $isUnavailable)';
}
