import 'package:flutter/material.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/expandable_caption.dart';
import '../../../core/widgets/media_carousel.dart';
import '../domain/public_post_entity.dart';
import '../../social/presentation/content_action_row.dart';
import 'content_card_header.dart';

/// Part P-045 scope: a reusable, customer-facing presentation of a single
/// published [PublicPost]. Every value it needs (the post, the business
/// display name, the tap callback) is passed in by the caller, so Phase 10's
/// Feed can reuse it unmodified.
///
/// `businessAvatarUrl` is deliberately not a parameter: `BusinessProfile`
/// has no logo/avatar field on the backend yet, so the avatar shows the
/// initials of the business name.
///
/// Part P-058 update: the action row is [ContentActionRow] (real Like/Save/
/// Share), and the business row ends with a "..." menu offering Report.
/// The Comment icon reuses [onTap] (open the detail screen).
///
/// Part P-114 STEP 2 (presentation only, same constructor plus one optional
/// flag): the Instagram-style post anatomy in Cavallo Blue.
///   1. [ContentCardHeader]: avatar, name, Verified, Featured badge, "..." menu.
///   2. Media in a FIXED 1:1 box ([MediaCarousel]) so the list never jumps
///      while the image loads; an [AppShimmerBox] skeleton shows meanwhile.
///   3. Action row: Like, Comment, Share at the start, Save at the end, then
///      the likes line, the caption (expandable "more") and the
///      "View all N comments" link, all inside [ContentActionRow]
///      (`showSummaryLines`) because it owns the live like/comment counts.
///   4. Relative time ("3 hours ago") from `createdAt`, through
///      [AppFormatters] only.
/// The whole card still opens the detail screen through [onTap]. No comment
/// preview is shown: the feed payload carries no comments and this part adds
/// no provider.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.businessName,
    this.onTap,
    this.isBusinessVerified = false,
  });

  final PublicPost post;
  final String businessName;
  final VoidCallback? onTap;

  /// Part P-114 STEP 2: shows the blue Verified mark after the business name.
  /// The caller resolves it (the Home feed reads the public business profile);
  /// callers that do not know it keep the default and show no mark.
  final bool isBusinessVerified;

  /// Post media box: width divided by height (1:1, Instagram square).
  static const double mediaAspectRatio = 1;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final String? imageUrl = post.imageUrl;
    final List<String> imageUrls =
        (imageUrl == null || imageUrl.isEmpty)
            ? const <String>[]
            : <String>[imageUrl];
    final DateTime? createdAt = post.createdAt;

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
              contentType: 'post',
              objectId: post.id,
              isVerified: isBusinessVerified,
              isFeatured: post.isFeatured,
            ),
            MediaCarousel(
              imageUrls: imageUrls,
              aspectRatio: mediaAspectRatio,
              semanticLabel:
                  businessName.isEmpty
                      ? null
                      : context.l10n.feedPostMediaLabel(businessName),
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
              showSummaryLines: true,
              summaryCaption:
                  post.caption.isEmpty
                      ? null
                      : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ExpandableCaption(text: post.caption),
                      ),
            ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 2, 12, 0),
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
