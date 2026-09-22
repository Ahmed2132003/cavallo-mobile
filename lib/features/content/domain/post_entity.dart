/// Part P-044 scope: the clean domain representation of a single Post
/// owned by the signed-in Business account — no transport concerns
/// (no raw JSON keys, no DTO types) cross this boundary, same
/// convention as `product_entity.dart` (Part P-033).
///
/// Field list confirmed against the real backend
/// (`content.serializers.PostSerializer`, Parts P-041/P-044 — read on
/// GitHub, not guessed):
/// `{id, business, caption, image, status, rejection_reason,
/// created_at, updated_at}`.
///
/// * `businessId` is read-only — same reasoning as `Product.businessId`
///   (Part P-033): `business` is in `read_only_fields` on
///   `PostSerializer`, resolved server-side from
///   `request.user.business_profile`.
/// * `imageUrl` is nullable — `Post.image` is a plain optional
///   `FileField` (no `ImageField`/Pillow dependency, per P-041's own
///   progress note).
/// * `rejectionReason` is this part's own backend addition (STEP 1) —
///   non-null ONLY when [status] is [ModerationStatus.rejected]; see
///   `content.serializers._get_rejection_reason()`.
library;

import 'moderation_status.dart';

class Post {
  const Post({
    required this.id,
    required this.businessId,
    required this.caption,
    required this.status,
    this.imageUrl,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  final int id;

  /// Read-only. See this file's module docstring.
  final int businessId;

  final String caption;

  /// Nullable — no image uploaded yet, or the backend's `image` field
  /// is genuinely empty (`Post.image` is optional on both read/write).
  final String? imageUrl;

  final ModerationStatus status;

  /// Non-null only when [status] is [ModerationStatus.rejected].
  final String? rejectionReason;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Post copyWith({
    int? id,
    int? businessId,
    String? caption,
    String? imageUrl,
    ModerationStatus? status,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Post(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      caption: caption ?? this.caption,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Post &&
          other.id == id &&
          other.businessId == businessId &&
          other.caption == caption &&
          other.imageUrl == imageUrl &&
          other.status == status &&
          other.rejectionReason == rejectionReason &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    caption,
    imageUrl,
    status,
    rejectionReason,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Post(id: $id, status: $status, businessId: $businessId)';
}