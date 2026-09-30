import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/chat/data/message_repository.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';
import 'package:social_commerce_app/features/chat/domain/shared_content.dart';
import 'package:social_commerce_app/features/chat/presentation/share_to_conversation_sheet.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/social/presentation/content_action_row.dart';
import 'package:social_commerce_app/routing/route_names.dart';

import '../../social/fake_social_interaction_repository.dart';

/// Part P-077 STEP 4 — the Share icon's two options and the
/// conversation picker: listing, sending the shared reference,
/// navigating into the thread, and failure handling.

class _FakeConversationRepository extends ConversationRepository {
  _FakeConversationRepository(this.conversations) : super(Dio());

  final List<Conversation> conversations;

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
}

class _FakeMessageRepository extends MessageRepository {
  _FakeMessageRepository() : super(Dio());

  Object? errorToThrow;
  final List<({int conversationId, SharedContentType type, int objectId})>
  sent = [];

  @override
  Future<Message> sendSharedContentMessage({
    required int conversationId,
    required SharedContentType contentType,
    required int objectId,
    String text = '',
  }) async {
    final error = errorToThrow;
    if (error != null) throw error;
    sent.add((
      conversationId: conversationId,
      type: contentType,
      objectId: objectId,
    ));
    return Message(
      id: 1,
      conversationId: conversationId,
      senderId: 1,
      text: text,
      status: MessageStatus.sent,
      createdAt: DateTime(2026, 1, 1),
    );
  }
}

Conversation _conversation(int id, String name) {
  return Conversation(
    id: id,
    otherParticipant: ConversationParticipantSummary(
      id: id + 100,
      accountType: 'business',
      displayName: name,
    ),
    lastMessage: null,
    unreadCount: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

/// Hosts [body] on '/', with a stub `chatThread` route that prints
/// `THREAD_<id>` and records the `extra` it was given.
Future<void> _pump(
  WidgetTester tester, {
  required Widget body,
  required _FakeConversationRepository conversations,
  required _FakeMessageRepository messages,
  required List<Object?> openedExtras,
  FakeSocialInteractionRepository? social,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: body),
      ),
      GoRoute(
        path: RouteNames.chatThreadPath,
        name: RouteNames.chatThread,
        builder: (context, state) {
          openedExtras.add(state.extra);
          return Scaffold(
            body: Text('THREAD_${state.pathParameters[RouteNames.idParam]}'),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(conversations),
        messageRepositoryProvider.overrideWithValue(messages),
        socialInteractionRepositoryProvider.overrideWithValue(
          social ?? FakeSocialInteractionRepository(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _openButton({
  required SharedContentType type,
  required int objectId,
  required void Function() onNative,
  required void Function() onTracked,
}) {
  return Builder(
    builder: (context) => ElevatedButton(
      onPressed: () => showShareOptionsSheet(
        context,
        contentType: type,
        objectId: objectId,
        onNativeShare: () async => onNative(),
        onSharedToConversation: () async => onTracked(),
      ),
      child: const Text('open'),
    ),
  );
}

void main() {
  late _FakeMessageRepository messages;
  late List<Object?> openedExtras;

  setUp(() {
    messages = _FakeMessageRepository();
    openedExtras = [];
  });

  testWidgets('the sheet offers both options; "Share via" runs the native flow',
      (tester) async {
    var nativeCalls = 0;
    await _pump(
      tester,
      body: _openButton(
        type: SharedContentType.post,
        objectId: 42,
        onNative: () => nativeCalls++,
        onTracked: () {},
      ),
      conversations: _FakeConversationRepository([]),
      messages: messages,
      openedExtras: openedExtras,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shareOption_native')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shareOption_conversation')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('shareOption_native')));
    await tester.pumpAndSettle();

    expect(nativeCalls, 1);
    expect(messages.sent, isEmpty);
  });

  testWidgets('picking a conversation sends the reference and opens the thread',
      (tester) async {
    var tracked = 0;
    await _pump(
      tester,
      body: _openButton(
        type: SharedContentType.product,
        objectId: 9,
        onNative: () {},
        onTracked: () => tracked++,
      ),
      conversations: _FakeConversationRepository([
        _conversation(5, 'Al Anaqa Store'),
        _conversation(6, 'Cavallo Trading'),
      ]),
      messages: messages,
      openedExtras: openedExtras,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shareOption_conversation')));
    await tester.pumpAndSettle();

    expect(find.text('Al Anaqa Store'), findsOneWidget);
    expect(find.text('Cavallo Trading'), findsOneWidget);

    await tester.tap(find.text('Al Anaqa Store'));
    await tester.pumpAndSettle();

    expect(messages.sent, hasLength(1));
    expect(messages.sent.single.conversationId, 5);
    expect(messages.sent.single.type, SharedContentType.product);
    expect(messages.sent.single.objectId, 9);
    expect(tracked, 1);

    expect(find.text('THREAD_5'), findsOneWidget);
    expect(openedExtras.single, isA<Conversation>());
    expect((openedExtras.single! as Conversation).id, 5);
  });

  testWidgets('a failed send keeps the picker open and navigates nowhere',
      (tester) async {
    messages.errorToThrow = Exception('boom');
    await _pump(
      tester,
      body: _openButton(
        type: SharedContentType.reel,
        objectId: 3,
        onNative: () {},
        onTracked: () {},
      ),
      conversations: _FakeConversationRepository([
        _conversation(5, 'Al Anaqa Store'),
      ]),
      messages: messages,
      openedExtras: openedExtras,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shareOption_conversation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Al Anaqa Store'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Could not share. Please try again.'), findsOneWidget);
    expect(find.text('Share to conversation'), findsWidgets);
    expect(find.textContaining('THREAD_'), findsNothing);
    expect(messages.sent, isEmpty);
    expect(openedExtras, isEmpty);
  });

  testWidgets('no conversations shows the empty state', (tester) async {
    await _pump(
      tester,
      body: _openButton(
        type: SharedContentType.post,
        objectId: 1,
        onNative: () {},
        onTracked: () {},
      ),
      conversations: _FakeConversationRepository([]),
      messages: messages,
      openedExtras: openedExtras,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shareOption_conversation')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sharePicker_empty')), findsOneWidget);
  });

  testWidgets(
    'ContentActionRow: the Share icon opens the options; sharing to a '
    'conversation sends the post and tracks the share',
    (tester) async {
      final social = FakeSocialInteractionRepository();
      await _pump(
        tester,
        body: ContentActionRow(
          contentType: 'post',
          objectId: 1,
          onCommentTap: () {},
        ),
        conversations: _FakeConversationRepository([
          _conversation(5, 'Al Anaqa Store'),
        ]),
        messages: messages,
        openedExtras: openedExtras,
        social: social,
      );

      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shareOption_conversation')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('shareOption_conversation')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Al Anaqa Store'));
      await tester.pumpAndSettle();

      expect(messages.sent.single.type, SharedContentType.post);
      expect(messages.sent.single.objectId, 1);
      expect(social.calls, contains('share:post:1'));
      expect(find.text('THREAD_5'), findsOneWidget);
    },
  );
}