/// Part P-007 scope: centralized route name/path constants for the app's
/// [GoRouter] table (see `app_router.dart`).
///
/// No feature should hardcode a path string or route name directly —
/// always reference these constants (with `context.goNamed(...)` /
/// `context.pushNamed(...)`) so a path can change in exactly one place
/// without hunting through every feature screen.
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

  /// Path-parameter key shared by [businessProfilePath], [productDetailPath]
  /// and [chatThreadPath].
  static const String idParam = 'id';
}
