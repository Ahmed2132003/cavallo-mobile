import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_colors.dart';

/// Part P-110: the single, reusable, READ-ONLY "Featured" badge (a star icon
/// plus the word "Featured").
///
/// Every screen that shows a business or its content uses THIS widget
/// whenever the backend says the owning business is Featured (real state
/// from P-087): public profile, search results, and Post/Reel cards (which
/// the Home feed, Discover and chat shares all reuse). Do not create a
/// second, slightly different badge elsewhere.
///
/// Display-only (ADR-006): it takes no callback, is not tappable and never
/// leads to any purchase flow. Featured is bought on the future Web
/// Dashboard, never inside this app. Callers decide WHETHER to show it:
///
/// ```dart
/// if (business.isFeatured) const FeaturedBadge(),
/// ```
///
/// Part P-111: amber `featured` fill with the dark `onFeatured` label, taken
/// from [AppColors]. Amber is reserved for Featured/Sponsored so it is never
/// confused with the blue brand or the blue Follow action.
///
/// Part P-114 STEP 3B: the visible word now comes from the ARB files
/// (`featuredBadgeLabel`), so Arabic shows the Arabic word. English is still
/// exactly [label].
class FeaturedBadge extends StatelessWidget {
  const FeaturedBadge({super.key});

  /// The English text. Public so tests can reference it. In another language
  /// the badge shows `featuredBadgeLabel` of that language instead.
  static const String label = 'Featured';

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelSmall;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.featured,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.star, size: 14, color: colors.onFeatured),
          const SizedBox(width: 4),
          Text(
            context.l10n.featuredBadgeLabel,
            style: labelStyle?.copyWith(
              color: colors.onFeatured,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
