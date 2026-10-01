// lib/features/business_console/presentation/business_console_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../stories/presentation/story_upload_queue_provider.dart';
import '../../stories/presentation/story_upload_status_banner.dart';

/// Part P-083 — the Business Console navigational home.
///
/// Wraps the four branches of the `/business-console`
/// `StatefulShellRoute.indexedStack` (wired in `app_router.dart` by
/// the routing owner, not here):
///
/// | index | label        | destination key                    |
/// |-------|--------------|------------------------------------|
/// | 0     | Products     | `business-console-nav-products`    |
/// | 1     | Posts/Reels  | `business-console-nav-content`     |
/// | 2     | Stories      | `business-console-nav-stories`     |
/// | 3     | Analytics    | `business-console-nav-analytics`   |
///
/// Order, labels and keys are the P-083 shared contract — do not
/// change them without changing every consumer (router, tests).
///
/// ### Decisions
///
/// * **No AppBar (D1).** Each branch root screen keeps its own
///   `AppBar`; a shell-level one would stack two app bars.
/// * **Upload banner lives here (D3).** `StoryUploadStatusBanner` is
///   shown above every tab, which is the "root-level shell" that
///   P-051's FLAGGED SCOPE DECISION 6 deferred to this phase. The
///   banner widget itself is not modified; this shell only decides
///   where it sits.
/// * **Status-bar handling.** Without an AppBar the banner would sit
///   under the status bar, so while uploads exist it is wrapped in a
///   top `SafeArea`. The branch content is then told the top inset is
///   already consumed (`MediaQuery.removePadding(removeTop: true)`),
///   otherwise each tab's own `AppBar` would add the status-bar
///   height a second time and leave a gap under the banner. When the
///   queue is empty nothing is consumed and each tab handles the
///   status bar itself.
/// * **Stable tree.** The `Column` always has the same two children in
///   the same positions and the `MediaQuery.removePadding` wrapper is
///   always present (only `removeTop` changes), so the banner
///   appearing or disappearing never remounts [navigationShell] and
///   never discards the state of the tabs.
/// * **No access control here.** Who may reach `/business-console` is
///   enforced by the router's `redirect`, not by this widget.
class BusinessConsoleShell extends ConsumerWidget {
  const BusinessConsoleShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `select` so the shell only rebuilds when the banner needs to
    // appear/disappear, not on every attempt/status change of a task
    // (the banner widget watches the full queue itself).
    final hasUploads = ref.watch(
      storyUploadQueueProvider.select((tasks) => tasks.isNotEmpty),
    );

    return Scaffold(
      body: Column(
        children: [
          if (hasUploads)
            const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: StoryUploadStatusBanner(),
              ),
            )
          else
            const SizedBox.shrink(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: hasUploads,
              child: navigationShell,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('business-console-nav-bar'),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected:
            (index) => navigationShell.goBranch(
              index,
              // Tapping the tab you are already on pops it back to its
              // branch root, the standard bottom-nav behaviour.
              initialLocation: index == navigationShell.currentIndex,
            ),
        destinations: const [
          NavigationDestination(
            key: Key('business-console-nav-products'),
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            key: Key('business-console-nav-content'),
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Posts/Reels',
          ),
          NavigationDestination(
            key: Key('business-console-nav-stories'),
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Stories',
          ),
          NavigationDestination(
            key: Key('business-console-nav-analytics'),
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
