/// Part P-045 scope: the clean, customer-facing domain representation
/// of a single PUBLISHED Post — deliberately separate from the
/// owner-facing `Post` (`post_entity.dart`, Parts P-041/P-044), which
/// carries `ModerationStatus`/`rejectionReason`, concepts the public,
/// unauthenticated surface must never reference at all (mirrors the
/// backend's own split between `PostSerializer` and
/// `PostPublicSerializer` — `content/serializers.py`, Part P-043).
/// Every [PublicPost] this app ever constructs is, by construction,
/// already published — see `PostPublicRepositoryImpl` (this part,
/// STEP 1) for exactly where and how that's enforced.
library;

class PublicPost {
  const PublicPost({
    required this.id,
    required this.businessId,
    required this.caption,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final int id;

  final int businessId;

  final String caption;

  /// Nullable — `Post.image` is optional on the backend, same as the
  /// owner-facing `Post.imageUrl` (see that file's docstring).
  final String? imageUrl;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  PublicPost copyWith({
    int? id,
    int? businessId,
    String? caption,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PublicPost(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      caption: caption ?? this.caption,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PublicPost &&
          other.id == id &&
          other.businessId == businessId &&
          other.caption == caption &&
          other.imageUrl == imageUrl &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode =>
      Object.hash(id, businessId, caption, imageUrl, createdAt, updatedAt);

  @override
  String toString() => 'PublicPost(id: $id, businessId: $businessId)';
}