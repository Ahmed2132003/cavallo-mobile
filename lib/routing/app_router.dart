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
import '../features/business_profile/presentation/business_profile_edit_screen.dart';
import '../features/business_profile/presentation/business_profile_provider.dart';
import '../features/business_profile/presentation/business_profile_public_screen.dart';
import '../features/chat/presentation/chat_list_screen.dart';
import '../features/chat/presentation/chat_thread_screen.dart';
import '../features/content/presentation/content_list_screen.dart';
import '../features/content/presentation/post_detail_screen.dart';
import '../features/content/presentation/post_form_screen.dart';
import '../features/content/presentation/reel_detail_screen.dart';
import '../features/content/presentation/reel_form_screen.dart';
import '../features/discover/presentation/discover_screen.dart';
import '../features/feed/presentation/home_screen.dart';
import '../features/moderation/domain/queue_item_entity.dart';
import '../features/moderation/presentation/moderation_queue_screen.dart';
import '../features/moderation/presentation/moderation_review_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/products/domain/product_entity.dart';
import '../features/products/presentation/product_detail_screen.dart';
import '../features/products/presentation/product_form_screen.dart';
import '../features/products/presentation/product_list_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/stories/presentation/story_creation_screen.dart';
import '../features/stories/presentation/story_viewer_screen.dart';
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
///   `notifications`, `businessConsole`, `businessOnboarding` (Part
///   P-028C1), `businessProfileEdit` (Part P-028C2), and — since Part
///   P-033 — `productList`/`productForm`): reachable only while signed
///   in.
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
/// ## Part P-028C2 — what changed here, and what deliberately did NOT
///
/// P-028C2 adds exactly one thing to this file: the [GoRoute] for
/// [RouteNames.businessProfileEditPath] →
/// `BusinessProfileEditScreen`. The `redirect` callback, the
/// Business-account gate above, [_SessionRefreshListenable]'s
/// conditional-subscription mechanism, and the base P-021b auth gate are
/// all **unchanged** — per P-028C1's own handoff note ("do not redesign
/// or replace the router-gate logic ... unless real-machine validation
/// surfaces an actual bug in them"), and per P-028C2's own acceptance
/// criterion that the onboarding redirect must remain intact after the
/// edit route is added.
///
/// The edit route needs no gate clause of its own: it is a protected
/// route like any other, so a signed-out user is already bounced to
/// `/login` by the base gate, and a Business user with no profile is
/// already bounced to onboarding by the P-028C1 gate above *before* the
/// edit route can ever render — the gate runs on `matchedLocation` for
/// every navigation, not just on cold start.
///
/// Still NOT implemented, unchanged from P-028C1 and flagged again
/// rather than silently added: an already-onboarded Business user who
/// navigates directly to `/business-onboarding` is not bounced to
/// `/home`. Only the no-profile → onboarding direction exists, which is
/// the only direction either part's acceptance criteria asked for.
///
/// ## Part P-033 — what changed here, and what deliberately did NOT
///
/// Adds exactly two [GoRoute]s — [RouteNames.productListPath] →
/// `ProductListScreen` and [RouteNames.productFormPath] →
/// `ProductFormScreen` — nested right after [RouteNames.businessConsolePath]
/// in the table, matching their nested path segment. Neither needs a
/// gate clause of its own, for the same reason [RouteNames.businessProfileEditPath]
/// doesn't (see P-028C2's note immediately above): both are ordinary
/// protected routes, already covered by the base auth gate.
///
/// `ProductListScreen`'s `onCreateNew`/`onEditProduct` callbacks (see
/// that screen's own docstring for why it takes them instead of calling
/// `context.goNamed` itself) are supplied HERE, in this route's own
/// `builder:` — exactly the "one-line `builder:`" wiring that screen's
/// docstring already anticipated, with zero changes needed to
/// `product_list_screen.dart` itself. `onEditProduct` passes the full
/// [Product] via `extra:`; `ProductFormScreen`'s own route reads it back
/// via `state.extra as Product?` — `null` for the plain "Create New" tap,
/// non-null for an edit tap, matching [RouteNames.productFormPath]'s own
/// doc on why there's no `:id` path segment here.
///
/// ## Part P-040 — moderator gate, and the two new routes
///
/// Adds a **third gate**, layered on top of the base auth gate and the
/// Business-account gate (never replacing either): the whole
/// `/moderation` prefix ([RouteNames.moderationPath] and anything under
/// `/moderation/`) is reachable only when the signed-in user has
/// `isModerator` **or** `isStaff` set (`User`, from `GET /api/v1/auth/me/`
/// — Part P-020, extended for this part). Anyone else is redirected to
/// `/home`.
///
/// This is enforced HERE, in `redirect`, which runs for every navigation
/// regardless of how it started (`context.go`, `context.push`, a deep
/// link, a restored location) — not by hiding a menu entry. A signed-out
/// user never reaches this gate: the base gate above has already sent
/// them to `/login`.
///
/// The review route additionally needs its [QueueItem], which the queue
/// screen passes as `extra:` (same convention as
/// [RouteNames.productForm]). If `extra` is missing or not a
/// [QueueItem] (a deep link, an app restore) the redirect sends the user
/// to the queue instead of building a broken screen. The role check runs
/// first, so a non-moderator is never told anything about this route.
///
/// Both routes are wired in the `routes:` table below; the queue's
/// `onOpenItem` callback is supplied here, in the route's `builder:`, for
/// the same reason `ProductListScreen`'s callbacks are (see P-033 above):
/// the screen stays free of any `GoRouter` dependency.
///
/// `_SessionRefreshListenable` needs no change: it already re-runs
/// `redirect` whenever the session changes, which is exactly what
/// re-evaluates this gate on login/logout.
///
/// ## Part P-044 — three new routes, no new gate
///
/// Adds [RouteNames.contentListPath] → `ContentListScreen`,
/// [RouteNames.postFormPath] → `PostFormScreen`, and
/// [RouteNames.reelFormPath] → `ReelFormScreen`, nested right after
/// [RouteNames.productFormPath] — same `/business-console/...` prefix
/// convention as the Part P-033 block immediately above. None of the
/// three needs a gate clause of its own, for the exact same reason
/// [RouteNames.productListPath]/[RouteNames.productFormPath] don't: all
/// three are ordinary protected routes, already covered by the base
/// auth gate.
///
/// `ContentListScreen`'s `onCreatePost`/`onCreateReel` callbacks (see
/// that screen's own docstring for why it takes them instead of calling
/// `context.pushNamed` itself) are supplied here, in this route's own
/// `builder:` — identical wiring shape to `ProductListScreen`'s
/// `onCreateNew`/`onEditProduct` above. Unlike `productForm`,
/// `postForm`/`reelForm` read no `extra:` — both forms are strictly
/// create-only (see each screen's own docstring for why), so there is
/// no edit-mode payload to hand over.
///
/// ## Part P-045 — two new public detail routes, no new gate
///
/// Adds [RouteNames.postDetailPath] (`/post/:id`) → `PostDetailScreen`
/// and [RouteNames.reelDetailPath] (`/reel/:id`) → `ReelDetailScreen`,
/// placed right after [RouteNames.productDetailPath] since all three are
/// the same shape: a public, customer-facing "view this exact item by
/// id" screen. Both read `state.pathParameters[RouteNames.idParam]`,
/// identically to `productDetail`'s builder immediately above them.
///
/// Neither needs a gate clause of its own, for the same reason
/// `productDetail` doesn't: both are ordinary protected routes, already
/// covered by the base auth gate — reachable only while signed in, like
/// everything else in this table outside `_publicRoutes`.
///
/// Genuinely new routes, not placeholder replacements: P-007's original
/// route table never anticipated Posts/Reels as top-level routes at all
/// (unlike `productDetail`, which replaced an existing P-007 placeholder
/// screen when Part P-034 built the real one).
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
      // already showing its own loading UI (e.g. AppButton's isLoading).
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

      // --- Part P-040: third gate, moderator-only routes ---
      // Layered on top of both gates above, evaluated only once `user`
      // is known non-null. See this provider's doc comment ("Part P-040
      // — moderator gate") for why this lives here and not in a menu.
      if (_isModerationLocation(location)) {
        final canModerate = user.isModerator || user.isStaff;
        if (!canModerate) {
          return RouteNames.homePath;
        }
        // The review screen needs the QueueItem handed over as `extra`;
        // without it (deep link, restored location) go back to the queue.
        if (location == RouteNames.moderationReviewPath &&
            state.extra is! QueueItem) {
          return RouteNames.moderationPath;
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
        // Part P-028C2. Placed next to the onboarding route on purpose:
        // the two screens are the same feature's two halves (create
        // once, then edit), and both are "my own profile," distinct from
        // the public `businessProfile` (`/business/:id`) route further
        // down, which is Part P-029's customer-facing screen.
        path: RouteNames.businessProfileEditPath,
        name: RouteNames.businessProfileEdit,
        builder: (context, state) => const BusinessProfileEditScreen(),
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
        // Part P-029: replaces P-007's placeholder. The public,
        // customer-facing "view a business by id" screen — distinct
        // from businessProfileEdit ("my own profile"), see that
        // route's own comment above.
        path: RouteNames.businessProfilePath,
        name: RouteNames.businessProfile,
        builder: (context, state) {
          final id = state.pathParameters[RouteNames.idParam]!;
          return BusinessProfilePublicScreen(businessId: id);
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
        // Part P-045. A genuinely new route — P-007's original skeleton
        // never anticipated Posts/Reels as top-level routes, so this is
        // an additive routing change, not a placeholder replacement
        // (unlike productDetail's route above). No gate clause of its
        // own — an ordinary protected route, same as productDetail.
        path: RouteNames.postDetailPath,
        name: RouteNames.postDetail,
        builder: (context, state) {
          final id = state.pathParameters[RouteNames.idParam]!;
          return PostDetailScreen(postId: id);
        },
      ),
      GoRoute(
        // Part P-045. Same reasoning as postDetail immediately above.
        path: RouteNames.reelDetailPath,
        name: RouteNames.reelDetail,
        builder: (context, state) {
          final id = state.pathParameters[RouteNames.idParam]!;
          return ReelDetailScreen(reelId: id);
        },
      ),
      GoRoute(
        // Part P-050. Same "public, customer-facing, id-param" shape as
        // postDetail/reelDetail immediately above — no gate clause of
        // its own, an ordinary protected route, reachable only while
        // signed in like everything else outside _publicRoutes.
        // `businessName` comes from `context.pushNamed(..., extra:
        // businessName)` (StoryRingWidget, this part) as a plain
        // String — `null` when this route is reached without it (a
        // deep link, a restored location); StoryViewerScreen's own
        // constructor already treats that as optional/cosmetic, same
        // as its own docstring says.
        path: RouteNames.storyViewerPath,
        name: RouteNames.storyViewer,
        builder: (context, state) {
          final id = state.pathParameters[RouteNames.idParam]!;
          return StoryViewerScreen(
            businessId: id,
            businessName: state.extra as String?,
          );
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
      GoRoute(
        // Part P-033. See this provider's own "Part P-033" doc section
        // above for why the navigation callbacks are wired here rather
        // than inside `product_list_screen.dart` itself.
        path: RouteNames.productListPath,
        name: RouteNames.productList,
        builder: (context, state) => ProductListScreen(
          onCreateNew: () => context.pushNamed(RouteNames.productForm),
          onEditProduct: (product) =>
              context.pushNamed(RouteNames.productForm, extra: product),
        ),
      ),
      GoRoute(
        // Part P-033. `extra` is the full `Product` for edit mode, or
        // `null` for create mode — see `RouteNames.productFormPath`'s
        // own doc for why there's no `:id` path segment here instead.
        path: RouteNames.productFormPath,
        name: RouteNames.productForm,
        builder: (context, state) =>
            ProductFormScreen(existingProduct: state.extra as Product?),
      ),
      GoRoute(
        // Part P-044. See this provider's "Part P-044" doc section
        // above for why the navigation callbacks are wired here rather
        // than inside `content_list_screen.dart` itself (same reasoning
        // as `productList` above).
        path: RouteNames.contentListPath,
        name: RouteNames.contentList,
        builder: (context, state) => ContentListScreen(
          onCreatePost: () => context.pushNamed(RouteNames.postForm),
          onCreateReel: () => context.pushNamed(RouteNames.reelForm),
        ),
      ),
      GoRoute(
        // Part P-044. Create-only — no `extra:` to read, unlike
        // `productForm` — see `PostFormScreen`'s own docstring.
        path: RouteNames.postFormPath,
        name: RouteNames.postForm,
        builder: (context, state) => const PostFormScreen(),
      ),
      GoRoute(
        // Part P-044. Same create-only shape as `postForm` above.
        path: RouteNames.reelFormPath,
        name: RouteNames.reelForm,
        builder: (context, state) => const ReelFormScreen(),
      ),
      GoRoute(
        // Part P-051. Same create-only shape as `postForm`/`reelForm`
        // above — see `RouteNames.storyFormPath`'s own doc for why this
        // route lives under `/business-console/stories/...` rather than
        // nested under `contentListPath` alongside Posts/Reels.
        path: RouteNames.storyFormPath,
        name: RouteNames.storyForm,
        builder: (context, state) => const StoryCreationScreen(),
      ),
      GoRoute(
        // Part P-040. Moderator-only — gated by the redirect callback
        // above (see this provider's "Part P-040" doc section), not
        // here. `onOpenItem` hands the tapped item to the review route
        // as `extra`, like `productForm`'s edit mode above.
        path: RouteNames.moderationPath,
        name: RouteNames.moderation,
        builder: (context, state) => ModerationQueueScreen(
          onOpenItem: (item) =>
              context.pushNamed(RouteNames.moderationReview, extra: item),
        ),
      ),
      GoRoute(
        // Part P-040. The redirect callback guarantees `extra` is a
        // QueueItem by the time this builder runs (a missing one is
        // redirected back to the queue), so the cast cannot fail here.
        path: RouteNames.moderationReviewPath,
        name: RouteNames.moderationReview,
        builder: (context, state) =>
            ModerationReviewScreen(item: state.extra! as QueueItem),
      ),
    ],
  );
});

/// True for `/moderation` itself and anything under `/moderation/` —
/// the prefix the moderator gate in [appRouterProvider]'s `redirect`
/// protects. Matched on a path-segment boundary so an unrelated route
/// that merely starts with the same letters (e.g. `/moderation-tools`)
/// would not be caught by accident.
bool _isModerationLocation(String location) {
  return location == RouteNames.moderationPath ||
      location.startsWith('${RouteNames.moderationPath}/');
}

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