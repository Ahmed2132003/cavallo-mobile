import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/push/fcm_service.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/notifications/domain/app_notification.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_navigator.dart';

class _FakeConversationRepository extends ConversationRepository {
  _FakeConversationRepository({
    this.conversations = const <Conversation>[],
    this.shouldThrow = false,
  }) : super(Dio());

  final List<Conversation> conversations;
  final bool shouldThrow;
  int listCalls = 0;

  @override
  Future<PaginatedResponse<Conversation>> listConversations({
    String? cursor,
  }) async {
    listCalls++;
    if (shouldThrow) throw Exception('boom');
    return PaginatedResponse<Conversation>(
      results: conversations,
      next: null,
      previous: null,
    );
  }
}

Conversation _conversation(int id) {
  return Conversation(
    id: id,
    otherParticipant: null,
    lastMessage: null,
    unreadCount: 0,
    createdAt: DateTime(2026, 9, 30),
  );
}

class _Setup {
  _Setup({
    required this.router,
    required this.navigator,
    required this.repository,
    required this.threadExtras,
  });

  final GoRouter router;
  final NotificationNavigator navigator;
  final _FakeConversationRepository repository;

  /// Every `extra` the `/chat/:id` stub route was built with.
  final List<Object?> threadExtras;
}

/// Starts on `/notifications` (so `push` has something to go back to)
/// with a stub route for every destination the resolver can answer.
Future<_Setup> _pump(
  WidgetTester tester, {
  List<Conversation> conversations = const <Conversation>[],
  bool repositoryThrows = false,
}) async {
  final threadExtras = <Object?>[];
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: <RouteBase>[
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const Text('screen: notifications'),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Text('screen: home'),
      ),
      GoRoute(
        path: '/business/:id',
        builder:
            (context, state) =>
                Text('screen: business ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/post/:id',
        builder:
            (context, state) =>
                Text('screen: post ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/reel/:id',
        builder:
            (context, state) =>
                Text('screen: reel ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/product/:id',
        builder:
            (context, state) =>
                Text('screen: product ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const Text('screen: chat list'),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          threadExtras.add(state.extra);
          return Text('screen: chat thread ${state.pathParameters['id']}');
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  final repository = _FakeConversationRepository(
    conversations: conversations,
    shouldThrow: repositoryThrows,
  );
  final navigator = NotificationNavigator(
    router: router,
    conversationRepository: repository,
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  expect(find.text('screen: notifications'), findsOneWidget);

  return _Setup(
    router: router,
    navigator: navigator,
    repository: repository,
    threadExtras: threadExtras,
  );
}

void main() {
  group('the four plain destinations', () {
    const cases = <(String, String)>[
      ('business_profile', 'screen: business 5'),
      ('post_detail', 'screen: post 5'),
      ('reel_detail', 'screen: reel 5'),
      ('product_detail', 'screen: product 5'),
    ];

    for (final (type, expectedText) in cases) {
      testWidgets('$type + 5 pushes its screen', (tester) async {
        final setup = await _pump(tester);

        await setup.navigator.open(deepLinkType: type, targetId: 5);
        await tester.pumpAndSettle();

        expect(find.text(expectedText), findsOneWidget);
        expect(setup.router.canPop(), isTrue);
        // No conversation lookup for a non-chat destination.
        expect(setup.repository.listCalls, 0);
      });
    }
  });

  group('chat_thread', () {
    testWidgets('opens the thread with the Conversation as extra', (
      tester,
    ) async {
      final target = _conversation(101);
      final setup = await _pump(
        tester,
        conversations: [_conversation(7), target],
      );

      await setup.navigator.open(deepLinkType: 'chat_thread', targetId: 101);
      await tester.pumpAndSettle();

      expect(find.text('screen: chat thread 101'), findsOneWidget);
      expect(setup.threadExtras, [same(target)]);
      expect(setup.repository.listCalls, 1);
      expect(setup.router.canPop(), isTrue);
    });

    testWidgets('falls back to the chat list when the conversation is '
        'not in the list', (tester) async {
      final setup = await _pump(tester, conversations: [_conversation(7)]);

      await setup.navigator.open(deepLinkType: 'chat_thread', targetId: 101);
      await tester.pumpAndSettle();

      expect(find.text('screen: chat list'), findsOneWidget);
      expect(setup.threadExtras, isEmpty);
    });

    testWidgets('falls back to the chat list when the lookup fails', (
      tester,
    ) async {
      final setup = await _pump(tester, repositoryThrows: true);

      await setup.navigator.open(deepLinkType: 'chat_thread', targetId: 101);
      await tester.pumpAndSettle();

      expect(find.text('screen: chat list'), findsOneWidget);
      expect(setup.threadExtras, isEmpty);
    });

    testWidgets('a missing target id goes home without any lookup', (
      tester,
    ) async {
      final setup = await _pump(tester, conversations: [_conversation(101)]);

      await setup.navigator.open(deepLinkType: 'chat_thread', targetId: null);
      await tester.pumpAndSettle();

      expect(find.text('screen: home'), findsOneWidget);
      expect(setup.repository.listCalls, 0);
    });
  });

  group('fallbacks', () {
    testWidgets('an unknown deep_link_type goes home', (tester) async {
      final setup = await _pump(tester);

      await setup.navigator.open(deepLinkType: 'something_new', targetId: 5);
      await tester.pumpAndSettle();

      expect(find.text('screen: home'), findsOneWidget);
    });

    testWidgets('a known type with a null id goes home', (tester) async {
      final setup = await _pump(tester);

      await setup.navigator.open(
        deepLinkType: 'business_profile',
        targetId: null,
      );
      await tester.pumpAndSettle();

      expect(find.text('screen: home'), findsOneWidget);
    });

    testWidgets('a blank deep_link_type navigates nowhere', (tester) async {
      final setup = await _pump(tester);

      await setup.navigator.open(deepLinkType: '', targetId: null);
      await setup.navigator.open(deepLinkType: '   ', targetId: 5);
      await tester.pumpAndSettle();

      expect(find.text('screen: notifications'), findsOneWidget);
      expect(setup.repository.listCalls, 0);
    });
  });

  group('the two convenience entry points share the same logic', () {
    testWidgets('openNotification uses the notification\'s own fields', (
      tester,
    ) async {
      final setup = await _pump(tester);
      final notification = AppNotification(
        id: 1,
        notificationType: 'new_follower',
        title: 'New follower',
        body: 'Someone followed you',
        deepLinkType: 'business_profile',
        targetId: 9,
        isRead: false,
        createdAt: DateTime(2026, 9, 30),
      );

      await setup.navigator.openNotification(notification);
      await tester.pumpAndSettle();

      expect(find.text('screen: business 9'), findsOneWidget);
    });

    testWidgets('openPush uses the push deep link', (tester) async {
      final setup = await _pump(tester, conversations: [_conversation(33)]);

      await setup.navigator.openPush(
        const PushDeepLink(type: 'chat_thread', targetId: 33),
      );
      await tester.pumpAndSettle();

      expect(find.text('screen: chat thread 33'), findsOneWidget);
      expect(setup.threadExtras.single, isA<Conversation>());
    });
  });
}
