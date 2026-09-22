/// Pure JSON mirror of `content.serializers.PostSerializer`'s exact
/// real read shape (Parts P-041/P-044, confirmed by reading
/// `content/serializers.py` on GitHub — not guessed):
/// `{id, business, caption, image, status, rejection_reason,
/// created_at, updated_at}`.
///
/// `business` is a bare id (`int`), never a nested object — same
/// `businessId`-only convention as `ProductResponseDto` (Part P-033).
library;

import '../../domain/moderation_status.dart';
import '../../domain/post_entity.dart';

class PostResponseDto {
  const PostResponseDto({
    required this.id,
    required this.business,
    required this.caption,
    required this.image,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostResponseDto.fromJson(Map<String, dynamic> json) {
    return PostResponseDto(
      id: json['id'] as int,
      business: json['business'] as int,
      caption: json['caption'] as String,
      image: json['image'] as String?,
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
  final String? image;
  final String status;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Post toEntity() {
    return Post(
      id: id,
      businessId: business,
      caption: caption,
      imageUrl: image,
      status: ModerationStatus.fromWire(status),
      rejectionReason: rejectionReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}