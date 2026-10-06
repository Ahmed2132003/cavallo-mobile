import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/conversation_repository.dart';
import '../domain/conversation.dart';

/// Part P-113 (STEP 5): `chatUnreadCountProvider` - the number on the Chats
/// icon of the Home top bar.
///
/// It reads the EXISTING `ConversationRepository.listConversations()` once
/// and adds up `unreadCount` of the conversations it returns. There is no
/// timer and no polling: the value is fetched when something first watches
/// it and again only when the code invalidates it (the Home pull-to-refresh
/// does).
///
/// * The sum covers the conversations of the first page only. The backend
///   returns the whole list as one array today, so this is the full count.
/// * A failed request is not an error for the UI: a badge that cannot be
///   loaded is simply not shown, so the provider settles on 0.
/// * `autoDispose`: the count is live, per-session data. When nothing
///   watches it any more it is dropped and re-read on the next watch.
final chatUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final ConversationRepository repository = ref.watch(
    conversationRepositoryProvider,
  );
  try {
    final page = await repository.listConversations();
    return page.results.fold<int>(
      0,
      (int sum, Conversation conversation) => sum + conversation.unreadCount,
    );
  } catch (_) {
    return 0;
  }
});
