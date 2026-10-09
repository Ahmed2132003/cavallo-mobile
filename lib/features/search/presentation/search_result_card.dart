/// Part P-065 STEP 4 scope: [SearchResultCard] - renders one row of the
/// Search results list, dispatching on [SearchResult]'s two variants
/// (STEP 1). [onTap] is a plain [VoidCallback], not a `context.pushNamed`
/// call made internally - same convention `PostCard`/`ReelCard`
/// (Part P-045) already use, and for the same reason: it keeps this
/// widget free of any `GoRouter` dependency, and lets a widget test
/// verify a tap without needing a real router in the tree.
///
/// ### Price - always through [ProductPriceFraming] (Part P-034)
///
/// The product row's price is rendered ONLY via [ProductPriceFraming]
/// (`products/presentation/product_price_framing.dart`). No new price text is
/// written here.
///
/// ### Business row - only real fields, no invented ones
///
/// `BusinessProfile` has no `rating`/`logo` field today, so this row shows
/// only what the entity carries: name, type, city/country, `isVerified`,
/// `isFeatured` and `followerCount`.
///
/// ### Part P-114 STEP 3B (presentation only)
///
/// * Instagram-style row: [AppAvatar], name with Verified mark and the single
///   [FeaturedBadge], a secondary line, a hairline under the row (no Card).
/// * Featured results carry the amber badge with the word "Featured"; organic
///   results use exactly the same row without it (nothing is hidden or
///   re-ordered here).
/// * Every string comes from the ARB files; counts use [AppFormatters].
/// * Directional layout only; the chevron mirrors in Arabic.
/// * Each row is at least 72 logical pixels tall (tap target >= 44).
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/l10n/rtl_helpers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/featured_badge.dart';
import '../../../core/widgets/grid_tile_media.dart';
import '../../business_profile/domain/business_profile_entity.dart';
import '../../products/domain/product_entity.dart';
import '../../products/presentation/product_price_framing.dart';
import '../domain/search_result_entity.dart';

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({
    super.key,
    required this.result,
    required this.onTap,
  });

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return switch (result) {
      BusinessSearchResult(:final business) => _BusinessResultRow(
        business: business,
        onTap: onTap,
      ),
      ProductSearchResult(:final product) => _ProductResultRow(
        product: product,
        onTap: onTap,
      ),
    };
  }
}

/// The shared frame of both rows: tappable, 72 px minimum, hairline below.
class _ResultRowFrame extends StatelessWidget {
  const _ResultRowFrame({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outline, width: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
            child: Row(
              children: <Widget>[
                Expanded(child: child),
                const SizedBox(width: 8),
                DirectionalIcon(
                  Icons.chevron_right,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessResultRow extends StatelessWidget {
  const _BusinessResultRow({required this.business, required this.onTap});

  final BusinessProfile business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final l10n = context.l10n;
    final AppFormatters formatters = AppFormatters(l10n);

    final String typeLabel =
        business.businessType == BusinessType.trader
            ? l10n.businessTypeTrader
            : l10n.businessTypeFactory;
    final String locationLabel;
    if (business.city.isNotEmpty && business.country.isNotEmpty) {
      locationLabel = l10n.profileLocation(business.city, business.country);
    } else {
      locationLabel =
          business.city.isNotEmpty ? business.city : business.country;
    }
    final String subtitle =
        locationLabel.isEmpty ? typeLabel : '$typeLabel \u2022 $locationLabel';
    final int followers = business.followerCount;

    return _ResultRowFrame(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          AppAvatar(
            name: business.businessName,
            size: 52,
            ringGapColor: colors.background,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        business.businessName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (business.isVerified) ...<Widget>[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: colors.brand,
                        semanticLabel: l10n.feedVerifiedLabel,
                      ),
                    ],
                    // Part P-110: display-only Featured badge.
                    if (business.isFeatured) ...<Widget>[
                      const SizedBox(width: 6),
                      const FeaturedBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.followersCountLine(
                    followers,
                    formatters.compactCount(followers),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductResultRow extends StatelessWidget {
  const _ProductResultRow({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _ResultRowFrame(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 64,
            height: 64,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GridTileMedia(
                imageUrl: product.imageUrl,
                semanticLabel: product.name,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        product.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Part P-110: display-only; reflects whether the
                    // OWNING BUSINESS is Featured.
                    if (product.isFeatured) ...<Widget>[
                      const SizedBox(width: 6),
                      const FeaturedBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // The ONLY place this row renders a price - always through
                // ProductPriceFraming (Part P-034).
                ProductPriceFraming(
                  price: product.price,
                  currency: product.currency,
                  compact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
