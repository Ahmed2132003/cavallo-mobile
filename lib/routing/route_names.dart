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

  /// Path-parameter key shared by [businessProfilePath], [productDetailPath]
  /// and [chatThreadPath].
  static const String idParam = 'id';
}