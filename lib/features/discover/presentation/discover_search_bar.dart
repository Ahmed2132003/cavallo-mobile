import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../routing/route_names.dart';

/// Part P-113 (STEP 6A): the visible entry point to the search screen.
///
/// A search-field look-alike that sits in the app bar of the Explore tab
/// (tab 2). It is a button, not a text field: tapping it opens the real
/// `SearchScreen` (`RouteNames.search`), which owns the typing, the
/// filters and the results. This replaces the temporary "Search (debug)"
/// entry of the Home debug menu.
class DiscoverSearchBar extends StatelessWidget {
  const DiscoverSearchBar({super.key});

  /// Key of the tappable bar.
  static const Key barKey = Key('discover-search-bar');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String hint = context.l10n.discoverSearchHint;

    return Semantics(
      button: true,
      label: hint,
      excludeSemantics: true,
      child: InkWell(
        key: barKey,
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.pushNamed(RouteNames.search),
        child: Container(
          height: 40,
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.search,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
