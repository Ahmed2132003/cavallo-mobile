/// Part P-007 scope: centralized route name/path constants for the app's
/// [GoRouter] table (see `app_router.dart`).
///
/// No feature should hardcode a path string or route name directly —
/// always reference these constants (with `context.goNamed(...)` /
/// `context.pushNamed(...)`) so a path can change in exactly one place
/// without hunting through every feature screen.
///
/// ### Part P-028C1 addition — [businessOnboarding] / [businessOnboardingPath]
///
/// P-028B's own handoff note left these unadded on purpose ("RouteNames
/// has no businessOnboarding/businessProfileEdit entries yet — P-028C
/// should add the real, permanent names"). This part (P-028C1) adds the
/// onboarding entry only — it owns the router-gate half of the original
/// P-028C scope. The edit-screen route (`businessProfileEdit`) is
/// deliberately NOT added here — that stays Part P-028C2's job, per the
/// split of the original P-028C spec into two parts for length reasons.
///
/// Path chosen: `/business-onboarding` — kebab-case, consistent with
/// this file's only other multi-word path ([businessConsolePath],
/// `/business-console`). P-028B's own test file used a throwaway local
/// route (`'businessOnboarding'` / `'/onboarding'`) inside its own test
/// only, explicitly flagged as not the real permanent one — this is the
/// real one.
///
/// ### Part P-028C2 addition — [businessProfileEdit] / [businessProfileEditPath]
///
/// The other half of the same handoff note, added now by the part that
/// actually builds the screen behind it (`BusinessProfileEditScreen`).
/// Nothing above it changed: P-028C1's two constants, and every
/// pre-existing P-007 constant, are untouched — this is a purely
/// additive edit, per this project's "don't redesign a prior part's
/// work unless the real backend contract forces it" convention.
///
/// ### Part P-033 addition — [productList] / [productForm]
///
/// This part's own spec: "Wire routes for this list/create/edit flow,
/// reachable from the business console area (even though the full
/// Business Console shell itself isn't built until Phase 14 — for now,
/// reach these screens via a simple route the router exposes)." Both
/// live under `/business-console/products...` — nested under the
/// existing [businessConsolePath] segment rather than a new top-level
/// one, since that's exactly where this part's spec says they belong
/// once Phase 14 gives them a real navigational home; nesting the path
/// now means Phase 14 only has to change how they're *reached*, not the
/// paths themselves.
///
/// [productForm] deliberately has NO `:id` path parameter, unlike
/// [productDetail]/[businessProfile]/[chatThread] — see this class's
/// own [productFormPath] doc for why.
///
/// ### Part P-040 addition — [moderation] / [moderationReview]
///
/// The in-app moderator review UI (`lib/features/moderation/`). Both
/// paths sit under one `/moderation` prefix on purpose: the router's
/// role gate (`app_router.dart`) protects the whole prefix in one check,
/// so a future moderation screen added under it is gated automatically.
/// Neither entry appears in any menu-driven allow-list — gating is done
/// by the redirect guard itself, not by hiding a link.
class RouteNames {
  RouteNames._();

  // --- Route names (used with context.goNamed / context.pushNamed) ---
  static const String splash = 'splash';
  static const String login = 'login';
  static const String register = 'register';
  static const String home = 'home';
  static const String discover = 'discover';
  static const String search = 'search';
  static const String businessProfile = 'businessProfile';
  static const String productDetail = 'productDetail';
  static const String chatList = 'chatList';
  static const String chatThread = 'chatThread';
  static const String notifications = 'notifications';
  static const String businessConsole = 'businessConsole';

  /// Part P-028C1: the "complete your business profile" onboarding
  /// screen (`BusinessOnboardingScreen`, Part P-028B) a Business-type
  /// user with no `BusinessProfile` yet is routed into by
  /// `app_router.dart`'s redirect guard.
  static const String businessOnboarding = 'businessOnboarding';

  /// Part P-028C2: the authenticated Business user's own profile EDIT
  /// screen (`BusinessProfileEditScreen`) — the entry P-028B's handoff
  /// note named ("RouteNames has no businessOnboarding/
  /// businessProfileEdit entries yet") and P-028C1 deliberately left
  /// unadded, since it owns only the onboarding half of the original
  /// P-028C scope.
  ///
  /// Distinct from [businessProfile], which is the PUBLIC, customer-
  /// facing "view some business by id" screen (Part P-029) — this one
  /// takes no id at all: the backend resolves "my own profile" strictly
  /// from `request.user` (Part P-026's IDOR-safe `/businesses/me/`
  /// endpoint), so there is deliberately no id to put in the path.
  static const String businessProfileEdit = 'businessProfileEdit';

  /// Part P-033: the signed-in Business user's own product list
  /// (`ProductListScreen`), backed by `ownProductsProvider`. Same "no id
  /// — resolved from `request.user`" reasoning as [businessProfileEdit].
  static const String productList = 'productList';

  /// Part P-033: the shared create/edit product form (`ProductFormScreen`).
  /// See [productFormPath]'s own doc for why this takes no `:id`.
  static const String productForm = 'productForm';

  /// Part P-040: the moderator's pending-content queue
  /// (`ModerationQueueScreen`). Reachable only by accounts with
  /// `is_moderator` or `is_staff` — see [moderationPath].
  static const String moderation = 'moderation';

  /// Part P-040: the single-item review screen
  /// (`ModerationReviewScreen`). See [moderationReviewPath] for how the
  /// item is handed to it.
  static const String moderationReview = 'moderationReview';

  // --- Route paths (used inside GoRoute(path: ...)) ---
  static const String splashPath = '/';
  static const String loginPath = '/login';
  static const String registerPath = '/register';
  static const String homePath = '/home';
  static const String discoverPath = '/discover';
  static const String searchPath = '/search';
  static const String businessProfilePath = '/business/:id';
  static const String productDetailPath = '/product/:id';
  static const String chatListPath = '/chat';
  static const String chatThreadPath = '/chat/:id';
  static const String notificationsPath = '/notifications';
  static const String businessConsolePath = '/business-console';

  /// Part P-028C1 — see [businessOnboarding]/this class's docstring.
  static const String businessOnboardingPath = '/business-onboarding';

  /// Part P-028C2 — see [businessProfileEdit].
  ///
  /// Kept on its own top-level segment rather than under
  /// [businessProfilePath] (`/business/:id`): that route is the public
  /// by-id screen, and hanging `/business/edit` off it would make
  /// `edit` indistinguishable from an id path-parameter value to
  /// `go_router`'s matcher. `/business-profile/edit` is unambiguous and
  /// still kebab-case, consistent with [businessConsolePath] and
  /// [businessOnboardingPath].
  static const String businessProfileEditPath = '/business-profile/edit';

  /// Part P-033 — see [productList].
  static const String productListPath = '/business-console/products';

  /// Part P-033 — see [productForm].
  ///
  /// No `:id` segment: unlike [productDetailPath] (the PUBLIC,
  /// customer-facing "view this exact product" screen, Part P-034,
  /// looked up fresh by id), this is "my own product form," reached
  /// only from [productListPath]'s own screen, which already holds the
  /// full [Product] object in memory (`ownProductsProvider`) — there is
  /// nothing to look up. Edit mode is signalled by passing that
  /// `Product` as `context.pushNamed(...)`'s `extra:` argument instead
  /// (read back via `GoRouterState.extra` in `app_router.dart`); `extra`
  /// being absent/null means create mode. See `ProductFormScreen`'s own
  /// docstring for why this screen takes no `RouteNames` dependency of
  /// its own at all — the caller (this route's own builder) supplies
  /// navigation.
  static const String productFormPath = '/business-console/products/form';

  /// Part P-040 — see [moderation].
  ///
  /// Gated in `app_router.dart`'s `redirect` callback: a signed-in user
  /// whose session has neither `isModerator` nor `isStaff` is sent to
  /// [homePath] no matter how they got here (`context.go`, a deep link,
  /// a restored location). The gate covers this path and everything
  /// under `/moderation/`.
  static const String moderationPath = '/moderation';

  /// Part P-040 — see [moderationReview].
  ///
  /// No `:id` segment, for the same reason as [productFormPath]: the
  /// queue screen already holds the full queue item, which is handed
  /// over as `context.pushNamed(..., extra: item)` instead of being
  /// looked up again. A location reached WITHOUT that `extra` (a deep
  /// link, an app restore) has nothing to show, so the router's redirect
  /// sends it back to [moderationPath] rather than building a broken
  /// screen.
  static const String moderationReviewPath = '/moderation/review';

  /// Path-parameter key shared by [businessProfilePath], [productDetailPath]
  /// and [chatThreadPath].
  static const String idParam = 'id';
}