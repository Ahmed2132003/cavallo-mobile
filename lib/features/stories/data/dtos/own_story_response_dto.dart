/// Parses `StorySerializer`'s shape (`stories/serializers.py`) exactly as
/// the owner's `GET /api/v1/stories/` returns it: `{id, business, media,
/// published_at, expires_at, status, created_at, updated_at}`, plus an
/// OPTIONAL `rejection_reason` that the backend does not send today (open
/// gap, see `own_story_entity.dart`). A missing key, a JSON null and a
/// blank string all become a null reason -- nothing is invented.
library;

import '../../domain/own_story_entity.dart';

class OwnStoryResponseDto {
  const OwnStoryResponseDto({
    required this.id,
    required this.business,
    required this.media,
    required this.status,
    required this.publishedAt,
    required this.expiresAt,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  factory OwnStoryResponseDto.fromJson(Map<String, dynamic> json) {
    final rawReason = json['rejection_reason'] as String?;
    final reason = rawReason?.trim();
    return OwnStoryResponseDto(
      id: json['id'] as int,
      business: json['business'] as int,
      media: json['media'] as String,
      status: json['status'] as String?,
      publishedAt: DateTime.parse(json['published_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      rejectionReason: (reason == null || reason.isEmpty) ? null : reason,
      createdAt:
          json['created_at'] == null
              ? null
              : DateTime.parse(json['created_at'] as String),
      updatedAt:
          json['updated_at'] == null
              ? null
              : DateTime.parse(json['updated_at'] as String),
    );
  }

  final int id;
  final int business;
  final String media;
  final String? status;
  final DateTime publishedAt;
  final DateTime expiresAt;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OwnStory toEntity() {
    return OwnStory(
      id: id,
      businessId: business,
      mediaUrl: media,
      status: OwnStoryStatus.fromWire(status),
      publishedAt: publishedAt,
      expiresAt: expiresAt,
      rejectionReason: rejectionReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
