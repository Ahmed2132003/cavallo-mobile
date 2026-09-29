import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/chat/chat_connection_manager.dart';
import '../../../core/chat/chat_event.dart';
import '../../../core/network/api_failure.dart';
import '../data/conversation_repository.dart';
import '../data/message_repository.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';
import '../domain/message_status.dart';
import '../domain/shared_content.dart';
import 'message_bubble_widget.dart';
import 'outbound_message_queue_provider.dart';

/// Part P-074 STEP 3 — the Message Thread screen (`/chat/:id`), replacing
/// P-007's placeholder IN PLACE (same file; class renamed only in its
/// constructor signature — see this class's own note below on why
/// `chatId` became `conversation`).
///
/// ### Why this takes a full [Conversation], not just an id
/// Determining "is this message mine or theirs" needs
/// `conversation.otherParticipant.id` (STEP 2) — in a 1:1 conversation,
/// `message.senderId != otherParticipant.id` is sufficient and means
/// this screen never needs to know its own signed-in user id at all.
/// That requires the full [Conversation], not just its id, so
/// `chat_list_screen.dart` now passes the whole tapped [Conversation] as
/// `extra:` (the same convention `app_router.dart` already uses for
/// `QueueItem`/`Product`/`businessName`). `app_router.dart`'s `redirect`
/// now guarantees `extra` is a [Conversation] before this screen is ever
/// built — see that file's own STEP 3 diff — mirroring
/// `moderationReview`'s existing `QueueItem` guard exactly.
///
/// ### Fetch strategy — documented, per this part's execution prompt
/// - **Opening this screen** (this `State`'s `initState`, i.e. every
///   time the user navigates into a conversation): [ConversationRepository.fetchMessageHistory]
///   — a full, current snapshot from the server. No "resume" logic is
///   needed here because a fresh screen instance always fetches fresh.
/// - **A WebSocket reconnect while this screen stays open**
///   ([ChatConnectionState] transitioning back to `connected` from
///   `reconnecting`, P-073's own STEP 3 backoff/retry): [MessageRepository.fetchMessagesSince]
///   using the highest message id already loaded, to fill exactly the
///   gap the disconnect may have caused without re-fetching everything.
///
/// ### mark_delivered / mark_read — MVP choices, per this part's own
/// execution prompt ("document your choice")
/// - **delivered**: sent for every one of the OTHER participant's
///   messages not already `delivered`/`read`, the moment they're
///   fetched (history, fetch-since) or received (`MessageReceived`).
/// - **read**: uses the simpler of the two offered approximations —
///   everything currently loaded from the other participant, not
///   already `read`, is marked read whenever this screen is mounted AND
///   the app is in the foreground (tracked via [WidgetsBindingObserver],
///   not a real per-bubble `VisibilityDetector`).
///
/// ### Presence — flagged gap, not fabricated
/// The verified `chat_event.dart` contract (P-073) has exactly three
/// server-push event shapes, none of which carries the OTHER
/// participant's online/offline state, and `ConversationParticipantSummary`
/// (STEP 2) carries no presence field either. The small label under the
/// app bar title below therefore shows THIS DEVICE'S OWN socket
/// connection state (`ChatConnectionState`), not real per-user presence
/// — see that label's own inline comment.
///
/// ### Sending — Part P-075 STEP 3 (optimistic UI + outbound queue)
/// Pressing send no longer awaits the REST call here. The text is
/// handed to [OutboundMessageQueueNotifier.enqueueMessage] and the
/// field is cleared immediately; the message shows up right away as a
/// local [OutboundMessageBubbleWidget] at the bottom of the thread
/// (sending / retrying / failed-tap-to-retry). When the queue reports
/// success on [OutboundMessageQueueNotifier.sentStream], the
/// server-confirmed [Message] is upserted into [_messagesById] and the
/// local bubble is already gone (the queue removes it first).
///
/// The queue provider is NOT autoDispose (P-051's same choice), so a
/// message still retrying when the user leaves this screen keeps
/// retrying; on re-entry its pending bubble reappears from the queue.
/// If it succeeds while no thread screen is open, nothing is lost — the
/// next open's history fetch includes it.
///
/// Only pending bubbles for THIS conversation are shown. If history
/// failed to load but pending messages exist, the message list is shown
/// (with those pending bubbles) instead of the history-error view, so a
/// failed send is never hidden behind an error screen.
///
/// ### BUGFIX (found by P-075 STEP 4's widget tests)
/// `dispose()` used to call `ref.read(chatConnectionManagerProvider)`.
/// Riverpod 3 forbids using `ref` once the element is being unmounted
/// (`Bad state: Using "ref" when a widget is about to or has been
/// unmounted is unsafe`), so that line threw and the REST of `dispose()`
/// never ran: the WebSocket was never disconnected and the text/scroll
/// controllers were never disposed. The manager is now cached in
/// [_chatManager] during `initState` (when `ref` is still valid) and
/// `dispose()` uses that field instead.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.conversation});

  final Conversation conversation;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen>
    with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  /// Cached in `initState` so `dispose()` never has to touch `ref`
  /// (see this class's BUGFIX note above).
  late final ChatConnectionManager _chatManager;

  /// Keyed by message id — makes upsert/dedupe O(1) and cheaply absorbs
  /// a `MessageReceived` echo of a message this device itself just sent
  /// via REST (flagged: `chat_event.dart`'s own doc comment only
  /// confirms self-exclusion for `typing_indicator` specifically, not
  /// `chat_message` — this dedupe is a defensive choice, not an assumed
  /// guarantee either way).
  final Map<int, Message> _messagesById = {};

  StreamSubscription<ChatEvent>? _eventSubscription;
  StreamSubscription<ChatConnectionState>? _connectionSubscription;
  StreamSubscription<OutboundMessageSent>? _sentSubscription;
  ChatConnectionState _connectionState = ChatConnectionState.disconnected;
  bool _hasConnectedOnce = false;

  bool _isLoadingHistory = true;
  bool _isAppInForeground = true;
  bool _otherIsTyping = false;
  Timer? _typingTimeoutTimer;
  Timer? _stopTypingTimer;

  ApiFailure? _historyError;

  int get _conversationId => widget.conversation.id;
  int? get _otherParticipantId => widget.conversation.otherParticipant?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatManager = ref.read(chatConnectionManagerProvider);
    _sentSubscription = ref
        .read(outboundMessageQueueProvider.notifier)
        .sentStream
        .listen(_handleOutboundSent);
    _connect();
    _loadHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingTimeoutTimer?.cancel();
    _stopTypingTimer?.cancel();
    _eventSubscription?.cancel();
    _connectionSubscription?.cancel();
    _sentSubscription?.cancel();
    // Uses the cached [_chatManager], NOT `ref.read` — `ref` is unsafe
    // to use during dispose (see this class's BUGFIX note).
    _chatManager.sendTyping(false);
    // A deliberate close, per this part's execution prompt ("On leaving
    // the screen, call disconnect()"). Fire-and-forget is correct here —
    // this widget is already unmounting.
    unawaited(_chatManager.disconnect());
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    if (_isAppInForeground) {
      _markVisibleMessagesAsRead();
    }
  }

  void _connect() {
    final manager = _chatManager;
    _connectionSubscription = manager.connectionState.listen((state) {
      if (!mounted) return;
      final wasConnected = _connectionState == ChatConnectionState.connected;
      setState(() => _connectionState = state);
      if (state == ChatConnectionState.connected) {
        if (_hasConnectedOnce && !wasConnected) {
          _catchUpAfterReconnect();
        }
        _hasConnectedOnce = true;
      }
    });
    _eventSubscription = manager.eventStream.listen(_handleEvent);
    unawaited(manager.connect(_conversationId));
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });
    try {
      final page = await ref
          .read(conversationRepositoryProvider)
          .fetchMessageHistory(_conversationId);
      if (!mounted) return;
      // Wire order is newest-first — reversed here into oldest-to-newest
      // (the on-screen order), exactly as `fetchMessageHistory`'s own
      // doc comment says is this layer's job, not the data layer's.
      for (final message in page.results.reversed) {
        _messagesById[message.id] = message;
      }
      setState(() => _isLoadingHistory = false);
      _markDeliveredForLoadedMessages();
      _markVisibleMessagesAsRead();
      _scrollToBottomSoon();
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e;
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _catchUpAfterReconnect() async {
    if (_messagesById.isEmpty) return;
    final maxId = _messagesById.keys.reduce((a, b) => a > b ? a : b);
    try {
      final missed = await ref
          .read(messageRepositoryProvider)
          .fetchMessagesSince(
            conversationId: _conversationId,
            sinceMessageId: maxId,
          );
      if (!mounted || missed.isEmpty) return;
      setState(() {
        for (final message in missed) {
          _messagesById[message.id] = message;
        }
      });
      _markDeliveredForLoadedMessages();
      _markVisibleMessagesAsRead();
      _scrollToBottomSoon();
    } on ApiFailure catch (_) {
      // Best-effort: a fresh screen open, or the next reconnect, will
      // retry. Not surfaced as an error banner — from the user's
      // perspective the connection is back up.
    }
  }

  void _markDeliveredForLoadedMessages() {
    final manager = _chatManager;
    for (final message in _messagesById.values) {
      if (message.senderId == _otherParticipantId &&
          message.status == MessageStatus.sent) {
        manager.sendMarkDelivered(message.id);
      }
    }
  }

  void _markVisibleMessagesAsRead() {
    if (!_isAppInForeground) return;
    final manager = _chatManager;
    for (final message in _messagesById.values) {
      if (message.senderId == _otherParticipantId &&
          message.status != MessageStatus.read) {
        manager.sendMarkRead(message.id);
      }
    }
  }

  void _handleEvent(ChatEvent event) {
    if (!mounted) return;
    switch (event) {
      case MessageReceived():
        setState(() {
          _messagesById[event.id] = Message(
            id: event.id,
            conversationId: event.conversationId,
            senderId: event.senderId,
            text: event.text,
            status: MessageStatus.fromRaw(event.status),
            createdAt: event.createdAt,
            mediaUrl: event.mediaUrl,
            mediaType: ChatMediaType.fromRaw(event.mediaType),
            sharedContent: SharedContent.tryParse(event.sharedContent),
          );
        });
        _markDeliveredForLoadedMessages();
        _markVisibleMessagesAsRead();
        _scrollToBottomSoon();
      case StatusUpdate():
        final existing = _messagesById[event.messageId];
        if (existing != null) {
          setState(() {
            _messagesById[event.messageId] = existing.copyWithStatus(
              MessageStatus.fromRaw(event.status),
            );
          });
        }
      case TypingIndicator():
        _typingTimeoutTimer?.cancel();
        setState(() => _otherIsTyping = event.isTyping);
        if (event.isTyping) {
          // Safety net if the paired "false" frame never arrives —
          // comfortably longer than _onTextChanged's own 2s debounce.
          _typingTimeoutTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => _otherIsTyping = false);
          });
        }
    }
  }

  /// Part P-075 STEP 3 — a queued message reached the server. The queue
  /// has already removed its local pending bubble; this puts the real,
  /// server-confirmed [Message] into the thread. Ignores messages that
  /// belong to a different conversation (the queue is app-wide).
  void _handleOutboundSent(OutboundMessageSent event) {
    if (!mounted) return;
    if (event.message.conversationId != _conversationId) return;
    setState(() {
      _messagesById[event.message.id] = event.message;
    });
    _scrollToBottomSoon();
  }

  void _onTextChanged(String text) {
    final manager = _chatManager;
    _stopTypingTimer?.cancel();
    if (text.isEmpty) {
      manager.sendTyping(false);
      return;
    }
    manager.sendTyping(true);
    _stopTypingTimer = Timer(
      const Duration(seconds: 2),
      () => manager.sendTyping(false),
    );
  }

  /// Part P-075 STEP 3 — optimistic send: hands the text to the
  /// outbound queue and clears the field immediately. The queue owns
  /// the real REST call, retries and the failed state.
  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _stopTypingTimer?.cancel();
    _chatManager.sendTyping(false);

    ref
        .read(outboundMessageQueueProvider.notifier)
        .enqueueMessage(conversationId: _conversationId, text: text);
    _textController.clear();
    _scrollToBottomSoon();
  }

  /// Part P-076 — client-side size caps. MUST stay in sync with the
  /// backend's `CHAT_IMAGE_MAX_BYTES` / `CHAT_VIDEO_MAX_BYTES`
  /// (`chat/serializers.py`): 5 MB image / 25 MB video. The backend is
  /// still the final authority (`validate_upload()`); this pre-check only
  /// avoids uploading a file that is already known to be rejected.
  static const _maxImageBytes = 5 * 1024 * 1024;
  static const _maxVideoBytes = 25 * 1024 * 1024;

  /// Part P-076 — the attach button: a small sheet to choose Photo or
  /// Video, then [_pickAndEnqueueMedia].
  Future<void> _showAttachSheet() async {
    final choice = await showModalBottomSheet<ChatMediaType>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('chatAttach_photo'),
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.of(sheetContext).pop(ChatMediaType.image),
            ),
            ListTile(
              key: const Key('chatAttach_video'),
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () => Navigator.of(sheetContext).pop(ChatMediaType.video),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _pickAndEnqueueMedia(choice);
  }

  /// Part P-076 — picks a file (same `image_picker` calls as
  /// `story_creation_screen.dart`), rejects an over-cap file with a
  /// SnackBar, and otherwise hands it to the SAME outbound queue as text
  /// messages. Whatever is typed in the composer is sent as the caption.
  Future<void> _pickAndEnqueueMedia(ChatMediaType type) async {
    final picker = ImagePicker();
    final XFile? picked = type == ChatMediaType.image
        ? await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
            maxWidth: 1920,
          )
        : await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final size = await File(picked.path).length();
    if (!mounted) return;
    final limit = type == ChatMediaType.image ? _maxImageBytes : _maxVideoBytes;
    if (size > limit) {
      final label = type == ChatMediaType.image ? 'Photo' : 'Video';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label is too large (max ${limit ~/ (1024 * 1024)} MB).'),
        ),
      );
      return;
    }

    _stopTypingTimer?.cancel();
    _chatManager.sendTyping(false);

    final caption = _textController.text.trim();
    ref
        .read(outboundMessageQueueProvider.notifier)
        .enqueueMediaMessage(
          conversationId: _conversationId,
          text: caption,
          mediaPath: picked.path,
          mediaType: type,
        );
    _textController.clear();
    _scrollToBottomSoon();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  String _connectionLabel() {
    switch (_connectionState) {
      case ChatConnectionState.connected:
        return 'Online';
      case ChatConnectionState.connecting:
        return 'Connecting…';
      case ChatConnectionState.reconnecting:
        return 'Reconnecting…';
      case ChatConnectionState.disconnected:
        return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        widget.conversation.otherParticipant?.displayName ?? 'Chat';
    final sortedMessages = _messagesById.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final pending =
        ref
            .watch(outboundMessageQueueProvider)
            .where((m) => m.conversationId == _conversationId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            // See this class's own top doc comment ("Presence — flagged
            // gap, not fabricated"): this is OUR OWN socket state, not
            // the other participant's real presence.
            child: Text(
              _otherIsTyping ? 'typing…' : _connectionLabel(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(sortedMessages, pending)),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageList(
    List<Message> messages,
    List<OutboundMessage> pending,
  ) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_historyError != null && messages.isEmpty && pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_historyError!.message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (messages.isEmpty && pending.isEmpty) {
      return const Center(child: Text('No messages yet — say hi!'));
    }

    final queue = ref.read(outboundMessageQueueProvider.notifier);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length + pending.length,
      itemBuilder: (context, index) {
        if (index < messages.length) {
          final message = messages[index];
          return MessageBubbleWidget(
            message: message,
            isMine: message.senderId != _otherParticipantId,
          );
        }
        final outbound = pending[index - messages.length];
        return OutboundMessageBubbleWidget(
          key: ValueKey('outbound_bubble_${outbound.id}'),
          outbound: outbound,
          onRetry: () => queue.retryFailedMessage(outbound.id),
          onDiscard: () => queue.discardFailedMessage(outbound.id),
        );
      },
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            IconButton(
              key: const Key('chatComposer_attachButton'),
              icon: const Icon(Icons.attach_file),
              onPressed: _showAttachSheet,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                onChanged: _onTextChanged,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}