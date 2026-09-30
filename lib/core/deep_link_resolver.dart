import '../routing/route_names.dart';

/// Part P-080: the Flutter-side half of the notification deep-link
/// contract defined by the backend in Part P-078.
///
/// The backend `Notification` model carries two separate fields:
/// `deep_link_type` (WHERE to go, a string) and `target_id` (the id of the
/// thing to open). [resolveDeepLink] turns that pair into a route path that
/// ALREADY exists in `RouteNames` — no route is invented here.
///
/// ### COUPLING — keep these two in sync (flagged on purpose)
///
/// [DeepLinkTypes] and the `switch` inside [resolveDeepLink] mirror the
/// `deep_link_type` choice list in the backend's `notifications/models.py`
/// (pinned there by `test_choice_values_are_the_locked_contract`). If a
/// future phase adds a new notification source with a new deep-link
/// target, BOTH the backend choice list AND this file (plus its test) must
/// be updated together.
///
/// Consumers: Part P-081 (FCM tap handling) and Part P-082 (notification
/// center UI) call [resolveDeepLink]; this part builds only the pure
/// resolution function, no UI and no FCM handling.

/// The exact `deep_link_type` strings sent by the backend (P-078).
class DeepLinkTypes {
  DeepLinkTypes._();

  static const String businessProfile = 'business_profile';
  static const String postDetail = 'post_detail';
  static const String reelDetail = 'reel_detail';
  static const String productDetail = 'product_detail';
  static const String chatThread = 'chat_thread';

  /// Every value [resolveDeepLink] knows how to resolve.
  static const Set<String> all = <String>{
    businessProfile,
    postDetail,
    reelDetail,
    productDetail,
    chatThread,
  };
}

/// Where an unresolvable deep link lands instead of crashing.
const String deepLinkFallbackRoute = RouteNames.homePath;

/// Resolves a notification's [deepLinkType] + [targetId] into a concrete
/// route path (for example `business_profile` + `5` -> `/business/5`).
///
/// Never throws and never returns null or a malformed path. Returns
/// [deepLinkFallbackRoute] (`/home`) when:
/// - [deepLinkType] is unknown or blank (a blank type means "navigates
///   nowhere" in the backend contract), or
/// - [targetId] is null or not a positive id (every supported type
///   requires one, so a null id would otherwise produce `/business/null`).
String resolveDeepLink(String deepLinkType, int? targetId) {
  final String? pathPattern = switch (deepLinkType) {
    DeepLinkTypes.businessProfile => RouteNames.businessProfilePath,
    DeepLinkTypes.postDetail => RouteNames.postDetailPath,
    DeepLinkTypes.reelDetail => RouteNames.reelDetailPath,
    DeepLinkTypes.productDetail => RouteNames.productDetailPath,
    DeepLinkTypes.chatThread => RouteNames.chatThreadPath,
    _ => null,
  };

  if (pathPattern == null) {
    return deepLinkFallbackRoute;
  }
  if (targetId == null || targetId <= 0) {
    return deepLinkFallbackRoute;
  }

  return pathPattern.replaceFirst(':${RouteNames.idParam}', '$targetId');
}
