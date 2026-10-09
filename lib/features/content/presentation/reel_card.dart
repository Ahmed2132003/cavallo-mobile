import 'package:flutter/material.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../domain/public_reel_entity.dart';
import '../../social/presentation/content_action_row.dart';
import 'content_card_header.dart';

/// Part P-045 scope: same role as [PostCard] for a published [PublicReel].
/// Reusable, no parent-screen dependency, business identity is text only.
///
/// Part P-058 update: same [ContentActionRow] + Report "..." menu wiring as
/// `PostCard`, with `contentType: 'reel'`.
///
/// Part P-114 STEP 2 (presentation only, same constructor plus one optional
/// flag): Instagram-style reel anatomy.
///   1. [ContentCardHeader] (same as the post card).
///   2. 9:16 media in a FIXED box so the list never jumps while the
///      thumbnail loads; an [AppShimmerBox] skeleton shows meanwhile. The play
///      mark stays in the middle (decorative: playback belongs to the Reel
///      detail screen).
///   3. Overlaid on the media: the actions as a column at the END side
///      (Like, Comment, Share, Save, white on a dark scrim, with counts) and
///      the caption at the bottom START side. The scrim and the white are the
///      two theme-independent colours that sit on top of media, the same
///      convention as the story viewer.
///   4. Relative time under the media, through [AppFormatters] only.
/// The whole card still opens the detail screen through [onTap].
class ReelCard extends StatelessWidget {
  const ReelCard({
    super.key,
    required this.reel,
    required this.businessName,
    this.onTap,
    this.isBusinessVerified = false,
  });

  final PublicReel reel;
  final String businessName;
  final VoidCallback? onTap;

  /// Part P-114 STEP 2: shows the blue Verified mark after the business name.
  /// Same contract as `PostCard.isBusinessVerified`.
  final bool isBusinessVerified;

  /// Reel media box: width divided by height (9:16).
  static const double mediaAspectRatio = 9 / 16;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final DateTime? createdAt = reel.createdAt;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(bottom: BorderSide(color: colors.outline, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ContentCardHeader(
              businessName: businessName,
              contentType: 'reel',
              objectId: reel.id,
              isVerified: isBusinessVerified,
              isFeatured: reel.isFeatured,
            ),
            AspectRatio(
              aspectRatio: mediaAspectRatio,
              child: Semantics(
                label:
                    businessName.isEmpty
                        ? null
                        : context.l10n.feedReelMediaLabel(businessName),
                image: true,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _ReelThumbnail(thumbnailUrl: reel.thumbnailUrl),
                    const _PlayIconOverlay(),
                    const Positioned.fill(child: _BottomScrim()),
                    PositionedDirectional(
                      end: 4,
                      bottom: 12,
                      child: ContentActionRow(
                        contentType: 'reel',
                        objectId: reel.id,
                        onCommentTap: () => onTap?.call(),
                        isLiked: reel.isLiked,
                        isSaved: reel.isSaved,
                        likesCount: reel.likesCount,
                        commentsCount: reel.commentsCount,
                        sharesCount: reel.sharesCount,
                        updatedAt: reel.updatedAt,
                        overlay: true,
                      ),
                    ),
                    if (reel.caption.isNotEmpty)
                      PositionedDirectional(
                        start: 12,
                        end: 64,
                        bottom: 16,
                        child: Text(
                          reel.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(color: _reelOnMedia),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
                child: Text(
                  AppFormatters(context.l10n).relativeTime(createdAt),
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// The two theme-independent colours that sit on top of reel media: white
/// text and icons, and a black scrim behind them. They stay the same in Light
/// and Dark because the media itself does not change with the theme.
const Color _reelOnMedia = Colors.white;
final Color _reelScrim = Colors.black.withValues(alpha: 0.55);
final Color _reelPlayBackground = Colors.black.withValues(alpha: 0.45);

/// Thumbnail with the same neutral-fallback convention as before: no URL shows
/// the movie icon, a failed load shows the broken-image icon, and while the
/// image loads an [AppShimmerBox] skeleton fills the fixed 9:16 box.
class _ReelThumbnail extends StatelessWidget {
  const _ReelThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? url = thumbnailUrl;

    Widget placeholder(IconData icon) => ColoredBox(
      color: colors.surfaceVariant,
      child: Center(child: Icon(icon, size: 40, color: colors.textSecondary)),
    );

    if (url == null || url.isEmpty) {
      return placeholder(Icons.movie_outlined);
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder:
          (BuildContext _, Widget child, ImageChunkEvent? progress) =>
              progress == null
                  ? child
                  : const SizedBox.expand(
                    child: AppShimmerBox(borderRadius: 0),
                  ),
      errorBuilder:
          (BuildContext _, Object error, StackTrace? stack) =>
              placeholder(Icons.broken_image_outlined),
    );
  }
}

/// Dark gradient at the bottom of the media so the white caption and action
/// icons stay readable on any thumbnail. Vertical, so it needs no RTL logic.
class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.center,
            end: Alignment.bottomCenter,
            colors: <Color>[Colors.transparent, _reelScrim],
          ),
        ),
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
          color: _reelPlayBackground,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(10),
        child: const Icon(Icons.play_arrow, color: _reelOnMedia, size: 32),
      ),
    );
  }
}
