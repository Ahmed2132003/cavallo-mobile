/// Parses the read-only, public-safe Post shape.
///
/// Used two ways by `PostPublicRepositoryImpl` (STEP 1):
/// * `GET /api/v1/posts/public/` (`content.serializers.
///   PostPublicSerializer`, Part P-043) — exactly the fields below,
///   nothing more: `{id, business, caption, image, created_at,
///   updated_at}`.
/// * `GET /api/v1/posts/{id}/` (`content.serializers.PostSerializer`,
///   the full owner-facing shape) — a strict superset of the same
///   fields, PLUS `status`/`rejection_reason`. Those two extra keys
///   are simply never read here: this DTO's schema is "public-safe
///   fields only", so parsing the detail response through it naturally
///   drops the moderation metadata at the boundary rather than needing
///   a second, near-identical DTO class. `PostPublicRepositoryImpl`
///   reads `json['status']` itself, directly off the raw map, BEFORE
///   calling this DTO — see that file for why.
library;

import '../../domain/public_post_entity.dart';

class PostPublicResponseDto {
  const PostPublicResponseDto({
    required this.id,
    required this.business,
    required this.caption,
    required this.image,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostPublicResponseDto.fromJson(Map<String, dynamic> json) {
    return PostPublicResponseDto(
      id: json['id'] as int,
      business: json['business'] as int,
      caption: json['caption'] as String,
      image: json['image'] as String?,
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
  final String? image;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PublicPost toEntity() {
    return PublicPost(
      id: id,
      businessId: business,
      caption: caption,
      imageUrl: image,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}