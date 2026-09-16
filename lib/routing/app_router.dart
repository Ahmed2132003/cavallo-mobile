import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/user_entity.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/session_provider.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/business_console/presentation/business_console_screen.dart';
import '../features/business_profile/presentation/business_onboarding_screen.dart';
import '../features/business_profile/presentation/business_profile_provider.dart';
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
///   `notifications`, `businessConsole`, and — since Part P-028C1 —
///   `businessOnboarding`): reachable only while signed in.
///
/// `splash` (`/`) is deliberately in neither list — see the dedicated note
/// further down, on the `redirect` callback itself.
///
/// ## Business-account gate — added in Part P-028C1
///
/// A **second, Business-account-specific gate**, layered strictly on top
/// of the base auth gate above (per this part's own Architecture Rules —
/// "reuses the router-redirect-guard pattern established in P-021 — this
/// is a second gate, not a replacement"). It only ever runs once the base
/// gate has already confirmed the user is signed in.
///
/// Logic (see the `redirect` callback body below for the real code):
/// * If the signed-in user's `accountType` is [AccountType.business] AND
///   [businessProfileProvider] resolves to `AsyncData(null)` (a backend
///   404 on `GET /api/v1/businesses/me/`, per Part P-026 — "hasn't
///   completed onboarding yet") AND the target route isn't already
///   [RouteNames.businessOnboardingPath] itself, redirect there.
/// * A [AccountType.customer] user is never even *read* from
///   [businessProfileProvider] — see [_SessionRefreshListenable] below
///   for how this is enforced at the provider-subscription level too,
///   not just inside this `if`, per this part's own spec ("Customer-type
///   users must skip the BusinessProfile existence check entirely").
/// * While [businessProfileProvider] is still [AsyncLoading] (the very
///   first read, right after the session itself resolves) or is
///   [AsyncError] (a genuine fetch failure — distinct from "no profile
///   yet", per `BusinessProfileNotifier`'s own docstring), this gate
///   does NOT force a redirect either way — it simply lets the user stay
///   on whatever route they're already resolving to, and
///   [_SessionRefreshListenable] re-runs this whole callback the instant
///   [businessProfileProvider] settles.
///
/// ### ⚠️ Known, pre-existing blocker this part does NOT fix (flagged, not silent)
///
/// [sessionProvider]'s `User.accountType` is still the documented
/// **placeholder** from Part P-021a (`_placeholderAccountType`, always
/// [AccountType.customer] — see `session_provider.dart`'s own
/// docstring). P-028A's and P-028B's handoff notes both already flagged
/// this as a real blocker for exactly this gate, and it is **not**
/// resolved by this part (no backend `/me/`-style account endpoint or
/// JWT-decoding infra was added here — that's explicitly out of this
/// part's own scope). The gate logic below is written to be **correct**
/// once `accountType` is real, but with the placeholder in place, a
/// signed-in user's `accountType` always reads as `customer` — meaning
/// this gate structurally cannot yet fire for a real Business account on
/// a real device. See this feature's `PROJECT_PROGRESS.md` entry for
/// Part P-028C1 for the full note and the options left for Ahmed to
/// decide on.
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
/// [sessionProvider] (and, since Part P-028C1, [businessProfileProvider])
/// with `ref.read` (a snapshot at evaluation time), not `ref.watch` —
/// watching inside `redirect` would have reintroduced the same bug by
/// making a `redirect` re-run also count as "this provider's dependency
/// changed."
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
      final user = switch (session) {
        AsyncData(:final value) => value,
        _ => null,
      };
      final isLoggedIn = user != null;
      final isPublicRoute = _publicRoutes.contains(location);

      if (!isLoggedIn) {
        // Signed out: only /login and /register are reachable. Everything
        // else — every protected route AND splash — bounces to /login.
        return isPublicRoute ? null : RouteNames.loginPath;
      }

      // --- Part P-028C1: second, Business-account-specific gate ---
      // Layered strictly on top of the base auth gate immediately above —
      // never a replacement for it, and only ever evaluated once `user`
      // is known non-null. See this provider's doc comment ("Business-
      // account gate — added in Part P-028C1") for the full explanation,
      // including the pre-existing `accountType` placeholder blocker this
      // part does NOT fix.
      if (user.accountType == AccountType.business) {
        final businessProfile = ref.read(businessProfileProvider);
        final noBusinessProfileYet = switch (businessProfile) {
          AsyncData(:final value) => value == null,
          // Still loading (first read) or a genuine fetch failure —
          // neither is "confirmed no profile yet," so this gate does not
          // force a redirect either way here. `_SessionRefreshListenable`
          // re-runs this callback once `businessProfileProvider` settles
          // into AsyncData.
          _ => false,
        };
        if (noBusinessProfileYet &&
            location != RouteNames.businessOnboardingPath) {
          return RouteNames.businessOnboardingPath;
        }
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
        path: RouteNames.businessOnboardingPath,
        name: RouteNames.businessOnboarding,
        builder: (context, state) => const BusinessOnboardingScreen(),
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
const _publicRoutes = <String>{RouteNames.loginPath, RouteNames.registerPath};

/// Bridges [sessionProvider] — and, since Part P-028C1, conditionally
/// [businessProfileProvider] — to `GoRouter`'s `refreshListenable`: the
/// piece that lets a single, persistent [GoRouter] re-run its `redirect`
/// callback whenever either changes, without ever rebuilding the router
/// itself (see [appRouterProvider]'s doc comment for the real-device bug
/// this fixes). `ref.listen` here is a plain side-effect subscription,
/// not a `ref.watch` — it does NOT make [appRouterProvider] re-run when
/// either provider changes; it only calls [notifyListeners], which
/// `GoRouter` itself is listening to.
///
/// ### Part P-028C1 addition — conditional, lazy subscription to [businessProfileProvider]
///
/// [businessProfileProvider] is an [AsyncNotifierProvider] whose `build()`
/// calls `GET /api/v1/businesses/me/` the moment anything creates a
/// subscription to it (`ref.read`/`ref.watch`/`ref.listen` all force
/// creation on first access — this is standard Riverpod behavior, not
/// something specific to this provider). Subscribing to it
/// unconditionally at construction time — the same way [sessionProvider]
/// is subscribed to just below — would therefore fire that GET request
/// for **every** signed-in user, including Customer-type accounts, the
/// instant the app starts. That directly contradicts this part's own
/// spec: "Customer-type users must skip the BusinessProfile existence
/// check entirely."
///
/// So this class only calls `ref.listen(businessProfileProvider, ...)`
/// **once**, lazily, the first time [sessionProvider] itself reports a
/// signed-in [AccountType.business] user (via [_maybeSubscribeToBusinessProfile],
/// invoked from the [sessionProvider] listener below, before
/// [notifyListeners] is called for that same change so `redirect` sees
/// an already-subscribed [businessProfileProvider] on its very next run).
/// A [AccountType.customer] session never triggers this subscription at
/// all, so [businessProfileProvider] is never even built for one —
/// enforced here at the subscription level, not only inside `redirect`'s
/// own `if (user.accountType == AccountType.business)` check.
///
/// Once subscribed, this class stays subscribed for the rest of the
/// provider's lifetime (i.e. the app process), even across a later
/// logout — deliberately not un-subscribed again, since Riverpod has no
/// built-in "temporarily pause a ref.listen" primitive and building that
/// is out of this part's scope. This is a real, minor, flagged
/// simplification (one extra provider kept alive for the rest of the app
/// session on a device that was ever signed in as Business), not a
/// silent one — see this feature's `PROJECT_PROGRESS.md` entry for Part
/// P-028C1.
class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(this._ref) {
    _ref.listen<AsyncValue<Object?>>(
      sessionProvider,
      (previous, next) {
        _maybeSubscribeToBusinessProfile(next);
        notifyListeners();
      },
      // Catches the case where a session was already restored (a token
      // existed at cold start) by the time this listener attaches, so
      // the business-profile subscription decision above isn't missed
      // waiting for a *second* session change that may never come.
      fireImmediately: true,
    );
  }

  final Ref _ref;

  /// Guards against calling `ref.listen(businessProfileProvider, ...)`
  /// more than once — see this class's docstring.
  bool _businessProfileSubscribed = false;

  void _maybeSubscribeToBusinessProfile(AsyncValue<Object?> session) {
    if (_businessProfileSubscribed) {
      return;
    }
    final user = switch (session) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (user is User && user.accountType == AccountType.business) {
      _businessProfileSubscribed = true;
      _ref.listen<AsyncValue<Object?>>(
        businessProfileProvider,
        (previous, next) => notifyListeners(),
      );
    }
  }
}
