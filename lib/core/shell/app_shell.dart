import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_entity.dart';
import '../../features/auth/presentation/session_provider.dart';
import '../../features/moderation/presentation/moderation_provider.dart';
import '../../routing/navigation_manifest.dart';
import '../../routing/route_names.dart';
import 'app_bottom_bar.dart';
import 'create_sheet.dart';
import 'shell_branches.dart';

/// Part P-113 (STEP 2A, back behaviour STEP 2B, create sheet and moderation
/// badge STEP 4A): the app shell - the persistent frame around the tabs.
///
/// It wraps the branches of the app's `StatefulShellRoute.indexedStack`
/// (declared in `app_router.dart`) and adds the bottom bar for the signed-in
/// account type. Each branch keeps its own navigator, so every tab remembers
/// its back stack and scroll position.
///
/// ## Back button
///
/// System back on a tab root returns to the Home tab first, and only from
/// Home does it leave the app:
/// * a screen pushed INSIDE a tab is popped first;
/// * on any other tab root, back switches to the Home tab;
/// * on the Home tab root, back is not intercepted (the app exits).
///
/// ## Business "+" (STEP 4A)
///
/// Unless [onCreateTap] is given, the "+" tab opens the create sheet
/// ([showCreateSheet]). It is an action: it never changes the selected tab.
///
/// ## Moderation badge (STEP 4A)
///
/// For the Staff audience only, the shell reads the EXISTING
/// `moderationQueueProvider` and shows the number of pending items on the
/// Moderation tab. No polling and no new request are added; nothing is read
/// for other account types. Entries of [badgeCounts] win over this value.
///
/// ## What it does NOT do
/// * It does not grant or deny access. Who may open which route is decided by
///   the router `redirect` guards, which P-113 leaves untouched.
/// * It has no top bar. Each tab root keeps its own AppBar.
///
/// The audience is read from [sessionProvider] through [navAudienceForUser].
/// While no user is available (a login/logout is in flight) the bar is simply
/// not drawn; the body keeps its place in the tree, so nothing is remounted.
class AppShell extends ConsumerWidget {
  const AppShell({
    required this.navigationShell,
    this.onCreateTap,
    this.badgeCounts = const <String, int>{},
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  /// Overrides what the Business "+" tab does. Null opens the create sheet.
  final VoidCallback? onCreateTap;

  /// Badge counts by destination id, forwarded to [AppBottomBar]. They win
  /// over the counts the shell computes itself.
  final Map<String, int> badgeCounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<User?> session = ref.watch(sessionProvider);
    final User? user = switch (session) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final NavAudience? audience =
        user == null ? null : navAudienceForUser(user);

    // Staff only: the pending count of the existing moderation queue.
    final int pendingModeration =
        audience == NavAudience.staff
            ? ref.watch(
              moderationQueueProvider.select(
                (async) => switch (async) {
                  AsyncData(:final value) => value.length,
                  _ => 0,
                },
              ),
            )
            : 0;

    final Map<String, int> counts = <String, int>{
      if (pendingModeration > 0) RouteNames.moderation: pendingModeration,
      ...badgeCounts,
    };

    return PopScope(
      // Only the Home tab lets the system back button through (= exit).
      canPop: navigationShell.currentIndex == ShellBranch.home,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          navigationShell.goBranch(ShellBranch.home);
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar:
            audience == null
                ? null
                : AppBottomBar(
                  audience: audience,
                  currentBranch: navigationShell.currentIndex,
                  onSelectBranch:
                      (int branch) => navigationShell.goBranch(
                        branch,
                        // Tapping the tab you are already on pops it back to
                        // its branch root (standard bottom-nav behaviour).
                        initialLocation: branch == navigationShell.currentIndex,
                      ),
                  onCreate:
                      onCreateTap ?? () => unawaited(showCreateSheet(context)),
                  badgeCounts: counts,
                ),
      ),
    );
  }
}
