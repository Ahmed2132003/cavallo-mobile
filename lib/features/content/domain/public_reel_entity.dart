/// Part P-045 scope: the clean, customer-facing domain representation
/// of a single PUBLISHED, fully-processed Reel — same split reasoning
/// as `PublicPost` (`public_post_entity.dart`, this same part). Every
/// [PublicReel] this app ever constructs is, by construction, already
/// `status == published` AND `processing_status == ready` — see
/// `ReelPublicRepositoryImpl` (this part, STEP 1) for exactly where
/// and how both are enforced.
library;

class PublicReel {
  const PublicReel({
    required this.id,
    required this.businessId,
    required this.caption,
    this.videoUrl,
    this.thumbnailUrl,
    this.durationSeconds,
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

  final DateTime? createdAt;
  final DateTime? updatedAt;

  PublicReel copyWith({
    int? id,
    int? businessId,
    String? caption,
    String? videoUrl,
    String? thumbnailUrl,
    int? durationSeconds,
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
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'PublicReel(id: $id, businessId: $businessId)';
}