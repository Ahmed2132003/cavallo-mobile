import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/session_provider.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/business_console/presentation/business_console_screen.dart';
import '../features/business_profile/presentation/business_profile_screen.dart';
import '../features/chat/presentation/chat_list_screen.dart';
import '../features/chat/presentation/chat_thread_screen.dart';
import '../features/discover/presentation/discover_screen.dart';
import '../features/feed/presentation/home_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/products/presentation/product_detail_screen.dart';
import '../features/search/presentation/search_screen.dart';
import 'route_names.dart';

/// Part P-007 scope: wires the app's single [GoRouter] instance and its
/// route table. Every feature screen must be reached through this router —
/// no feature should build or push its own separate `Navigator`.
///
/// ## Auth guard — resolved in Part P-021b
/// P-007 left the `redirect` callback below as a stub (`TODO(Phase 3)`,
/// always returning `null`) backed by a fake `_sessionPlaceholderProvider`
/// that never changed. Part P-021b replaces that placeholder with the real
/// [sessionProvider] (`SessionNotifier`, Part P-021a) and fills in the
/// redirect logic.
///
/// Routes are split into two groups:
/// * **Public** (`_publicRoutes`): `/login`, `/register` — reachable only
///   while signed out.
/// * **Protected** (everything else — `home`, `discover`, `search`,
///   `businessProfile`, `productDetail`, `chatList`, `chatThread`,
///   `notifications`, `businessConsole`): reachable only while signed in.
///
/// `splash` (`/`) is deliberately in neither list — see the dedicated note
/// further down, on the `redirect` callback itself.
///
/// ## ⚠️ Corrected after real-device testing — `refreshListenable`, not `ref.watch`
///
/// P-007's original design called `ref.watch(sessionProvider)` directly
/// inside this provider's body, on the theory that "Riverpod's own
/// rebuild mechanism" would be enough — no `refreshListenable` needed.
/// P-021b initially shipped exactly that. **On the real device this broke
/// login visibly**: every time `SessionNotifier` changed `state` — even
/// the transient `AsyncValue.loading()` set the instant `login()` is
/// called — Riverpod rebuilds this whole provider, which produced an
/// entirely NEW [GoRouter] instance. A brand-new `GoRouter` always starts
/// back at [RouteNames.splashPath] (its `initialLocation`) — it has no
/// memory of "I was on `/login`." The visible symptom (reported directly
/// against a real login attempt): tapping "Log in" flashed the splash
/// screen, `LoginScreen` was unmounted mid-request, and a few seconds
/// later the user landed back on `/login` with **no error message shown
/// at all** — because whatever failure/success `login()` eventually
/// produced was setting `state` on a `SessionNotifier` whose
/// `LoginScreen` observer no longer existed to react to it.
///
/// The fix: build exactly ONE [GoRouter] for the lifetime of this
/// provider (this provider's body itself never re-runs on a session
/// change), and instead give it a [_SessionRefreshListenable] via
/// `refreshListenable` — go_router's own documented mechanism for "an
/// external source of truth changed, please re-run `redirect` against
/// whatever page the user is currently on," without rebuilding the
/// router or losing the current screen. `redirect` below reads
/// [sessionProvider] with `ref.read` (a snapshot at evaluation time), not
/// `ref.watch` — watching inside `redirect` would have reintroduced the
/// same bug by making a `redirect` re-run also count as "this provider's
/// dependency changed."
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _SessionRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: RouteNames.splashPath,
    debugLogDiagnostics: true,
    refreshListenable: refreshListenable,
    redirect: (BuildContext context, GoRouterState state) {
      // Snapshot read — NOT ref.watch. See the provider-level doc above
      // for why watching here would silently reintroduce the exact bug
      // this refreshListenable rewrite fixes.
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;

      // A login/register/logout call is in flight (SessionNotifier sets
      // `state` to a bare `AsyncValue.loading()` — see session_provider.dart's
      // own docstring re: not using `copyWithPrevious`, which is `@internal`
      // on this Riverpod version). This is NOT the cold-start restore —
      // main.dart (Part P-021b) gates that case before GoRouter ever mounts,
      // so by the time this callback runs at all, `isLoading` here can only
      // mean "a screen just called login()/register()/logout() and is
      // already showing its own loading UI (e.g. AppButton's isLoading)."
      // Now that the router is a single persistent instance (see above),
      // returning null here correctly means "stay exactly where you
      // already are" — it no longer risks losing the current screen.
      if (session.isLoading) {
        return null;
      }

      // Pattern-matched rather than `session.valueOrNull` — that getter
      // isn't available on this project's pinned flutter_riverpod
      // version (3.3.2; confirmed via a real `flutter analyze` failure on
      // the real machine, not assumed). `AsyncData(:final value)` reaches
      // the same result (null-safe, no previous-value ambiguity since
      // SessionNotifier never uses `copyWithPrevious` — Part P-021a) and
      // needs no extra API.
      final isLoggedIn = switch (session) {
        AsyncData(:final value) => value != null,
        _ => false,
      };
      final isPublicRoute = _publicRoutes.contains(location);

      if (!isLoggedIn) {
        // Signed out: only /login and /register are reachable. Everything
        // else — every protected route AND splash — bounces to /login.
        return isPublicRoute ? null : RouteNames.loginPath;
      }

      // Signed in: /login and /register bounce to /home, per the spec's
      // literal example. splash is ALSO included here — a deliberate
      // addition beyond the literal spec text (which never mentioned
      // splash either way), flagged rather than silently decided: splash
      // is only ever reached as `initialLocation` on the very first
      // `GoRouter` build (cold start, already gated by main.dart) — once
      // resolved, it should behave like any other "am I allowed here"
      // check, not sit unreachable-but-also-unredirected.
      if (isPublicRoute || location == RouteNames.splashPath) {
        return RouteNames.homePath;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: RouteNames.splashPath,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.loginPath,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.registerPath,
        name: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.homePath,
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RouteNames.discoverPath,
        name: RouteNames.discover,
        builder: (context, state) => const DiscoverScreen(),
      ),
      GoRoute(
        path: RouteNames.searchPath,
        name: RouteNames.search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: RouteNames.businessProfilePath,
        name: RouteNames.businessProfile,
        builder: (context, state) {
          final id = state.pathParameters[RouteNames.idParam]!;
          return BusinessProfileScreen(businessId: id);
        },
      ),
      GoRoute(
        path: RouteNames.productDetailPath,
        name: RouteNames.productDetail,
        builder: (context, state) {
          final id = state.pathParameters[RouteNames.idParam]!;
          return ProductDetailScreen(productId: id);
        },
      ),
      GoRoute(
        path: RouteNames.chatListPath,
        name: RouteNames.chatList,
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: RouteNames.chatThreadPath,
        name: RouteNames.chatThread,
        builder: (context, state) {
          final id = state.pathParameters[RouteNames.idParam]!;
          return ChatThreadScreen(chatId: id);
        },
      ),
      GoRoute(
        path: RouteNames.notificationsPath,
        name: RouteNames.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RouteNames.businessConsolePath,
        name: RouteNames.businessConsole,
        builder: (context, state) => const BusinessConsoleScreen(),
      ),
    ],
  );
});

/// Routes reachable only while signed out. Everything else in the route
/// table is "protected" implicitly (see the `redirect` callback above) —
/// there is no separate `_protectedRoutes` list to keep in sync.
const _publicRoutes = <String>{
  RouteNames.loginPath,
  RouteNames.registerPath,
};

/// Bridges [sessionProvider] to `GoRouter`'s `refreshListenable` — the
/// piece that lets a single, persistent [GoRouter] re-run its `redirect`
/// callback whenever the session changes, without ever rebuilding the
/// router itself (see [appRouterProvider]'s doc comment for the real-device
/// bug this fixes). `ref.listen` here is a plain side-effect subscription,
/// not a `ref.watch` — it does NOT make [appRouterProvider] re-run when
/// [sessionProvider] changes; it only calls [notifyListeners], which
/// `GoRouter` itself is listening to.
class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(Ref ref) {
    ref.listen<AsyncValue<Object?>>(
      sessionProvider,
      (previous, next) => notifyListeners(),
    );
  }
}