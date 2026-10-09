import 'package:flutter/material.dart';

import '../l10n/rtl_helpers.dart';
import '../theme/app_colors.dart';
import 'app_shimmer_box.dart';

/// Small icon drawn in the top corner (end side) of a [GridTileMedia].
enum GridTileBadge {
  /// Nothing.
  none,

  /// A video / reel.
  video,

  /// A post with several images.
  carousel,
}

/// Part P-114 STEP 1: one tile of the 3-column grids (profile Posts / Reels /
/// Products, Explore). Fixed aspect ratio, image cropped to fill, skeleton
/// while loading, optional corner badge. Presentation only.
class GridTileMedia extends StatelessWidget {
  const GridTileMedia({
    super.key,
    this.imageUrl,
    this.aspectRatio = 1,
    this.badge = GridTileBadge.none,
    this.onTap,
    this.semanticLabel,
  });

  final String? imageUrl;

  /// Width divided by height. 1 for posts and products, 9 / 16 for reels.
  final double aspectRatio;

  final GridTileBadge badge;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? url = imageUrl;

    final Widget placeholder = ColoredBox(
      color: colors.surfaceVariant,
      child: Center(
        child: Icon(Icons.image_outlined, color: colors.textSecondary),
      ),
    );

    final Widget media =
        (url == null || url.isEmpty)
            ? placeholder
            : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: 400,
              loadingBuilder:
                  (BuildContext _, Widget child, ImageChunkEvent? progress) =>
                      progress == null
                          ? child
                          : const SizedBox.expand(
                            child: AppShimmerBox(borderRadius: 0),
                          ),
              errorBuilder:
                  (BuildContext _, Object error, StackTrace? stack) =>
                      placeholder,
            );

    final Widget tile = AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          media,
          if (badge != GridTileBadge.none)
            PositionedDirectional(
              top: 6,
              end: 6,
              child: _BadgeIcon(badge: badge),
            ),
        ],
      ),
    );

    return Semantics(
      label: semanticLabel,
      image: true,
      button: onTap != null,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.badge});

  final GridTileBadge badge;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Widget icon = switch (badge) {
      GridTileBadge.video => DirectionalIcon(
        Icons.play_arrow,
        size: 16,
        color: colors.textPrimary,
      ),
      GridTileBadge.carousel => Icon(
        Icons.collections,
        size: 16,
        color: colors.textPrimary,
      ),
      GridTileBadge.none => const SizedBox.shrink(),
    };
    return ExcludeSemantics(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface.withValues(alpha: 0.8),
        ),
        child: Center(child: icon),
      ),
    );
  }
}
