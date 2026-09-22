/// Parses `StorySerializer`'s shape (`stories/serializers.py`, Part
/// P-046) exactly as `GET /api/v1/stories/public/`
/// (`StoryPublicListView`, Part P-048) returns it: `{id, business,
/// media, published_at, expires_at, status, created_at, updated_at}`.
///
/// `status` is never read here — every row this endpoint returns is
/// already guaranteed `published` by the backend's own queryset (see
/// that view's docstring: `status=Story.Status.PUBLISHED,
/// expires_at__gt=timezone.now()`, evaluated fresh on every request).
/// Unlike `PostPublicResponseDto`/`ReelPublicResponseDto` (Part
/// P-045), this DTO is never reused against a second, full
/// owner-facing detail endpoint — there is no public-safe
/// `GET /api/v1/stories/{id}/` route at all (`StoryListCreateView`'s
/// GET is the owner's own authenticated list, not a public detail
/// route) — so there is no "extra keys simply never read" concern to
/// document here the way those two DTOs' docstrings do.
library;

import '../../domain/public_story_entity.dart';

class StoryPublicResponseDto {
  const StoryPublicResponseDto({
    required this.id,
    required this.business,
    required this.media,
    required this.publishedAt,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoryPublicResponseDto.fromJson(Map<String, dynamic> json) {
    return StoryPublicResponseDto(
      id: json['id'] as int,
      business: json['business'] as int,
      media: json['media'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
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
  final String media;
  final DateTime publishedAt;
  final DateTime expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PublicStory toEntity() {
    return PublicStory(
      id: id,
      businessId: business,
      mediaUrl: media,
      publishedAt: publishedAt,
      expiresAt: expiresAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}