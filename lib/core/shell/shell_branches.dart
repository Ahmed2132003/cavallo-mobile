import '../../routing/route_names.dart';

/// Part P-113 (STEP 2A): the branch order of the app shell.
///
/// The app shell (`StatefulShellRoute.indexedStack`, wired into
/// `app_router.dart` in STEP 2B) has ONE branch per tab destination of ANY
/// account type. Each account type shows only the branches its bottom bar
/// needs, but the branch indexes are the same for everybody, so a tab keeps
/// its own back stack and scroll position no matter who is signed in.
///
/// | index | destination (route name) | shown for                    |
/// |-------|--------------------------|------------------------------|
/// | 0     | `home`                   | everyone (tab 1)             |
/// | 1     | `discover`               | everyone (tab 2, Explore)    |
/// | 2     | `saved`                  | Customer (tab 3)             |
/// | 3     | `moderation`             | Staff (tab 3)                |
/// | 4     | `chatList`               | everyone (tab 4)             |
/// | 5     | `profile`                | everyone (tab 5)             |
///
/// The Business "+" is NOT a branch: it opens the create sheet (STEP 7) and
/// never changes the current tab.
///
/// This order is a contract shared by `app_router.dart` (branch order) and
/// `app_bottom_bar.dart` (tab to branch mapping). Do not reorder it without
/// changing both.
abstract final class ShellBranch {
  static const int home = 0;
  static const int discover = 1;
  static const int saved = 2;
  static const int moderation = 3;
  static const int chats = 4;
  static const int profile = 5;

  /// Number of branches the shell route must declare.
  static const int count = 6;

  /// Route name of each branch root, indexed by branch.
  static const Map<String, int> byRouteName = <String, int>{
    RouteNames.home: home,
    RouteNames.discover: discover,
    RouteNames.saved: saved,
    RouteNames.moderation: moderation,
    RouteNames.chatList: chats,
    RouteNames.profile: profile,
  };

  /// The branch index of [routeName], or null when that route is not a tab
  /// (a create action, or a route that opens above the shell).
  static int? forRouteName(String? routeName) {
    if (routeName == null) {
      return null;
    }
    return byRouteName[routeName];
  }
}
