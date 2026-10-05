import 'package:flutter/material.dart';

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
class FeaturedBadge extends StatelessWidget {
  const FeaturedBadge({super.key});

  /// The visible (and screen-reader) text. Public so tests can reference it.
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
            label,
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
