/// Part P-077 — the kind of platform content a chat message shares.
///
/// Mirrors the backend's closed whitelist
/// `SHARE_TO_CHAT_CONTENT_TYPES` (`chat/serializers.py`):
/// `"post"`, `"reel"`, `"product"`. [raw] is the exact string the
/// backend expects in `shared_content_type` when sending, and the
/// exact string it reports back as `shared_content.content_type`.
enum SharedContentType {
  post('post'),
  reel('reel'),
  product('product');

  const SharedContentType(this.raw);

  final String raw;

  /// `""`, `null` and anything unrecognized map to `null`
  /// ("nothing shared"), the same lenient convention as
  /// `ChatMediaType.fromRaw`.
  static SharedContentType? fromRaw(String? raw) {
    for (final type in SharedContentType.values) {
      if (type.raw == raw) return type;
    }
    return null;
  }
}

/// Part P-077 — the viewer-INDEPENDENT description of the content a
/// message shares.
///
/// Mirrors `build_shared_content_payload()` (`chat/serializers.py`):
/// `{content_type, object_id, available, business_id, business_name,
/// preview: {preview_text, preview_image_url}}`.
///
/// It deliberately carries no per-viewer state (no is_liked/is_saved):
/// the same payload is sent over REST and broadcast over the WebSocket
/// to the other participant. The chat bubble (STEP 3) renders a card
/// from [previewText] / [previewImageUrl] and opens the live entity
/// by ([type], [objectId]).
///
/// When [available] is `false` (the target was unpublished,
/// deactivated or deleted after being shared) the backend sends
/// `business_id`, `business_name` and `preview` as `null`, so all of
/// those fields here are `null` too and the UI must show an
/// "unavailable" state instead of the content.
class SharedContent {
  const SharedContent({
    required this.type,
    required this.objectId,
    required this.available,
    this.businessId,
    this.businessName,
    this.previewText,
    this.previewImageUrl,
  });

  final SharedContentType type;
  final int objectId;
  final bool available;
  final int? businessId;
  final String? businessName;
  final String? previewText;
  final String? previewImageUrl;

  /// Lenient parser used by `Message.fromJson`: returns `null` when
  /// [raw] is not a map, or its `content_type` / `object_id` are not
  /// recognizable. One odd payload must never break parsing of the
  /// whole message (and therefore the whole thread).
  static SharedContent? tryParse(Object? raw) {
    if (raw is! Map) return null;

    final type = SharedContentType.fromRaw(raw['content_type'] as String?);
    final objectId = raw['object_id'];
    if (type == null || objectId is! int) return null;

    final previewRaw = raw['preview'];
    final preview = previewRaw is Map ? previewRaw : null;
    final previewText = preview?['preview_text'];
    final previewImageUrl = preview?['preview_image_url'];
    final businessId = raw['business_id'];
    final businessName = raw['business_name'];

    return SharedContent(
      type: type,
      objectId: objectId,
      available: raw['available'] == true,
      businessId: businessId is int ? businessId : null,
      businessName: businessName is String ? businessName : null,
      previewText: previewText is String ? previewText : null,
      previewImageUrl:
          previewImageUrl is String && previewImageUrl.isNotEmpty
              ? previewImageUrl
              : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedContent &&
          other.type == type &&
          other.objectId == objectId &&
          other.available == available &&
          other.businessId == businessId &&
          other.businessName == businessName &&
          other.previewText == previewText &&
          other.previewImageUrl == previewImageUrl);

  @override
  int get hashCode => Object.hash(
    type,
    objectId,
    available,
    businessId,
    businessName,
    previewText,
    previewImageUrl,
  );
}
