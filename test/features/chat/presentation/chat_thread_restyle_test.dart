import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/chat/chat_connection_manager.dart';
import 'package:social_commerce_app/core/chat/chat_event.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/chat/data/message_repository.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';
import 'package:social_commerce_app/features/chat/presentation/chat_thread_screen.dart';
import 'package:social_commerce_app/features/chat/presentation/message_bubble_widget.dart';
import 'package:social_commerce_app/features/chat/presentation/outbound_message_queue_provider.dart';

import '../../../goldens/golden_helpers.dart';

/// Part P-115 STEP 3C: tests for the restyled chat thread (presentation
/// only). The send / queue / reconnect / delivery behaviour stays covered by
/// the existing chat tests, which are unchanged. This file is ASCII only.

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

class _FakeConversationRepository extends ConversationRepository {
  _FakeConversationRepository(this.history) : super(Dio());

  /// Newest first, like the wire order.
  final List<Message> history;

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
}

class _FakeMessageRepository extends MessageRepository {
  _FakeMessageRepository() : super(Dio());

  @override
  Future<List<Message>> fetchMessagesSince({
    required int conversationId,
    required int sinceMessageId,
  }) async => <Message>[];
}

const int _me = 1;
const int _other = 7;

final Conversation _conversation = Conversation(
  id: 42,
  otherParticipant: const ConversationParticipantSummary(
    id: _other,
    accountType: 'business',
    displayName: 'Al Ananka Store',
  ),
  lastMessage: null,
  unreadCount: 0,
  createdAt: DateTime(2026, 1, 1, 9),
);

Message _msg(int id, int sender, String text, int day, int minute) {
  return Message(
    id: id,
    conversationId: 42,
    senderId: sender,
    text: text,
    status: MessageStatus.delivered,
    createdAt: DateTime(2026, 1, day, 10, minute),
  );
}

Future<_FakeChatConnectionManager> _pumpThread(
  WidgetTester tester,
  GoldenCombo combo,
  List<Message> oldestFirst,
) async {
  final _FakeChatConnectionManager manager = _FakeChatConnectionManager();
  await pumpGoldenApp(
    tester,
    combo,
    ChatThreadScreen(conversation: _conversation),
    overrides: [
      chatConnectionManagerProvider.overrideWithValue(manager),
      conversationRepositoryProvider.overrideWithValue(
        _FakeConversationRepository(oldestFirst.reversed.toList()),
      ),
      messageRepositoryProvider.overrideWithValue(_FakeMessageRepository()),
      outboundMessageQueueProvider.overrideWith(
        () => OutboundMessageQueueNotifier(),
      ),
    ],
  );
  await tester.pump(const Duration(milliseconds: 300));
  return manager;
}

Future<void> _finish(
  WidgetTester tester,
  _FakeChatConnectionManager manager,
) async {
  await unmountGolden(tester);
  unawaited(manager.close());
}

Finder _bubbleOf(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byType(MessageBubbleWidget),
);

BoxDecoration _decorationOf(WidgetTester tester, Finder bubble) {
  final Container box = tester.widget<Container>(
    find.descendant(of: bubble, matching: find.byType(Container)).first,
  );
  return box.decoration! as BoxDecoration;
}

void main() {
  group('chat thread restyle', () {
    for (final GoldenCombo c in <GoldenCombo>[
      kGoldenCombos[0],
      kGoldenCombos[2],
    ]) {
      testWidgets('bubbles use the colour tokens (${c.tag})', (tester) async {
        final AppColors colors = c.dark ? AppColors.dark : AppColors.light;
        final _FakeChatConnectionManager manager = await _pumpThread(
          tester,
          c,
          <Message>[
            _msg(1, _me, 'mine text', 5, 0),
            _msg(2, _other, 'theirs text', 5, 1),
          ],
        );

        expect(
          _decorationOf(tester, _bubbleOf('mine text')).color,
          colors.brand,
        );
        expect(tester.widget<Text>(find.text('mine text')).style?.color,
            colors.onBrand);
        expect(
          _decorationOf(tester, _bubbleOf('theirs text')).color,
          colors.surfaceVariant,
        );
        expect(tester.widget<Text>(find.text('theirs text')).style?.color,
            colors.textPrimary);

        await _finish(tester, manager);
      });
    }

    testWidgets('consecutive messages from one sender are grouped', (
      tester,
    ) async {
      final _FakeChatConnectionManager manager = await _pumpThread(
        tester,
        kGoldenCombos[0],
        <Message>[
          _msg(1, _me, 'own one', 5, 0),
          _msg(2, _me, 'own two', 5, 1),
          _msg(3, _me, 'own three', 5, 2),
          _msg(4, _other, 'theirs', 5, 3),
          _msg(5, _me, 'own next day', 6, 0),
        ],
      );

      MessageBubbleWidget bubble(String text) =>
          tester.widget<MessageBubbleWidget>(_bubbleOf(text));

      expect(bubble('own one').isFirstInGroup, isTrue);
      expect(bubble('own one').isLastInGroup, isFalse);
      expect(bubble('own two').isFirstInGroup, isFalse);
      expect(bubble('own two').isLastInGroup, isFalse);
      expect(bubble('own three').isFirstInGroup, isFalse);
      expect(bubble('own three').isLastInGroup, isTrue);
      expect(bubble('theirs').isFirstInGroup, isTrue);
      expect(bubble('theirs').isLastInGroup, isTrue);
      // A date separator ends the group.
      expect(bubble('own next day').isFirstInGroup, isTrue);
      expect(bubble('own next day').isLastInGroup, isTrue);

      // Radius 20 everywhere; the sender-side (end) corners are 4 inside a
      // group. Own bubbles sit at the end side.
      BorderRadiusDirectional radius(String text) =>
          _decorationOf(tester, _bubbleOf(text)).borderRadius!
              as BorderRadiusDirectional;
      const Radius big = Radius.circular(20);
      const Radius small = Radius.circular(4);

      expect(radius('own one').topEnd, big);
      expect(radius('own one').bottomEnd, small);
      expect(radius('own two').topEnd, small);
      expect(radius('own two').bottomEnd, small);
      expect(radius('own three').topEnd, small);
      expect(radius('own three').bottomEnd, big);
      expect(radius('own two').topStart, big);
      expect(radius('own two').bottomStart, big);
      expect(radius('theirs').topStart, big);
      expect(radius('theirs').bottomEnd, big);

      await _finish(tester, manager);
    });

    testWidgets('a date separator appears when the calendar day changes', (
      tester,
    ) async {
      final _FakeChatConnectionManager manager = await _pumpThread(
        tester,
        kGoldenCombos[0],
        <Message>[
          _msg(1, _me, 'a', 5, 0),
          _msg(2, _other, 'b', 5, 1),
          _msg(3, _me, 'c', 6, 0),
        ],
      );

      expect(
        find.byKey(const ValueKey('chatThread_dateSeparator')),
        findsNWidgets(2),
      );
      expect(find.text('January 5, 2026'), findsOneWidget);
      expect(find.text('January 6, 2026'), findsOneWidget);

      await _finish(tester, manager);
    });

    testWidgets('typing dots follow the typing event', (tester) async {
      final _FakeChatConnectionManager manager = await _pumpThread(
        tester,
        kGoldenCombos[0],
        <Message>[_msg(1, _other, 'hi', 5, 0)],
      );
      const Key dots = ValueKey('chatThread_typingDots');

      expect(find.byKey(dots), findsNothing);

      manager.emitEvent(const TypingIndicator(isTyping: true));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(dots), findsOneWidget);
      expect(find.text('typing...'), findsNothing);

      manager.emitEvent(const TypingIndicator(isTyping: false));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(dots), findsNothing);

      await _finish(tester, manager);
    });

    for (final GoldenCombo c in <GoldenCombo>[
      kGoldenCombos[0],
      kGoldenCombos[1],
    ]) {
      final bool rtl = c.direction == TextDirection.rtl;
      testWidgets('layout mirrors for ${c.tag}', (tester) async {
        final _FakeChatConnectionManager manager = await _pumpThread(
          tester,
          c,
          <Message>[
            _msg(1, _me, 'mine text', 5, 0),
            _msg(2, _other, 'theirs text', 5, 1),
          ],
        );
        const double middle = 200;

        final double mine = tester.getCenter(find.text('mine text')).dx;
        final double theirs = tester.getCenter(find.text('theirs text')).dx;
        // Own bubbles sit at the END side, received at the START side.
        expect(mine > middle, !rtl);
        expect(theirs > middle, rtl);

        // The send button is at the END of the composer row.
        final double send = tester.getCenter(find.byIcon(Icons.send)).dx;
        final double field = tester.getCenter(find.byType(TextField)).dx;
        expect(send > field, !rtl);

        // The send icon itself is direction-aware (mirrors in RTL).
        final Icon icon = tester.widget<Icon>(find.byIcon(Icons.send));
        expect(icon.icon!.matchTextDirection, isTrue);

        await _finish(tester, manager);
      });
    }
  });
}