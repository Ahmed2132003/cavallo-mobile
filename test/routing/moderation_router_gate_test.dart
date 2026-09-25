import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/login_screen.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/feed/presentation/home_feed_screen.dart';
import 'package:social_commerce_app/features/moderation/data/moderation_repository_impl.dart';
import 'package:social_commerce_app/features/moderation/domain/moderation_repository.dart';
import 'package:social_commerce_app/features/moderation/domain/queue_item_entity.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_queue_screen.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_review_screen.dart';
import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-040 scope: router tests for the moderator gate added to
/// `app_router.dart`'s `redirect` callback — the third gate, layered on
/// the base auth gate (P-021b) and the Business-account gate (P-028C1),
/// which are not re-tested here (`app_router_redirect_test.dart` and
/// `business_profile_router_gate_test.dart` own those).
///
/// What these prove, per the part's acceptance criteria: a session with
/// neither `isModerator` nor `isStaff` cannot reach `/moderation` (or
/// anything under it) by any route change — `router.go`/`goNamed` here
/// stand in for a manually typed deep link — and is sent to `/home`
/// instead of seeing a broken or empty screen, while either flag alone
/// is enough to get in.
///
/// [sessionProvider] is overridden with a fake notifier that resolves
/// immediately to a fixed user (same approach as
/// `app_router_redirect_test.dart`). [moderationRepositoryProvider] is
/// overridden so the moderator cases never touch a real backend.
class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._fixedValue);

  final User? _fixedValue;

  @override
  Future<User?> build() async => _fixedValue;
}

class _FakeModerationRepository implements ModerationRepository {
  _FakeModerationRepository(this._items);

  final List<QueueItem> _items;

  @override
  Future<PaginatedResponse<QueueItem>> fetchQueue({
    QueuePriority? priority,
  }) async {
    return PaginatedResponse<QueueItem>(
      results: List.of(_items),
      next: null,
      previous: null,
    );
  }

  @override
  Future<QueueItem> approve(int queueItemId) =>
      throw UnimplementedError('Not exercised by moderation_router_gate_test');

  @override
  Future<QueueItem> reject({
    required int queueItemId,
    required String reason,
  }) => throw UnimplementedError(
    'Not exercised by moderation_router_gate_test',
  );
}

const _customer = User(
  id: 1,
  email: 'customer@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

const _moderator = User(
  id: 2,
  email: 'mod@example.com',
  accountType: AccountType.customer,
  isModerator: true,
  isStaff: false,
);

const _staff = User(
  id: 3,
  email: 'staff@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: true,
);

QueueItem _queueItem(int id) {
  return QueueItem(
    id: id,
    contentType: 'post',
    status: QueueItemStatus.pending,
    priority: QueuePriority.normal,
    createdAt: DateTime.utc(2026, 9, 20, 10),
    ageDuration: const Duration(minutes: 5),
    previewText: 'Preview $id',
  );
}

/// Pumps the real router from [appRouterProvider] with [sessionValue] as
/// the session, and returns it so tests can drive navigation.
Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  required User? sessionValue,
  List<QueueItem> queueItems = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSessionNotifier(sessionValue)),
      moderationRepositoryProvider.overrideWithValue(
        _FakeModerationRepository(queueItems),
      ),
    ],
  );
  addTearDown(container.dispose);

  // Let the fake SessionNotifier.build() resolve before the router's
  // first redirect evaluation runs against it.
  await container.read(sessionProvider.future);

  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// The router's current location as a plain path string.
String _currentPath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  group('moderator gate — blocked accounts', () {
    testWidgets('signed out: /moderation bounces to /login (base gate)', (
      tester,
    ) async {
      final router = await _pumpRouter(tester, sessionValue: null);

      router.go(RouteNames.moderationPath);
      await tester.pumpAndSettle();

      expect(_currentPath(router), RouteNames.loginPath);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ModerationQueueScreen), findsNothing);
    });

    testWidgets(
      'a plain user (neither flag) navigating straight to /moderation is '
      'redirected to /home, not shown the queue',
      (tester) async {
        final router = await _pumpRouter(tester, sessionValue: _customer);
        expect(_currentPath(router), RouteNames.homePath);

        router.go(RouteNames.moderationPath);
        await tester.pumpAndSettle();

        expect(_currentPath(router), RouteNames.homePath);
        expect(find.byType(HomeFeedScreen), findsOneWidget);
        expect(find.byType(ModerationQueueScreen), findsNothing);
      },
    );

    testWidgets('the same block applies by route name', (tester) async {
      final router = await _pumpRouter(tester, sessionValue: _customer);

      router.goNamed(RouteNames.moderation);
      await tester.pumpAndSettle();

      expect(_currentPath(router), RouteNames.homePath);
      expect(find.byType(ModerationQueueScreen), findsNothing);
    });

    testWidgets(
      'a plain user cannot reach the review route either, even when '
      'supplying a valid item as extra',
      (tester) async {
        final router = await _pumpRouter(tester, sessionValue: _customer);

        router.go(RouteNames.moderationReviewPath, extra: _queueItem(5));
        await tester.pumpAndSettle();

        expect(_currentPath(router), RouteNames.homePath);
        expect(find.byType(ModerationReviewScreen), findsNothing);
        expect(find.byType(ModerationQueueScreen), findsNothing);
      },
    );
  });

  group('moderator gate — permitted accounts', () {
    testWidgets('isModerator alone is enough to reach /moderation', (
      tester,
    ) async {
      final router = await _pumpRouter(tester, sessionValue: _moderator);

      router.go(RouteNames.moderationPath);
      await tester.pumpAndSettle();

      expect(_currentPath(router), RouteNames.moderationPath);
      expect(find.byType(ModerationQueueScreen), findsOneWidget);
    });

    testWidgets('isStaff alone is enough to reach /moderation', (tester) async {
      final router = await _pumpRouter(tester, sessionValue: _staff);

      router.goNamed(RouteNames.moderation);
      await tester.pumpAndSettle();

      expect(_currentPath(router), RouteNames.moderationPath);
      expect(find.byType(ModerationQueueScreen), findsOneWidget);
    });

    testWidgets(
      'tapping a queue row opens the review screen for that item',
      (tester) async {
        final router = await _pumpRouter(
          tester,
          sessionValue: _moderator,
          queueItems: [_queueItem(5)],
        );

        router.go(RouteNames.moderationPath);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('queue-row-5')));
        await tester.pumpAndSettle();

        // Not asserting `_currentPath(router)` here on purpose: the review
        // screen is opened with `pushNamed`, and for an imperatively
        // pushed route go_router's `currentConfiguration.uri` keeps
        // reporting the underlying location (`/moderation`), not the
        // pushed one. What matters is that the review screen is showing
        // for the tapped item.
        expect(find.byType(ModerationReviewScreen), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ModerationReviewScreen),
            matching: find.text('Preview 5'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the review route without an item (a deep link or restored '
      'location) goes back to the queue instead of a broken screen',
      (tester) async {
        final router = await _pumpRouter(tester, sessionValue: _moderator);

        router.go(RouteNames.moderationReviewPath);
        await tester.pumpAndSettle();

        expect(_currentPath(router), RouteNames.moderationPath);
        expect(find.byType(ModerationQueueScreen), findsOneWidget);
        expect(find.byType(ModerationReviewScreen), findsNothing);
      },
    );
  });
}