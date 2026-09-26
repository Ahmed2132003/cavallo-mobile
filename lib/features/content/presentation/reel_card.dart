import 'package:flutter/material.dart';

import '../domain/public_reel_entity.dart';
import '../../social/presentation/content_action_row.dart';
import '../../social/presentation/content_overflow_menu.dart';

/// Part P-045 scope: same role as [PostCard] for a published [PublicReel].
/// Reusable, no parent-screen dependency, business identity is text only.
///
/// Part P-058 update: same [ContentActionRow] + Report "..." menu wiring as
/// `PostCard`, with `contentType: 'reel'`.
class ReelCard extends StatelessWidget {
  const ReelCard({
    super.key,
    required this.reel,
    required this.businessName,
    this.onTap,
  });

  final PublicReel reel;
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
            _ReelThumbnail(thumbnailUrl: reel.thumbnailUrl),
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
                  ContentOverflowMenu(contentType: 'reel', objectId: reel.id),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                reel.caption,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ContentActionRow(
              contentType: 'reel',
              objectId: reel.id,
              onCommentTap: () => onTap?.call(),
              isLiked: reel.isLiked,
              isSaved: reel.isSaved,
              likesCount: reel.likesCount,
              commentsCount: reel.commentsCount,
              sharesCount: reel.sharesCount,
              updatedAt: reel.updatedAt,
            ),
          ],
        ),
      ),
    );
  }
}

/// Thumbnail + play-icon overlay, with the same neutral-fallback convention
/// as `PostCard`'s `_PostImage`. Deliberately duplicated, not shared.
class _ReelThumbnail extends StatelessWidget {
  const _ReelThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final url = thumbnailUrl;

    Widget placeholder(IconData icon) => Container(
      color: surface,
      alignment: Alignment.center,
      child: Icon(icon, size: 40),
    );

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          (url == null || url.isEmpty)
              ? placeholder(Icons.movie_outlined)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      placeholder(Icons.broken_image_outlined),
                ),
          const _PlayIconOverlay(),
        ],
      ),
    );
  }
}

class _PlayIconOverlay extends StatelessWidget {
  const _PlayIconOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(10),
        child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
      ),
    );
  }
}