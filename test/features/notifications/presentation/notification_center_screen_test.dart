import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/notifications/data/notification_repository_impl.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_center_screen.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_navigator.dart';

import '../fake_notification_repository.dart';

/// Real router + real [NotificationNavigator] (the single navigation
/// point), with stub destination screens. Only the repository is faked.
Future<GoRouter> _pump(
  WidgetTester tester,
  FakeNotificationRepository repository,
) async {
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: <RouteBase>[
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
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
    ],
  );
  addTearDown(router.dispose);

  // Not used by these tests (no chat_thread notification is tapped).
  final navigator = NotificationNavigator(
    router: router,
    conversationRepository: ConversationRepository(Dio()),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
        notificationNavigatorProvider.overrideWithValue(navigator),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder _unreadDot(int id) =>
    find.byKey(ValueKey('notification-unread-dot-$id'));

void main() {
  group('rendering', () {
    testWidgets('distinguishes unread from read items', (tester) async {
      final repository = FakeNotificationRepository(
        pages: {
          null: fakePage([
            fakeNotification(2),
            fakeNotification(1, isRead: true),
          ]),
        },
      );
      await _pump(tester, repository);

      expect(find.text('Title 2'), findsOneWidget);
      expect(find.text('Body 2'), findsOneWidget);
      expect(find.text('Title 1'), findsOneWidget);

      // Unread: dot + bold. Read: no dot + regular weight.
      expect(_unreadDot(2), findsOneWidget);
      expect(_unreadDot(1), findsNothing);
      expect(
        tester.widget<Text>(find.text('Title 2')).style?.fontWeight,
        FontWeight.w700,
      );
      expect(
        tester.widget<Text>(find.text('Title 1')).style?.fontWeight,
        FontWeight.w400,
      );
    });

    testWidgets('shows the empty state when there are no notifications', (
      tester,
    ) async {
      final repository = FakeNotificationRepository(
        pages: {null: fakePage([])},
      );
      await _pump(tester, repository);

      expect(find.text('No notifications yet.'), findsOneWidget);
    });

    testWidgets('shows an error with Retry, and Retry reloads the list', (
      tester,
    ) async {
      final repository = FakeNotificationRepository(
        pages: {
          null: fakePage([fakeNotification(1)]),
        },
      );
      repository.listErrors[null] = Exception('boom');
      await _pump(tester, repository);

      expect(find.text('Could not load your notifications.'), findsOneWidget);

      repository.listErrors.remove(null);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Title 1'), findsOneWidget);
    });
  });

  group('tapping', () {
    testWidgets('marks an unread notification read and navigates', (
      tester,
    ) async {
      final repository = FakeNotificationRepository(
        pages: {
          null: fakePage([fakeNotification(2)]),
        },
      );
      final router = await _pump(tester, repository);

      await tester.tap(find.text('Title 2'));
      await tester.pumpAndSettle();

      // fakeNotification defaults: business_profile + target 7.
      expect(repository.markReadCalls, [2]);
      expect(find.text('screen: business 7'), findsOneWidget);
      expect(router.canPop(), isTrue);

      // Back on the list, the item is now read.
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Title 2'), findsOneWidget);
      expect(_unreadDot(2), findsNothing);
    });

    testWidgets('an already-read notification navigates without mark-read', (
      tester,
    ) async {
      final repository = FakeNotificationRepository(
        pages: {
          null: fakePage([fakeNotification(1, isRead: true)]),
        },
      );
      await _pump(tester, repository);

      await tester.tap(find.text('Title 1'));
      await tester.pumpAndSettle();

      expect(repository.markReadCalls, isEmpty);
      expect(find.text('screen: business 7'), findsOneWidget);
    });

    testWidgets('a failed mark-read still navigates', (tester) async {
      final repository = FakeNotificationRepository(
        pages: {
          null: fakePage([fakeNotification(2)]),
        },
      );
      repository.markReadError = Exception('offline');
      await _pump(tester, repository);

      await tester.tap(find.text('Title 2'));
      await tester.pumpAndSettle();

      expect(find.text('screen: business 7'), findsOneWidget);
    });

    testWidgets('a notification with no destination is only marked read', (
      tester,
    ) async {
      final repository = FakeNotificationRepository(
        pages: {
          null: fakePage([
            fakeNotification(3, deepLinkType: '', targetId: null),
          ]),
        },
      );
      await _pump(tester, repository);

      await tester.tap(find.text('Title 3'));
      await tester.pumpAndSettle();

      expect(repository.markReadCalls, [3]);
      expect(find.text('Title 3'), findsOneWidget); // still on the list
      expect(_unreadDot(3), findsNothing);
      expect(find.text('screen: home'), findsNothing);
    });
  });

  group('pagination', () {
    testWidgets('scrolling near the end loads the next page', (tester) async {
      final repository = FakeNotificationRepository(
        pages: {
          null: fakePage([
            for (var id = 1; id <= 30; id++) fakeNotification(id),
          ], next: 'a'),
          'a': fakePage([fakeNotification(31)]),
        },
      );
      await _pump(tester, repository);
      expect(repository.listCursors, [null]);

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();

      expect(repository.listCursors, [null, 'a']);
      await tester.scrollUntilVisible(find.text('Title 31'), 300);
      expect(find.text('Title 31'), findsOneWidget);
    });
  });
}
