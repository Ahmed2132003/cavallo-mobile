/// Pure JSON mirror of `content.serializers.ReelSerializer`'s exact
/// real read shape (Parts P-042/P-044, confirmed from
/// `content/serializers.py` on GitHub):
/// `{id, business, caption, video, thumbnail, duration_seconds,
/// processing_status, status, rejection_reason, created_at,
/// updated_at}`.
library;

import '../../domain/moderation_status.dart';
import '../../domain/reel_entity.dart';

class ReelResponseDto {
  const ReelResponseDto({
    required this.id,
    required this.business,
    required this.caption,
    required this.video,
    required this.thumbnail,
    required this.durationSeconds,
    required this.processingStatus,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReelResponseDto.fromJson(Map<String, dynamic> json) {
    return ReelResponseDto(
      id: json['id'] as int,
      business: json['business'] as int,
      caption: json['caption'] as String,
      video: json['video'] as String?,
      thumbnail: json['thumbnail'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      processingStatus: json['processing_status'] as String,
      status: json['status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
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
  final String processingStatus;
  final String status;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Reel toEntity() {
    return Reel(
      id: id,
      businessId: business,
      caption: caption,
      videoUrl: video,
      thumbnailUrl: thumbnail,
      durationSeconds: durationSeconds,
      processingStatus: ReelProcessingStatus.fromWire(processingStatus),
      status: ModerationStatus.fromWire(status),
      rejectionReason: rejectionReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}