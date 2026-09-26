import 'package:flutter/material.dart';

import '../domain/public_post_entity.dart';
import '../../social/presentation/content_action_row.dart';
import '../../social/presentation/content_overflow_menu.dart';

/// Part P-045 scope: a reusable, customer-facing presentation of a single
/// published [PublicPost]. Every value it needs (the post, the business
/// display name, the tap callback) is passed in by the caller, so Phase 10's
/// Feed can reuse it unmodified.
///
/// `businessAvatarUrl` is deliberately not a parameter: `BusinessProfile`
/// has no logo/avatar field on the backend yet, so business identity is
/// text only.
///
/// Part P-058 update: the action row is [ContentActionRow] (real Like/Save/
/// Share), and the business row ends with a "..." menu offering Report.
/// The Comment icon reuses [onTap] (open the detail screen).
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.businessName,
    this.onTap,
  });

  final PublicPost post;
  final String businessName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PostImage(imageUrl: post.imageUrl),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      businessName,
                      style: theme.textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ContentOverflowMenu(contentType: 'post', objectId: post.id),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                post.caption,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ContentActionRow(
              contentType: 'post',
              objectId: post.id,
              onCommentTap: () => onTap?.call(),
              isLiked: post.isLiked,
              isSaved: post.isSaved,
              likesCount: post.likesCount,
              commentsCount: post.commentsCount,
              sharesCount: post.sharesCount,
              updatedAt: post.updatedAt,
            ),
          ],
        ),
      ),
    );
  }
}

/// Media area with a neutral fallback for "no image" and for a URL that
/// fails to load. Deliberately a local, duplicated widget (same precedent as
/// `_ProductThumbnail` in the business profile screen).
class _PostImage extends StatelessWidget {
  const _PostImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final url = imageUrl;

    Widget placeholder(IconData icon) => Container(
      color: surface,
      alignment: Alignment.center,
      child: Icon(icon, size: 40),
    );

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: (url == null || url.isEmpty)
          ? placeholder(Icons.image_outlined)
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) =>
                  placeholder(Icons.broken_image_outlined),
            ),
    );
  }
}