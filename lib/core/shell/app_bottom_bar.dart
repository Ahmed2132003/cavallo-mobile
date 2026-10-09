import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../routing/navigation_manifest.dart';
import '../../routing/route_names.dart';
import '../l10n/formatters.dart';
import '../l10n/l10n_context.dart';
import '../theme/app_colors.dart';
import 'shell_branches.dart';

/// Part P-113 (STEP 2A): the persistent bottom navigation bar.
///
/// The tabs are NOT written here. They come from the navigation manifest
/// ([bottomTabsFor]), so the manifest stays the single source of truth for
/// what each account type sees (locked P-113 table):
///
/// | slot | Customer | Business (Trader/Factory) | Staff / Moderator |
/// |------|----------|---------------------------|-------------------|
/// | 1    | Home     | Home                      | Home              |
/// | 2    | Explore  | Explore                   | Explore           |
/// | 3    | Saved    | Create (+)                | Moderation        |
/// | 4    | Chats    | Chats                     | Chats             |
/// | 5    | Profile  | Profile                   | Profile           |
///
/// This widget is deliberately free of GoRouter and Riverpod: it receives
/// the audience, the current shell branch and callbacks. `AppShell` connects
/// it to the router and the session.
///
/// * A tab that is a branch calls [onSelectBranch] with the branch index
///   ([ShellBranch]). The shell decides what that means (switch tab, or pop
///   the tab back to its root when it is already selected).
/// * The Business "+" tab is an action, not a branch: it calls [onCreate]
///   and never becomes the selected tab.
/// * [badgeCounts] maps a destination id (a `RouteNames` value) to a count.
///   A count above zero draws a brand-blue badge on that tab (used for the
///   Staff moderation tab in STEP 7). Counts are passed in; this widget does
///   no polling of its own.
///
/// Every colour comes from the theme tokens, every label from ARB. There is
/// no left/right anywhere; the bar mirrors automatically in Arabic.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    required this.audience,
    required this.currentBranch,
    required this.onSelectBranch,
    this.onCreate,
    this.badgeCounts = const <String, int>{},
    super.key,
  });

  final NavAudience audience;

  /// The shell branch that is currently showing (a [ShellBranch] value).
  final int currentBranch;

  final ValueChanged<int> onSelectBranch;

  /// Called when the Business "+" tab is tapped. Null means "not wired yet".
  final VoidCallback? onCreate;

  final Map<String, int> badgeCounts;

  /// Key of the bar itself.
  static const Key barKey = Key('app-nav-bar');

  /// Key of the tab for [destinationId] (a `RouteNames` value, or
  /// [kNavCreateId] for the Business "+").
  static Key tabKey(String destinationId) => Key('app-nav-$destinationId');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.appColors;
    final AppFormatters formatters = AppFormatters(l10n);
    final List<MapEntry<NavDestination, NavEntry>> tabs = bottomTabsFor(
      audience,
    );

    int selectedIndex = 0;
    for (int i = 0; i < tabs.length; i++) {
      final int? branch = ShellBranch.forRouteName(tabs[i].key.routeName);
      if (branch != null && branch == currentBranch) {
        selectedIndex = i;
      }
    }

    return NavigationBar(
      key: barKey,
      selectedIndex: selectedIndex,
      onDestinationSelected: (int index) {
        final int? branch = ShellBranch.forRouteName(tabs[index].key.routeName);
        if (branch == null) {
          onCreate?.call();
          return;
        }
        onSelectBranch(branch);
      },
      destinations: <Widget>[
        for (final MapEntry<NavDestination, NavEntry> tab in tabs)
          _destination(
            id: tab.key.id,
            l10n: l10n,
            colors: colors,
            formatters: formatters,
          ),
      ],
    );
  }

  Widget _destination({
    required String id,
    required AppLocalizations l10n,
    required AppColors colors,
    required AppFormatters formatters,
  }) {
    final _TabSpec spec = _specFor(id);
    final int count = badgeCounts[id] ?? 0;

    Widget icon(IconData data) {
      final Widget base = Icon(data);
      if (count <= 0) {
        return base;
      }
      return Badge(
        backgroundColor: colors.brand,
        textColor: colors.onBrand,
        label: Text(formatters.compactCount(count)),
        child: base,
      );
    }

    return NavigationDestination(
      key: tabKey(id),
      icon: icon(spec.icon),
      selectedIcon: icon(spec.selectedIcon),
      label: spec.label(l10n),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l10n) label;
}

/// Icon pair and label of each destination that can appear in a bottom bar.
/// A destination that reaches the bar through the manifest but is missing
/// here is a programming error, caught by the tests.
final Map<String, _TabSpec> _tabSpecs = <String, _TabSpec>{
  RouteNames.home: _TabSpec(
    Icons.home_outlined,
    Icons.home,
    (AppLocalizations l10n) => l10n.navHome,
  ),
  RouteNames.discover: _TabSpec(
    Icons.explore_outlined,
    Icons.explore,
    (AppLocalizations l10n) => l10n.navExplore,
  ),
  RouteNames.saved: _TabSpec(
    Icons.bookmark_border,
    Icons.bookmark,
    (AppLocalizations l10n) => l10n.navSaved,
  ),
  kNavCreateId: _TabSpec(
    Icons.add_box_outlined,
    Icons.add_box,
    (AppLocalizations l10n) => l10n.navCreate,
  ),
  RouteNames.moderation: _TabSpec(
    Icons.shield_outlined,
    Icons.shield,
    (AppLocalizations l10n) => l10n.navModeration,
  ),
  RouteNames.chatList: _TabSpec(
    Icons.chat_bubble_outline,
    Icons.chat_bubble,
    (AppLocalizations l10n) => l10n.navChats,
  ),
  RouteNames.profile: _TabSpec(
    Icons.person_outline,
    Icons.person,
    (AppLocalizations l10n) => l10n.navProfile,
  ),
};

_TabSpec _specFor(String id) {
  final _TabSpec? spec = _tabSpecs[id];
  if (spec == null) {
    throw StateError(
      'AppBottomBar: no icon/label registered for bottom-bar destination "$id".',
    );
  }
  return spec;
}

/// Ids that [AppBottomBar] knows how to draw. Exposed for the tests that keep
/// the manifest and the bar in sync.
Set<String> get appBottomBarKnownIds => _tabSpecs.keys.toSet();
