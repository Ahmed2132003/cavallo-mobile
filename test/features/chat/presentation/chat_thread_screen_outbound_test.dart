import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/chat/chat_connection_manager.dart';
import 'package:social_commerce_app/core/chat/chat_event.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/chat/data/message_repository.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';
import 'package:social_commerce_app/features/chat/presentation/chat_thread_screen.dart';
import 'package:social_commerce_app/features/chat/presentation/outbound_message_queue_provider.dart';

/// Part P-075 STEP 4 — widget tests for [ChatThreadScreen]'s optimistic
/// send flow (pending bubble -> confirmed message, retry, discard, and
/// failed sends never being hidden).
///
/// Hand-rolled fakes only (this project doesn't use mocktail). Each fake
/// extends the concrete class and overrides just what the screen calls,
/// the same approach `chat_list_screen_test.dart` uses for
/// `ConversationRepository`.

/// Never touches a real socket: connect/disconnect/send* are no-ops and
/// both streams are empty.
class _FakeChatConnectionManager extends ChatConnectionManager {
  _FakeChatConnectionManager()
    : super(
        getAccessToken: () async => null,
        getApiBaseUrl: () => 'http://localhost',
      );

  @override
  Stream<ChatConnectionState> get connectionState =>
      Stream<ChatConnectionState>.empty();

  @override
  Stream<ChatEvent> get eventStream => Stream<ChatEvent>.empty();

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
  _FakeConversationRepository({this.error}) : super(Dio());

  /// When set, the history fetch throws this.
  final Object? error;

  @override
  Future<PaginatedResponse<Message>> fetchMessageHistory(
    int conversationId, {
    String? cursor,
  }) async {
    if (error != null) {
      throw error!;
    }
    return const PaginatedResponse<Message>(
      results: [],
      next: null,
      previous: null,
    );
  }
}

class _ScriptedMessageRepository extends MessageRepository {
  _ScriptedMessageRepository(this._outcomes) : super(Dio());

  /// One entry per call to [sendMessage]: `null` = succeed, non-null =
  /// throw it.
  final List<Object?> _outcomes;

  /// When set, every send blocks on this before resolving — lets a test
  /// observe the in-flight (pending) state deterministically.
  Completer<void>? gate;

  int callCount = 0;

  @override
  Future<Message> sendMessage({
    required int conversationId,
    required String text,
  }) async {
    final outcome = _outcomes[callCount];
    callCount++;
    if (gate != null) {
      await gate!.future;
    }
    if (outcome != null) {
      throw outcome;
    }
    return Message(
      id: 500 + callCount,
      conversationId: conversationId,
      senderId: 1, // != otherParticipant.id (7) => "mine"
      text: text,
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
    );
  }
}

const _networkDown = NetworkFailure(message: 'Network down');
const _forbidden = AuthFailure(message: 'Not allowed.');

Conversation _conversation() {
  return Conversation(
    id: 42,
    otherParticipant: const ConversationParticipantSummary(
      id: 7,
      accountType: 'business',
      displayName: 'Shop',
    ),
    lastMessage: null,
    unreadCount: 0,
    createdAt: DateTime(2026, 9, 1, 9),
  );
}

Future<ProviderContainer> _pumpThread(
  WidgetTester tester, {
  required _ScriptedMessageRepository messages,
  _FakeConversationRepository? conversations,
}) async {
  final container = ProviderContainer(
    overrides: [
      chatConnectionManagerProvider.overrideWithValue(
        _FakeChatConnectionManager(),
      ),
      conversationRepositoryProvider.overrideWithValue(
        conversations ?? _FakeConversationRepository(),
      ),
      messageRepositoryProvider.overrideWithValue(messages),
      outboundMessageQueueProvider.overrideWith(
        () => OutboundMessageQueueNotifier(
          backoffDelayForAttempt: (_) => const Duration(milliseconds: 10),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: ChatThreadScreen(conversation: _conversation())),
    ),
  );
  // Let the history load resolve.
  await tester.pump();
  await tester.pump();
  return container;
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byIcon(Icons.send));
  await tester.pump();
}

/// Unmounts the screen and disposes the container so no queue timer is
/// left pending when the test ends.
Future<void> _teardown(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox.shrink());
  container.dispose();
}

/// Advances fake time enough for the full 5-attempt retry cycle.
Future<void> _pumpThroughRetries(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets(
    'optimistic send: pending bubble shows immediately, field clears, then '
    'becomes the confirmed message (no duplicate)',
    (tester) async {
      final messages = _ScriptedMessageRepository([null])
        ..gate = Completer<void>();
      final container = await _pumpThread(tester, messages: messages);

      await _send(tester, 'hello');

      // Request is still in flight (gated) — pending bubble is visible.
      expect(find.text('hello'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);

      messages.gate!.complete();
      await tester.pump();
      await tester.pump();

      // Same text, exactly once, now a confirmed message (single tick).
      expect(find.text('hello'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsNothing);
      expect(find.byIcon(Icons.done), findsOneWidget);
      expect(container.read(outboundMessageQueueProvider), isEmpty);

      await _teardown(tester, container);
    },
  );

  testWidgets(
    'network failures: retries automatically, ends in "Failed to send · Tap '
    'to retry" after 5 attempts, then tap-to-retry succeeds',
    (tester) async {
      final messages = _ScriptedMessageRepository([
        _networkDown,
        _networkDown,
        _networkDown,
        _networkDown,
        _networkDown,
        null, // succeeds after the manual retry
      ]);
      final container = await _pumpThread(tester, messages: messages);

      await _send(tester, 'hello');
      await _pumpThroughRetries(tester);

      expect(messages.callCount, 5);
      expect(find.text('Failed to send · Tap to retry'), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('outbound_retry_outbound_0')));
      await tester.pump();
      await tester.pump();

      expect(messages.callCount, 6);
      expect(find.text('Failed to send · Tap to retry'), findsNothing);
      expect(find.text('hello'), findsOneWidget);
      expect(find.byIcon(Icons.done), findsOneWidget);
      expect(container.read(outboundMessageQueueProvider), isEmpty);

      await _teardown(tester, container);
    },
  );

  testWidgets('non-retryable failure (403-style) shows failed immediately '
      'after a single call', (tester) async {
    final messages = _ScriptedMessageRepository([_forbidden, null]);
    final container = await _pumpThread(tester, messages: messages);

    await _send(tester, 'hello');
    await tester.pump();
    await _pumpThroughRetries(tester);

    expect(messages.callCount, 1, reason: 'must not retry');
    expect(find.text('Failed to send · Tap to retry'), findsOneWidget);
    expect(find.text('Not allowed.'), findsOneWidget);

    await _teardown(tester, container);
  });

  testWidgets('discarding a failed bubble removes it from the thread', (
    tester,
  ) async {
    final messages = _ScriptedMessageRepository([_forbidden]);
    final container = await _pumpThread(tester, messages: messages);

    await _send(tester, 'hello');
    await tester.pump();
    expect(find.text('Failed to send · Tap to retry'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('outbound_discard_outbound_0')));
    await tester.pump();

    expect(find.text('hello'), findsNothing);
    expect(find.text('Failed to send · Tap to retry'), findsNothing);
    expect(container.read(outboundMessageQueueProvider), isEmpty);

    await _teardown(tester, container);
  });

  testWidgets('a failed send is not hidden behind the history-error view', (
    tester,
  ) async {
    final messages = _ScriptedMessageRepository([_forbidden]);
    final container = await _pumpThread(
      tester,
      messages: messages,
      conversations: _FakeConversationRepository(error: _networkDown),
    );

    // History failed and nothing is pending yet: the error view is shown.
    expect(find.text('Network down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await _send(tester, 'hello');
    await tester.pump();

    // Now the failed bubble must be visible instead of the error view.
    expect(find.text('Failed to send · Tap to retry'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);

    await _teardown(tester, container);
  });

  testWidgets('only this conversation\'s pending messages are shown', (
    tester,
  ) async {
    final messages = _ScriptedMessageRepository([null, null])
      ..gate = Completer<void>();
    final container = await _pumpThread(tester, messages: messages);

    final queue = container.read(outboundMessageQueueProvider.notifier);
    queue.enqueueMessage(conversationId: 999, text: 'other chat');
    queue.enqueueMessage(conversationId: 42, text: 'this chat');
    await tester.pump();

    expect(find.text('this chat'), findsOneWidget);
    expect(find.text('other chat'), findsNothing);

    await _teardown(tester, container);
  });
}