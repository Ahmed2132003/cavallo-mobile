import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One icon tab of [ProfileTabBar].
class ProfileTabItem {
  const ProfileTabItem({required this.icon, required this.label});

  /// Icon shown in the tab. Non-directional icons only (grid, play, bag,
  /// info): they are never mirrored.
  final IconData icon;

  /// Localized label: tooltip and screen-reader label of the icon-only tab.
  final String label;
}

/// Part P-114 STEP 1: the icon tab bar of a business profile (Posts grid,
/// Reels grid, Products grid, Info).
///
/// A thin wrapper over [TabBar]: the caller owns the [TabController], so the
/// existing tab content and providers are untouched. Colours come from
/// `context.appColors`. Tabs follow the reading direction (the first tab is at
/// the start side: right in Arabic).
class ProfileTabBar extends StatelessWidget implements PreferredSizeWidget {
  const ProfileTabBar({
    super.key,
    required this.controller,
    required this.items,
    this.onTap,
  });

  final TabController controller;
  final List<ProfileTabItem> items;
  final ValueChanged<int>? onTap;

  static const double height = 48;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outline)),
      ),
      child: TabBar(
        controller: controller,
        onTap: onTap,
        labelColor: colors.brandText,
        unselectedLabelColor: colors.textSecondary,
        indicatorColor: colors.brand,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: <Widget>[
          for (final ProfileTabItem item in items)
            Tab(
              height: height,
              child: Tooltip(message: item.label, child: Icon(item.icon)),
            ),
        ],
      ),
    );
  }
}