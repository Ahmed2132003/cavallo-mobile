import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/chat/chat_connection_manager.dart';
import 'package:social_commerce_app/core/chat/chat_event.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/chat/data/message_repository.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';
import 'package:social_commerce_app/features/chat/domain/shared_content.dart';
import 'package:social_commerce_app/features/chat/presentation/chat_list_screen.dart';
import 'package:social_commerce_app/features/chat/presentation/chat_thread_screen.dart';
import 'package:social_commerce_app/features/chat/presentation/outbound_message_queue_provider.dart';

import 'golden_helpers.dart';

/// Part P-115 STEP 10A: goldens for the Chat List and the Chat Thread in
/// light-en, light-ar, dark-en, dark-ar. Images live in
/// `test/goldens/p115_chat/` and are created in STEP 10C (not here).
///
/// Offline and deterministic: every repository / the socket manager is a fake,
/// all timestamps are fixed. ChatListScreen builds AppFormatters without an
/// injectable clock, so every list time is an OLD fixed date (always older
/// than 7 days, hence always rendered as an absolute date). No animation is
/// left running: the typing state is a static frame. This file is ASCII only.

const String _dir = 'p115_chat';

// --------------------------------------------------------------- fakes

class _FakeConversationRepository extends ConversationRepository {
  _FakeConversationRepository({
    this.conversations = const <Conversation>[],
    this.history = const <Message>[],
  }) : super(Dio());

  final List<Conversation> conversations;

  /// Newest first, exactly like the wire order.
  final List<Message> history;

  @override
  Future<PaginatedResponse<Conversation>> listConversations({
    String? cursor,
  }) async {
    return PaginatedResponse<Conversation>(
      results: conversations,
      next: null,
      previous: null,
    );
  }

  @override
  Future<PaginatedResponse<Message>> fetchMessageHistory(
    int conversationId, {
    String? cursor,
  }) async {
    return PaginatedResponse<Message>(
      results: history,
      next: null,
      previous: null,
    );
  }

  @override
  Future<int> startConversation({required int recipientId}) =>
      throw UnimplementedError('not used by goldens');
}

class _FakeMessageRepository extends MessageRepository {
  _FakeMessageRepository() : super(Dio());

  @override
  Future<List<Message>> fetchMessagesSince({
    required int conversationId,
    required int sinceMessageId,
  }) async => <Message>[];
}

class _FakeChatConnectionManager extends ChatConnectionManager {
  _FakeChatConnectionManager()
    : super(
        getAccessToken: () async => null,
        getApiBaseUrl: () => 'http://localhost',
      );

  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();
  final StreamController<ChatConnectionState> _states =
      StreamController<ChatConnectionState>.broadcast();

  @override
  Stream<ChatConnectionState> get connectionState => _states.stream;

  @override
  Stream<ChatEvent> get eventStream => _events.stream;

  void emitEvent(ChatEvent event) => _events.add(event);

  void emitState(ChatConnectionState state) => _states.add(state);

  Future<void> close() async {
    await _events.close();
    await _states.close();
  }

  @override
  Future<void> connect(int conversationId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void sendTyping(bool isTyping) {}

  @override
  void sendMarkDelivered(int messageId) {}

  @override
  void sendMarkRead(int messageId) {}
}

// --------------------------------------------------------------- fixed data

const int _me = 1;
const int _other = 7;

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 1, day, hour, minute);

Conversation _conv({
  required int id,
  required String name,
  LastMessagePreview? last,
  int unread = 0,
}) {
  return Conversation(
    id: id,
    otherParticipant: ConversationParticipantSummary(
      id: id + 100,
      accountType: 'business',
      displayName: name,
    ),
    lastMessage: last,
    unreadCount: unread,
    createdAt: _at(1, 9, 0),
  );
}

LastMessagePreview _last(
  String text, {
  int day = 20,
  ChatMediaType? media,
  SharedContentType? shared,
}) {
  return LastMessagePreview(
    id: 900 + day,
    text: text,
    senderId: 142,
    status: MessageStatus.delivered,
    createdAt: _at(day, 10, 0),
    mediaType: media,
    sharedContentType: shared,
  );
}

final List<Conversation> _listData = <Conversation>[
  _conv(
    id: 1,
    name: 'Al Ananka Store',
    last: _last('Is this still available?', day: 20),
    unread: 3,
  ),
  _conv(
    id: 2,
    name: 'Nile Traders',
    last: _last('Thanks, see you soon.', day: 19),
    unread: 120,
  ),
  _conv(id: 3, name: 'Cairo Fabrics', last: _last('Order confirmed.', day: 18)),
  _conv(
    id: 4,
    name: 'Delta Leather',
    last: _last('', day: 17, media: ChatMediaType.image),
  ),
  _conv(
    id: 5,
    name: 'Sphinx Studio',
    last: _last('', day: 16, shared: SharedContentType.product),
  ),
  _conv(id: 6, name: 'New Contact'),
];

const SharedContent _sharedProduct = SharedContent(
  type: SharedContentType.product,
  objectId: 10,
  available: true,
  businessId: 7,
  businessName: 'Al Ananka Store',
  previewText: 'Leather bag',
);

Message _msg(
  int id,
  int sender,
  String text,
  MessageStatus status,
  int minute, {
  SharedContent? shared,
}) {
  return Message(
    id: id,
    conversationId: 42,
    senderId: sender,
    text: text,
    status: status,
    createdAt: _at(20, 10, minute),
    sharedContent: shared,
  );
}

/// Oldest to newest; own = sender 1, received = sender 7.
final List<Message> _threadOldestFirst = <Message>[
  _msg(1, _me, 'Hello, is this bag still available?', MessageStatus.read, 0),
  _msg(
    2,
    _other,
    'Yes, it is available in two colors.',
    MessageStatus.delivered,
    2,
  ),
  _msg(3, _other, '', MessageStatus.delivered, 3, shared: _sharedProduct),
  _msg(4, _me, 'Great, I will take the brown one.', MessageStatus.delivered, 5),
  _msg(5, _me, 'Thank you!', MessageStatus.sent, 6),
];

final Conversation _threadConversation = Conversation(
  id: 42,
  otherParticipant: ConversationParticipantSummary(
    id: _other,
    accountType: 'business',
    displayName: 'Al Ananka Store',
  ),
  lastMessage: null,
  unreadCount: 0,
  createdAt: _at(1, 9, 0),
);

// --------------------------------------------------------------- goldens

void main() {
  group('P-115 chat goldens', () {
    for (final GoldenCombo c in kGoldenCombos) {
      testWidgets('chat list (${c.tag})', (tester) async {
        await pumpGoldenApp(
          tester,
          c,
          const ChatListScreen(),
          overrides: [
            conversationRepositoryProvider.overrideWithValue(
              _FakeConversationRepository(conversations: _listData),
            ),
          ],
        );
        await expectGolden(_dir, 'chat_list', c);
        await unmountGolden(tester);
      });

      for (final bool typing in <bool>[false, true]) {
        final String name = typing ? 'chat_thread_typing' : 'chat_thread';
        testWidgets('$name (${c.tag})', (tester) async {
          final _FakeChatConnectionManager manager =
              _FakeChatConnectionManager();
          await pumpGoldenApp(
            tester,
            c,
            ChatThreadScreen(conversation: _threadConversation),
            overrides: [
              chatConnectionManagerProvider.overrideWithValue(manager),
              conversationRepositoryProvider.overrideWithValue(
                _FakeConversationRepository(
                  history: _threadOldestFirst.reversed.toList(),
                ),
              ),
              messageRepositoryProvider.overrideWithValue(
                _FakeMessageRepository(),
              ),
              outboundMessageQueueProvider.overrideWith(
                () => OutboundMessageQueueNotifier(),
              ),
            ],
          );

          manager.emitState(ChatConnectionState.connected);
          if (typing) {
            manager.emitEvent(const TypingIndicator(isTyping: true));
          }
          await tester.pump();
          // Finish the one-shot 200 ms scroll-to-bottom animation.
          await tester.pump(const Duration(milliseconds: 300));

          await expectGolden(_dir, name, c);
          await unmountGolden(tester);
          unawaited(manager.close());
        });
      }
    }
  });
}