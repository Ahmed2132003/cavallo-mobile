/// Parses the read-only, public-safe Post shape.
///
/// Used two ways by `PostPublicRepositoryImpl` (STEP 1):
/// * `GET /api/v1/posts/public/` (`content.serializers.
///   PostPublicSerializer`, Part P-043) — exactly the fields below,
///   nothing more: `{id, business, caption, image, likes_count,
///   comments_count, shares_count, is_liked, is_saved, created_at,
///   updated_at}` (the five social fields added by Part BUGFIX-058).
/// * `GET /api/v1/posts/{id}/` (`content.serializers.PostSerializer`,
///   the full owner-facing shape) — a strict superset of the same
///   fields, PLUS `status`/`rejection_reason`. Those two extra keys
///   are simply never read here: this DTO's schema is "public-safe
///   fields only", so parsing the detail response through it naturally
///   drops the moderation metadata at the boundary rather than needing
///   a second, near-identical DTO class. `PostPublicRepositoryImpl`
///   reads `json['status']` itself, directly off the raw map, BEFORE
///   calling this DTO — see that file for why.
///
/// Part BUGFIX-058: `is_liked`/`is_saved`/`likes_count`/
/// `comments_count`/`shares_count` are parsed with a defensive default
/// (`false`/`0`) rather than a hard cast when the key is missing, so
/// that this DTO does not explode against an older cached response —
/// but the backend is expected to always send all five now.
library;

import '../../domain/public_post_entity.dart';

class PostPublicResponseDto {
  const PostPublicResponseDto({
    required this.id,
    required this.business,
    required this.caption,
    required this.image,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isLiked,
    required this.isSaved,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostPublicResponseDto.fromJson(Map<String, dynamic> json) {
    return PostPublicResponseDto(
      id: json['id'] as int,
      business: json['business'] as int,
      caption: json['caption'] as String,
      image: json['image'] as String?,
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
  final String? image;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLiked;
  final bool isSaved;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PublicPost toEntity() {
    return PublicPost(
      id: id,
      businessId: business,
      caption: caption,
      imageUrl: image,
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