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
///
/// Part BUGFIX-058: added [isLiked], [isSaved], [likesCount],
/// [commentsCount], [sharesCount] — the per-viewer social state and
/// real counters now returned by `PostPublicSerializer`. These are the
/// values `ContentActionRow` seeds `contentInteractionProvider` from
/// on every fetch, fixing the cross-account like/save state leak.
/// Deliberately optional with defaults (0 / false), not required: a
/// real fetch through `PostPublicResponseDto.toEntity()` always sets
/// them from the server response, but existing test fixtures across
/// the app construct [PublicPost] directly without them, and forcing
/// every one of those call sites to change is out of this bugfix's
/// scope.
library;

class PublicPost {
  const PublicPost({
    required this.id,
    required this.businessId,
    required this.caption,
    this.imageUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.createdAt,
    this.updatedAt,
  });

  final int id;

  final int businessId;

  final String caption;

  /// Nullable — `Post.image` is optional on the backend, same as the
  /// owner-facing `Post.imageUrl` (see that file's docstring).
  final String? imageUrl;

  /// Denormalized counter from the backend (`Post.likes_count`).
  final int likesCount;

  /// Denormalized counter from the backend (`Post.comments_count`).
  final int commentsCount;

  /// Denormalized counter from the backend (`Post.shares_count`).
  final int sharesCount;

  /// Whether the CURRENT viewer (the authenticated request user this
  /// object was fetched under) has liked this post. False for an
  /// unauthenticated fetch — see `PostPublicSerializer.get_is_liked`.
  final bool isLiked;

  /// Whether the CURRENT viewer has saved this post. Same
  /// per-viewer/unauthenticated-false shape as [isLiked].
  final bool isSaved;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  PublicPost copyWith({
    int? id,
    int? businessId,
    String? caption,
    String? imageUrl,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    bool? isLiked,
    bool? isSaved,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PublicPost(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      caption: caption ?? this.caption,
      imageUrl: imageUrl ?? this.imageUrl,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
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
          other.likesCount == likesCount &&
          other.commentsCount == commentsCount &&
          other.sharesCount == sharesCount &&
          other.isLiked == isLiked &&
          other.isSaved == isSaved &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    caption,
    imageUrl,
    likesCount,
    commentsCount,
    sharesCount,
    isLiked,
    isSaved,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'PublicPost(id: $id, businessId: $businessId)';
}