/// Part P-045 scope: the clean, customer-facing domain representation
/// of a single PUBLISHED, fully-processed Reel — same split reasoning
/// as `PublicPost` (`public_post_entity.dart`, this same part). Every
/// [PublicReel] this app ever constructs is, by construction, already
/// `status == published` AND `processing_status == ready` — see
/// `ReelPublicRepositoryImpl` (this part, STEP 1) for exactly where
/// and how both are enforced.
///
/// Part BUGFIX-058: added [isLiked], [isSaved], [likesCount],
/// [commentsCount], [sharesCount] — same per-viewer social state and
/// real counters added to `PublicPost`, now returned by
/// `ReelPublicSerializer` too. Same optional-with-defaults reasoning
/// as `PublicPost` above — see that entity's docstring.
library;

class PublicReel {
  const PublicReel({
    required this.id,
    required this.businessId,
    required this.caption,
    this.videoUrl,
    this.thumbnailUrl,
    this.durationSeconds,
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

  final String? videoUrl;

  /// Read-only, set by `content.tasks.transcode_reel()`. Should always
  /// be non-null in practice for a [PublicReel] (the backend's own
  /// `ReelPublishedManager` requires `processing_status == "ready"`,
  /// which only happens after transcoding sets this), but kept
  /// nullable defensively since the raw JSON field itself is nullable.
  final String? thumbnailUrl;

  final int? durationSeconds;

  /// Denormalized counter from the backend (`Reel.likes_count`).
  final int likesCount;

  /// Denormalized counter from the backend (`Reel.comments_count`).
  final int commentsCount;

  /// Denormalized counter from the backend (`Reel.shares_count`).
  final int sharesCount;

  /// Whether the CURRENT viewer has liked this reel. False for an
  /// unauthenticated fetch — see `ReelPublicSerializer.get_is_liked`.
  final bool isLiked;

  /// Whether the CURRENT viewer has saved this reel. Same
  /// per-viewer/unauthenticated-false shape as [isLiked].
  final bool isSaved;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  PublicReel copyWith({
    int? id,
    int? businessId,
    String? caption,
    String? videoUrl,
    String? thumbnailUrl,
    int? durationSeconds,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    bool? isLiked,
    bool? isSaved,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PublicReel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      caption: caption ?? this.caption,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
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
      (other is PublicReel &&
          other.id == id &&
          other.businessId == businessId &&
          other.caption == caption &&
          other.videoUrl == videoUrl &&
          other.thumbnailUrl == thumbnailUrl &&
          other.durationSeconds == durationSeconds &&
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
    videoUrl,
    thumbnailUrl,
    durationSeconds,
    likesCount,
    commentsCount,
    sharesCount,
    isLiked,
    isSaved,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'PublicReel(id: $id, businessId: $businessId)';
}