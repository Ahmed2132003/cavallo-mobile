import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_entity.dart';
import '../../features/auth/presentation/session_provider.dart';
import '../../routing/navigation_manifest.dart';
import 'app_bottom_bar.dart';
import 'shell_branches.dart';

/// Part P-113 (STEP 2A, back behaviour added in STEP 2B): the app shell - the
/// persistent frame around the five tabs.
///
/// It wraps the branches of the app's `StatefulShellRoute.indexedStack`
/// (declared in `app_router.dart`) and adds the bottom bar for the signed-in
/// account type. Each branch keeps its own navigator, so every tab remembers
/// its back stack and scroll position.
///
/// ## Back button (STEP 2B)
///
/// System back on a tab root returns to the Home tab first, and only from
/// Home does it leave the app:
/// * a screen pushed INSIDE a tab is popped first (the tab's own navigator
///   handles that before this widget is asked);
/// * on any other tab root, back switches to the Home tab;
/// * on the Home tab root, back is not intercepted (the app exits).
///
/// ## What it does NOT do
/// * It does not grant or deny access. Who may open which route is decided by
///   the router `redirect` guards (auth, business onboarding, business
///   console, moderator), which P-113 leaves untouched. The shell sits inside
///   them.
/// * It has no top bar. Each tab root keeps its own AppBar; the Home top bar
///   with the bell and chats badges is STEP 4.
/// * It does no polling and builds no badge counts yet (STEP 7 passes the
///   Staff pending count).
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

  /// Opens the Business create sheet. Wired in STEP 7; until then the Business
  /// "+" tab calls nothing.
  final VoidCallback? onCreateTap;

  /// Badge counts by destination id, forwarded to [AppBottomBar].
  final Map<String, int> badgeCounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<User?> session = ref.watch(sessionProvider);
    final User? user = switch (session) {
      AsyncData(:final value) => value,
      _ => null,
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
            user == null
                ? null
                : AppBottomBar(
                  audience: navAudienceForUser(user),
                  currentBranch: navigationShell.currentIndex,
                  onSelectBranch:
                      (int branch) => navigationShell.goBranch(
                        branch,
                        // Tapping the tab you are already on pops it back to
                        // its branch root (standard bottom-nav behaviour,
                        // same as the Business console shell).
                        initialLocation: branch == navigationShell.currentIndex,
                      ),
                  onCreate: onCreateTap,
                  badgeCounts: badgeCounts,
                ),
      ),
    );
  }
}