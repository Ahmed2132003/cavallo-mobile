/// Parses the read-only, public-safe Reel shape. Same dual-use pattern
/// as `PostPublicResponseDto` above: used for both
/// `GET /api/v1/reels/public/` (`ReelPublicSerializer`, exact fields
/// below) and `GET /api/v1/reels/{id}/` (the fuller `ReelSerializer`
/// shape, whose extra `status`/`processing_status`/`rejection_reason`
/// keys are simply never read here — `ReelPublicRepositoryImpl` reads
/// both of the first two off the raw map itself, before calling this
/// DTO).
///
/// Part BUGFIX-058: added `likes_count`/`comments_count`/
/// `shares_count`/`is_liked`/`is_saved`, parsed the same
/// defensive-default way as `PostPublicResponseDto` — see that file's
/// docstring for why.
library;

import '../../domain/public_reel_entity.dart';

class ReelPublicResponseDto {
  const ReelPublicResponseDto({
    required this.id,
    required this.business,
    required this.caption,
    required this.video,
    required this.thumbnail,
    required this.durationSeconds,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isLiked,
    required this.isSaved,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReelPublicResponseDto.fromJson(Map<String, dynamic> json) {
    return ReelPublicResponseDto(
      id: json['id'] as int,
      business: json['business'] as int,
      caption: json['caption'] as String,
      video: json['video'] as String?,
      thumbnail: json['thumbnail'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      likesCount: (json['likes_count'] as int?) ?? 0,
      commentsCount: (json['comments_count'] as int?) ?? 0,
      sharesCount: (json['shares_count'] as int?) ?? 0,
      isLiked: (json['is_liked'] as bool?) ?? false,
      isSaved: (json['is_saved'] as bool?) ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  final int id;
  final int business;
  final String caption;
  final String? video;
  final String? thumbnail;
  final int? durationSeconds;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLiked;
  final bool isSaved;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PublicReel toEntity() {
    return PublicReel(
      id: id,
      businessId: business,
      caption: caption,
      videoUrl: video,
      thumbnailUrl: thumbnail,
      durationSeconds: durationSeconds,
      likesCount: likesCount,
      commentsCount: commentsCount,
      sharesCount: sharesCount,
      isLiked: isLiked,
      isSaved: isSaved,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}