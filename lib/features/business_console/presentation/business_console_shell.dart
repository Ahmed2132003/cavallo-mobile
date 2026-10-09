// lib/features/business_console/presentation/business_console_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../stories/presentation/story_upload_queue_provider.dart';
import '../../stories/presentation/story_upload_status_banner.dart';

/// Part P-083 - the Business Console navigational home.
///
/// Wraps the four branches of the `/business-console`
/// `StatefulShellRoute.indexedStack` (wired in `app_router.dart`):
///
/// | index | label        | destination key                    |
/// |-------|--------------|------------------------------------|
/// | 0     | Products     | `business-console-nav-products`    |
/// | 1     | Posts/Reels  | `business-console-nav-content`     |
/// | 2     | Stories      | `business-console-nav-stories`     |
/// | 3     | Analytics    | `business-console-nav-analytics`   |
///
/// Order and keys are the P-083 shared contract - do not change them.
/// The LABELS are localized since P-115 STEP 5 (English text is unchanged).
///
/// ### Decisions (unchanged since P-083)
///
/// * No AppBar here: each branch root keeps its own AppBar.
/// * The story upload banner lives here, above every tab. While uploads
///   exist it is wrapped in a top SafeArea and the branch content is told the
///   top inset is already consumed.
/// * Stable tree: the Column always has the same two children and the
///   MediaQuery.removePadding wrapper is always present, so the banner
///   appearing never remounts [navigationShell] or discards tab state.
/// * No access control here: the router's redirect owns that.
class BusinessConsoleShell extends ConsumerWidget {
  const BusinessConsoleShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
        destinations: [
          NavigationDestination(
            key: const Key('business-console-nav-products'),
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: l10n.consoleNavProducts,
          ),
          NavigationDestination(
            key: const Key('business-console-nav-content'),
            icon: const Icon(Icons.dynamic_feed_outlined),
            selectedIcon: const Icon(Icons.dynamic_feed),
            label: l10n.consoleNavContent,
          ),
          NavigationDestination(
            key: const Key('business-console-nav-stories'),
            icon: const Icon(Icons.auto_stories_outlined),
            selectedIcon: const Icon(Icons.auto_stories),
            label: l10n.consoleNavStories,
          ),
          NavigationDestination(
            key: const Key('business-console-nav-analytics'),
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: l10n.consoleNavAnalytics,
          ),
        ],
      ),
    );
  }
}
