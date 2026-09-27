import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../routing/route_names.dart';
import '../data/conversation_repository.dart';
import '../domain/conversation.dart';

/// Part P-074 STEP 3 — the Conversation List screen (`/chat`), replacing
/// P-007's placeholder IN PLACE (same file, same class name — per rule
/// 11 of this project's own process: don't duplicate an existing
/// file/class, edit it).
///
/// Fetches `GET /api/v1/conversations/` via [ConversationRepository]
/// (STEP 2), displayed in whatever order the backend returns (no
/// client-side re-sort). Supports pull-to-refresh and cursor-based
/// "load more" near the bottom, using `PaginatedResponse.next` verbatim
/// as the next page's request URL — the same opaque-cursor contract
/// `ConversationRepository.listConversations`'s own doc comment
/// describes.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _scrollController = ScrollController();

  List<Conversation> _conversations = [];
  String? _nextCursor;
  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  ApiFailure? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || _nextCursor == null) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoadingFirstPage = true;
      _error = null;
    });
    try {
      final page =
          await ref.read(conversationRepositoryProvider).listConversations();
      if (!mounted) return;
      setState(() {
        _conversations = page.results;
        _nextCursor = page.next;
        _isLoadingFirstPage = false;
      });
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoadingFirstPage = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    final cursor = _nextCursor;
    if (cursor == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await ref
          .read(conversationRepositoryProvider)
          .listConversations(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _conversations = [..._conversations, ...page.results];
        _nextCursor = page.next;
        _isLoadingMore = false;
      });
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openConversation(Conversation conversation) {
    context.pushNamed(
      RouteNames.chatThread,
      pathParameters: {RouteNames.idParam: conversation.id.toString()},
      extra: conversation,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingFirstPage) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _conversations.isEmpty) {
      return _ErrorRetry(message: _error!.message, onRetry: _loadFirstPage);
    }
    if (_conversations.isEmpty) {
      return const Center(child: Text('No conversations yet'));
    }
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _conversations.length + (_nextCursor != null ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _conversations.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final conversation = _conversations[index];
          return _ConversationTile(
            conversation: conversation,
            onTap: () => _openConversation(conversation),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final other = conversation.otherParticipant;
    final displayName = other?.displayName ?? 'Unknown';
    final lastMessage = conversation.lastMessage;
    final hasUnread = conversation.unreadCount > 0;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        ),
      ),
      title: Text(
        displayName,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        lastMessage?.text ?? 'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: hasUnread
          ? CircleAvatar(
              radius: 10,
              child: Text(
                conversation.unreadCount > 99
                    ? '99+'
                    : conversation.unreadCount.toString(),
                style: const TextStyle(fontSize: 10),
              ),
            )
          : null,
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}