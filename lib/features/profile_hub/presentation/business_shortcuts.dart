import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';

/// Part P-113 (STEP 4B): the Business shortcuts under the header of the
/// Profile & Settings hub (tab 5).
///
/// Four icon buttons - Products, Content, Stories, Analytics - each opening
/// the same screen as the matching row of the "Business tools" group, one tap
/// from the tab. They carry a tooltip (and so an accessibility label) instead
/// of visible text, so the hub does not show the same words twice.
///
/// The hub draws this widget for Business accounts only. A tap pushes the
/// screen above the shell, so back returns to the hub. Who may open those
/// screens is still decided by the router redirect guards.
class BusinessShortcuts extends StatelessWidget {
  const BusinessShortcuts({super.key});

  /// The destinations, in display order.
  static const List<String> routeNames = <String>[
    RouteNames.productList,
    RouteNames.contentList,
    RouteNames.storyList,
    RouteNames.businessAnalytics,
  ];

  /// Key of the shortcut that opens [routeName].
  static Key shortcutKey(String routeName) => Key('hub-shortcut-$routeName');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    Widget shortcut(String routeName, IconData icon, String label) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: IconButton.filledTonal(
          key: shortcutKey(routeName),
          icon: Icon(icon),
          tooltip: label,
          onPressed: () => context.pushNamed(routeName),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: Row(
        children: <Widget>[
          shortcut(
            RouteNames.productList,
            Icons.inventory_2_outlined,
            l10n.hubProducts,
          ),
          shortcut(
            RouteNames.contentList,
            Icons.photo_library_outlined,
            l10n.hubContent,
          ),
          shortcut(
            RouteNames.storyList,
            Icons.auto_stories_outlined,
            l10n.hubStories,
          ),
          shortcut(
            RouteNames.businessAnalytics,
            Icons.insights_outlined,
            l10n.hubAnalytics,
          ),
        ],
      ),
    );
  }
}
