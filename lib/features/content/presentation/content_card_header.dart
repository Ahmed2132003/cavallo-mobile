import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/featured_badge.dart';
import '../../social/presentation/content_overflow_menu.dart';

/// Part P-114 STEP 2: the header row shared by `PostCard` and `ReelCard`.
///
/// Instagram anatomy: a circular [AppAvatar], the business name in bold with
/// the blue Verified mark after it, then (at the end side) the amber
/// [FeaturedBadge] when the owning business is Featured, and the existing
/// [ContentOverflowMenu] ("..." with Report).
///
/// Presentation only: every value is passed in by the card, nothing is read
/// from a provider here. `BusinessProfile` has no logo field on the backend,
/// so the avatar shows the initials of [businessName] (same fallback as the
/// stories tray). While the name is still being resolved ([businessName]
/// empty) it shows the generic person icon.
///
/// Featured stays read-only and uses the single [FeaturedBadge] widget.
class ContentCardHeader extends StatelessWidget {
  const ContentCardHeader({
    super.key,
    required this.businessName,
    required this.contentType,
    required this.objectId,
    this.isVerified = false,
    this.isFeatured = false,
  });

  final String businessName;

  /// `"post"` or `"reel"` (the wire value `ContentOverflowMenu` reports with).
  final String contentType;
  final int objectId;

  /// Shows the blue Verified mark after the name.
  final bool isVerified;

  /// Shows the amber [FeaturedBadge] (the OWNING business is Featured).
  final bool isFeatured;

  static const double avatarSize = 32;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextStyle nameStyle = (Theme.of(context).textTheme.labelLarge ??
            const TextStyle())
        .copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 0, 8),
      child: Row(
        children: <Widget>[
          AppAvatar(name: businessName, size: avatarSize),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    businessName,
                    style: nameStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isVerified) ...<Widget>[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.verified,
                    key: const ValueKey<String>('content_card_verified_mark'),
                    size: 16,
                    color: colors.brand,
                    semanticLabel: context.l10n.feedVerifiedLabel,
                  ),
                ],
              ],
            ),
          ),
          // Part P-110: display-only; shown when the OWNING business is
          // Featured. Every caller (Home feed, Discover, chat shares,
          // business profile) inherits it from here.
          if (isFeatured) ...<Widget>[
            const SizedBox(width: 8),
            const FeaturedBadge(),
          ],
          ContentOverflowMenu(contentType: contentType, objectId: objectId),
        ],
      ),
    );
  }
}
