import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/error_messages.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../routing/route_names.dart';
import '../data/conversation_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';
import '../domain/shared_content.dart';

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
///
/// ### STEP 4 addition — "New chat (test)" floating action button
/// See [_ChatListScreenState._startTestConversation]'s own doc comment
/// for why this exists and why it is explicitly a manual-testing aid,
/// not a designed product entry point.
///
/// ### Part P-115 STEP 2 — restyle only
/// Presentation only: every field of the state, every repository call, the
/// pagination cursor logic and the navigation callback are unchanged.
/// Rows use the P-111 components ([AppAvatar], [AppShimmerBox],
/// [EmptyStateWidget], [ErrorStateWidget]) and `context.appColors`; every
/// user-facing string comes from the ARB files. The spec's "online dot" is NOT
/// drawn: neither the backend nor [ConversationParticipantSummary] carries
/// presence data (see the note in `chat_thread_screen.dart`), and P-115 forbids
/// new features and backend changes.
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
  bool _isStartingTestConversation = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedApiError(context.l10n, e))),
      );
    }
  }

  void _openConversation(Conversation conversation) {
    context.pushNamed(
      RouteNames.chatThread,
      pathParameters: {RouteNames.idParam: conversation.id.toString()},
      extra: conversation,
    );
  }

  /// STEP 4 — manual-testing aid only, NOT part of P-074's original
  /// scope as written. P-074's own execution prompt assumes
  /// conversations already exist or are started from elsewhere (e.g. a
  /// "Message" button on a business profile screen) — no such entry
  /// point exists anywhere in this codebase yet (confirmed by
  /// inspecting `lib/features/business_profile/` directly: no
  /// reference to `ConversationRepository`/`startConversation` anywhere
  /// outside `lib/features/chat/` itself). Without SOME way to create a
  /// conversation between two real test accounts, P-074's own
  /// acceptance criteria — a manual two-account run against the real
  /// backend — cannot be performed at all.
  ///
  /// This button is a deliberately minimal, clearly-temporary bridge:
  /// it prompts for the other account's numeric user id, calls
  /// `ConversationRepository.startConversation` (`POST
  /// /api/v1/conversations/start/`, built in STEP 2), and hand-builds a
  /// minimal [Conversation] from the response. That endpoint returns
  /// only `{id, created_at, updated_at, participant_ids}` — see
  /// `ConversationRepository.startConversation`'s own doc comment for
  /// why a full [Conversation] can't be parsed from it directly — so
  /// [ConversationParticipantSummary.displayName] here is a placeholder
  /// (`"User #<id>"`), not the real resolved name. This is enough to
  /// satisfy `app_router.dart`'s `extra is Conversation` redirect guard
  /// and let [ChatThreadScreen] mount and function correctly (it only
  /// needs `conversation.id` and `conversation.otherParticipant.id` —
  /// see that screen's own doc comment). Re-opening the same
  /// conversation later from this list shows the real resolved name,
  /// since that came from `GET /api/v1/conversations/` — this
  /// screen's normal fetch.
  ///
  /// A real "Message" entry point from a business profile (or anywhere
  /// else) is out of P-074's scope and should replace this button in a
  /// later part.
  Future<void> _startTestConversation() async {
    final recipientIdText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(dialogContext.l10n.chatTestDialogTitle),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: dialogContext.l10n.chatTestUserIdLabel,
              hintText: dialogContext.l10n.chatTestUserIdHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.l10n.chatTestCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(dialogContext.l10n.chatTestStart),
            ),
          ],
        );
      },
    );

    final recipientId = int.tryParse(recipientIdText?.trim() ?? '');
    if (recipientId == null) return;

    setState(() => _isStartingTestConversation = true);
    try {
      final conversationId = await ref
          .read(conversationRepositoryProvider)
          .startConversation(recipientId: recipientId);
      if (!mounted) return;
      setState(() => _isStartingTestConversation = false);

      final placeholderConversation = Conversation(
        id: conversationId,
        otherParticipant: ConversationParticipantSummary(
          id: recipientId,
          accountType: 'unknown',
          displayName: context.l10n.chatTestUserPlaceholder(recipientId),
        ),
        lastMessage: null,
        unreadCount: 0,
        createdAt: DateTime.now(),
      );
      if (!mounted) return;
      context.pushNamed(
        RouteNames.chatThread,
        pathParameters: {RouteNames.idParam: conversationId.toString()},
        extra: placeholderConversation,
      );
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() => _isStartingTestConversation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedApiError(context.l10n, e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatListTitle)),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isStartingTestConversation ? null : _startTestConversation,
        icon:
            _isStartingTestConversation
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.add_comment_outlined),
        label: Text(l10n.chatListNewChatTest),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (_isLoadingFirstPage) {
      return const _ConversationListSkeleton();
    }
    if (_error != null && _conversations.isEmpty) {
      return ErrorStateWidget(
        message: localizedApiError(l10n, _error),
        onRetry: _loadFirstPage,
      );
    }
    if (_conversations.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.chat_bubble_outline,
        message: l10n.chatListEmpty,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _conversations.length + (_nextCursor != null ? 1 : 0),
        separatorBuilder: (_, _) => const _RowDivider(),
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

/// Avatar diameter and gaps shared by the real row and its skeleton, so the
/// loading state does not jump when the data arrives.
const double _avatarSize = 52;
const double _rowGap = 12;
const double _rowPadding = 16;

/// Hairline between rows, inset so it starts under the text, not the avatar
/// (`indent` is directional: it flips in Arabic).
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: _rowPadding + _avatarSize + _rowGap,
      color: context.appColors.outline,
    );
  }
}

/// What the row shows under the name. Text always wins; a media-only or
/// shared-content-only message falls back to a localized label. Mirrors
/// [LastMessagePreview.previewText] (domain, English only, left untouched)
/// with ARB strings.
String _previewLabel(AppLocalizations l10n, LastMessagePreview? last) {
  if (last == null) return l10n.chatListNoMessages;
  if (last.text.isNotEmpty) return last.text;
  switch (last.mediaType) {
    case ChatMediaType.image:
      return l10n.chatListPreviewPhoto;
    case ChatMediaType.video:
      return l10n.chatListPreviewVideo;
    case null:
      break;
  }
  switch (last.sharedContentType) {
    case SharedContentType.post:
      return l10n.chatListPreviewSharedPost;
    case SharedContentType.reel:
      return l10n.chatListPreviewSharedReel;
    case SharedContentType.product:
      return l10n.chatListPreviewSharedProduct;
    case null:
      return l10n.chatListNoMessages;
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    final other = conversation.otherParticipant;
    final String displayName = other?.displayName ?? l10n.chatListUnknownUser;
    final LastMessagePreview? lastMessage = conversation.lastMessage;
    final int unread = conversation.unreadCount;
    final bool hasUnread = unread > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: _rowPadding,
          vertical: 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            AppAvatar(
              name: displayName,
              size: _avatarSize,
              ringGapColor: colors.background,
            ),
            const SizedBox(width: _rowGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            color: colors.textPrimary,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (lastMessage != null) ...<Widget>[
                        const SizedBox(width: 8),
                        Text(
                          AppFormatters.of(
                            context,
                          ).relativeTime(lastMessage.createdAt),
                          maxLines: 1,
                          style: text.bodySmall?.copyWith(
                            color:
                                hasUnread
                                    ? colors.brandText
                                    : colors.textSecondary,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _previewLabel(l10n, lastMessage),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color:
                                hasUnread
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...<Widget>[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: unread),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Brand-blue pill with the unread count (capped at `99+`). The count is also
/// spoken as a full sentence, so the meaning never depends on colour alone.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  static const int _cap = 99;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String label = count > _cap ? '$_cap+' : '$count';
    return Semantics(
      label: context.l10n.chatListUnreadLabel(count),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.brand,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onBrand,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// First-load placeholder: the same row anatomy as [_ConversationTile] built
/// from [AppShimmerBox], instead of a spinner.
class _ConversationListSkeleton extends StatelessWidget {
  const _ConversationListSkeleton();

  static const int _rows = 8;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.chatListLoadingLabel,
      child: ExcludeSemantics(
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rows,
          itemBuilder:
              (context, index) => const Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: _rowPadding,
                  vertical: 10,
                ),
                child: Row(
                  children: <Widget>[
                    AppShimmerBox.circle(size: _avatarSize),
                    SizedBox(width: _rowGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          AppShimmerBox(
                            width: 140,
                            height: 14,
                            borderRadius: 6,
                          ),
                          SizedBox(height: 8),
                          AppShimmerBox(height: 12, borderRadius: 6),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}
