import 'package:flutter/material.dart';

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
/// Colors come from the active [ColorScheme] (AppTheme, P-006) so it
/// follows the theme and any later brand restyle.
class FeaturedBadge extends StatelessWidget {
  const FeaturedBadge({super.key});

  /// The visible (and screen-reader) text. Public so tests can reference it.
  static const String label = 'Featured';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
