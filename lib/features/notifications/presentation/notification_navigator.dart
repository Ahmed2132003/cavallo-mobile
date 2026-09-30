import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/deep_link_resolver.dart';
import '../../../core/push/fcm_service.dart';
import '../../../routing/app_router.dart';
import '../../../routing/route_names.dart';
import '../../chat/data/conversation_repository.dart';
import '../../chat/domain/conversation.dart';
import '../domain/app_notification.dart';

/// Part P-082 (STEP 3): the ONE place where a tapped notification becomes
/// navigation. Every source goes through [open]:
///
/// * a row in the notification center (via [openNotification]),
/// * an in-app foreground banner (via [openPush]),
/// * a background / terminated-state push tap (via [openPush]).
///
/// The route itself always comes from P-080's `resolveDeepLink` — this
/// class never builds a path by hand.
///
/// ### The `chat_thread` special case
/// `resolveDeepLink('chat_thread', 101)` answers `/chat/101`, but the
/// router's P-074 redirect guard sends any `/chat/<id>` whose `extra` is
/// not a [Conversation] to the chat list. So for chat notifications the
/// [Conversation] is looked up first (the backend has no
/// conversation-detail endpoint; the list endpoint returns every
/// conversation in one plain array, same lookup as
/// `ConversationRepository.startConversationWithBusiness`) and handed
/// over as `extra`. If it cannot be found or the request fails, the user
/// lands on the chat list instead of a broken screen.
///
/// ### push vs go
/// Real destinations use `push`, so Back returns to where the user was
/// (for example the notification center). The `/home` fallback and the
/// chat-list fallback use `go`: they are "somewhere sensible", not a
/// destination worth a back stack.
class NotificationNavigator {
  NotificationNavigator({
    required GoRouter router,
    required ConversationRepository conversationRepository,
  }) : _router = router,
       _conversationRepository = conversationRepository;

  final GoRouter _router;
  final ConversationRepository _conversationRepository;

  /// Navigates to what [deepLinkType] + [targetId] point at. Never throws.
  ///
  /// A blank [deepLinkType] means "this notification navigates nowhere"
  /// (backend contract, P-078): nothing happens.
  Future<void> open({
    required String deepLinkType,
    required int? targetId,
  }) async {
    if (deepLinkType.trim().isEmpty) return;

    final route = resolveDeepLink(deepLinkType, targetId);

    // Unknown type, or missing / invalid id.
    if (route == deepLinkFallbackRoute) {
      _router.go(route);
      return;
    }

    if (deepLinkType == DeepLinkTypes.chatThread) {
      // `route != fallback` guarantees a valid, positive targetId.
      final conversation = await _findConversation(targetId!);
      if (conversation == null) {
        _router.go(RouteNames.chatListPath);
        return;
      }
      unawaited(_router.push<void>(route, extra: conversation));
      return;
    }

    unawaited(_router.push<void>(route));
  }

  /// A row of the in-app notification center.
  Future<void> openNotification(AppNotification notification) {
    return open(
      deepLinkType: notification.deepLinkType,
      targetId: notification.targetId,
    );
  }

  /// A push message tapped in the foreground banner, or a background /
  /// terminated-state tap (P-081's [PushDeepLink]).
  Future<void> openPush(PushDeepLink link) {
    return open(deepLinkType: link.type, targetId: link.targetId);
  }

  Future<Conversation?> _findConversation(int conversationId) async {
    try {
      final page = await _conversationRepository.listConversations();
      for (final conversation in page.results) {
        if (conversation.id == conversationId) return conversation;
      }
      return null;
    } catch (_) {
      // Any failure (network, auth, parsing) degrades to the chat list.
      return null;
    }
  }
}

/// Reads the router and the conversation repository lazily, at first use.
/// Safe to read from outside the widget tree's router subtree (the app
/// root's banner / tap handlers), because [appRouterProvider] is a single
/// persistent [GoRouter].
final notificationNavigatorProvider = Provider<NotificationNavigator>((ref) {
  return NotificationNavigator(
    router: ref.watch(appRouterProvider),
    conversationRepository: ref.watch(conversationRepositoryProvider),
  );
});
