import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
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
/// ## Auth guard — Phase 3 TODO
/// Real authentication doesn't exist until Phase 3 (Part P-018/P-021 build
/// the login flow; Part P-022 handles token refresh). This part only wires
/// the *mechanism* the guard will use once that lands — the `redirect`
/// callback below currently always returns `null` (never redirects).
///
/// [_sessionPlaceholderProvider] stands in for whatever real session
/// provider Phase 3 ultimately defines (originally expected from P-008;
/// P-008 has not run as of this part, so this placeholder type is a
/// reasonable stand-in — see the handoff note in PROJECT_PROGRESS.md).
/// Its type here, `AsyncValue<Object?>`, mirrors the eventual
/// `AsyncValue<User?>`-shaped provider:
///   - `AsyncValue.loading()`  — a stored session is still being restored
///     (e.g. reading a refresh token from secure storage on cold start)
///   - `AsyncValue.data(user)` — resolved (`null` = signed out, a `User` =
///     signed in)
///   - `AsyncValue.error(...)` — restoring the session failed
///
/// When the real provider exists: replace [_sessionPlaceholderProvider]
/// with it (or delete this placeholder and `ref.watch` the real provider
/// directly inside [appRouterProvider]), then fill in the `redirect`
/// callback body. That is the *only* change Phase 3 needs to make in this
/// file — every feature screen already navigates via the named routes in
/// [RouteNames] and will not need touching.
final _sessionPlaceholderProvider = Provider<AsyncValue<Object?>>((ref) {
  return const AsyncValue.data(null);
});

/// Exposes the app's [GoRouter] as a Riverpod provider (rather than a
/// static/global instance) so that once [_sessionPlaceholderProvider] is
/// replaced by a real, live-updating session provider, watching it here
/// makes this provider — and therefore the router's redirect evaluation —
/// automatically react to auth-state changes. No `refreshListenable`
/// plumbing is needed; Riverpod's own rebuild mechanism covers it.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Watched (not read once) on purpose — see class-level doc above.
  ref.watch(_sessionPlaceholderProvider);

  return GoRouter(
    initialLocation: RouteNames.splashPath,
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      // TODO(Phase 3): gate routes based on real auth session state once
      // Part P-018/P-021 exist, e.g.:
      //   final session = ref.watch(realSessionProvider);
      //   final isLoggedIn = session.valueOrNull != null;
      //   final isAuthRoute = state.matchedLocation == RouteNames.loginPath
      //       || state.matchedLocation == RouteNames.registerPath;
      //   if (!isLoggedIn && !isAuthRoute) return RouteNames.loginPath;
      //   if (isLoggedIn && isAuthRoute) return RouteNames.homePath;
      // Currently always allows navigation — no redirect performed.
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
