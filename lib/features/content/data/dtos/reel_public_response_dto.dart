/// Parses the read-only, public-safe Reel shape. Same dual-use pattern
/// as `PostPublicResponseDto` above: used for both
/// `GET /api/v1/reels/public/` (`ReelPublicSerializer`, exact fields
/// below) and `GET /api/v1/reels/{id}/` (the fuller `ReelSerializer`
/// shape, whose extra `status`/`processing_status`/`rejection_reason`
/// keys are simply never read here — `ReelPublicRepositoryImpl` reads
/// both of the first two off the raw map itself, before calling this
/// DTO).
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
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}