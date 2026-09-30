import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/notifications/data/notification_repository_impl.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_list_provider.dart';

import '../fake_notification_repository.dart';

ProviderContainer _container(FakeNotificationRepository fake) {
  final container = ProviderContainer(
    overrides: [notificationRepositoryProvider.overrideWithValue(fake)],
  );
  // The provider is autoDispose: keep it alive for the whole test.
  container.listen(notificationListProvider, (previous, next) {});
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('build() loads the first page with a null cursor', () async {
    final fake = FakeNotificationRepository(
      pages: {
        null: fakePage([
          fakeNotification(2),
          fakeNotification(1, isRead: true),
        ], next: 'cursor-a'),
      },
    );
    final container = _container(fake);

    final state = await container.read(notificationListProvider.future);

    expect(state.items.map((n) => n.id), [2, 1]);
    expect(state.nextCursor, 'cursor-a');
    expect(state.isLoadingMore, isFalse);
    expect(state.unreadCount, 1);
    expect(fake.listCursors, [null]);
  });

  test(
    'loadMore() appends, advances the cursor and clears it at the end',
    () async {
      final fake = FakeNotificationRepository(
        pages: {
          null: fakePage([fakeNotification(3)], next: 'a'),
          'a': fakePage([fakeNotification(2)], next: 'b'),
          'b': fakePage([fakeNotification(1)]),
        },
      );
      final container = _container(fake);
      await container.read(notificationListProvider.future);
      final notifier = container.read(notificationListProvider.notifier);

      await notifier.loadMore();
      var state = container.read(notificationListProvider).value!;
      expect(state.items.map((n) => n.id), [3, 2]);
      expect(state.nextCursor, 'b');

      await notifier.loadMore();
      state = container.read(notificationListProvider).value!;
      expect(state.items.map((n) => n.id), [3, 2, 1]);
      expect(state.nextCursor, isNull);
      expect(fake.listCursors, [null, 'a', 'b']);
    },
  );

  test('loadMore() is a no-op when there is no next cursor', () async {
    final fake = FakeNotificationRepository(
      pages: {
        null: fakePage([fakeNotification(1)]),
      },
    );
    final container = _container(fake);
    await container.read(notificationListProvider.future);

    await container.read(notificationListProvider.notifier).loadMore();

    expect(fake.listCursors, [null]);
  });

  test('loadMore() failure keeps the loaded items and rethrows', () async {
    final fake = FakeNotificationRepository(
      pages: {
        null: fakePage([fakeNotification(2)], next: 'a'),
      },
    )..listErrors['a'] = StateError('boom');
    final container = _container(fake);
    await container.read(notificationListProvider.future);

    await expectLater(
      container.read(notificationListProvider.notifier).loadMore(),
      throwsA(isA<StateError>()),
    );

    final state = container.read(notificationListProvider).value!;
    expect(state.items, hasLength(1));
    expect(state.isLoadingMore, isFalse);
    expect(state.nextCursor, 'a');
  });

  test('markAsRead() marks the item read after the server answers', () async {
    final fake = FakeNotificationRepository(
      pages: {
        null: fakePage([fakeNotification(2), fakeNotification(1)]),
      },
    );
    final container = _container(fake);
    await container.read(notificationListProvider.future);

    final ok = await container
        .read(notificationListProvider.notifier)
        .markAsRead(2);

    expect(ok, isTrue);
    expect(fake.markReadCalls, [2]);
    final state = container.read(notificationListProvider).value!;
    expect(state.items[0].isRead, isTrue);
    expect(state.items[1].isRead, isFalse);
    expect(state.unreadCount, 1);
  });

  test('markAsRead() makes no network call for an already-read item', () async {
    final fake = FakeNotificationRepository(
      pages: {
        null: fakePage([fakeNotification(1, isRead: true)]),
      },
    );
    final container = _container(fake);
    await container.read(notificationListProvider.future);

    final ok = await container
        .read(notificationListProvider.notifier)
        .markAsRead(1);

    expect(ok, isTrue);
    expect(fake.markReadCalls, isEmpty);
  });

  test(
    'markAsRead() failure returns false and leaves the item unread',
    () async {
      final fake = FakeNotificationRepository(
        pages: {
          null: fakePage([fakeNotification(1)]),
        },
      )..markReadError = StateError('boom');
      final container = _container(fake);
      await container.read(notificationListProvider.future);

      final ok = await container
          .read(notificationListProvider.notifier)
          .markAsRead(1);

      expect(ok, isFalse);
      final state = container.read(notificationListProvider).value!;
      expect(state.items.single.isRead, isFalse);
    },
  );

  test(
    'markAsRead() for an id not in the list still calls the server',
    () async {
      final fake = FakeNotificationRepository(
        pages: {
          null: fakePage([fakeNotification(1)]),
        },
      );
      final container = _container(fake);
      await container.read(notificationListProvider.future);

      final ok = await container
          .read(notificationListProvider.notifier)
          .markAsRead(99);

      expect(ok, isTrue);
      expect(fake.markReadCalls, [99]);
      final state = container.read(notificationListProvider).value!;
      expect(state.items.map((n) => n.id), [1]);
      expect(state.items.single.isRead, isFalse);
    },
  );

  test('refresh() replaces the list with a fresh first page', () async {
    final fake = FakeNotificationRepository(
      pages: {
        null: fakePage([fakeNotification(1)], next: 'a'),
      },
    );
    final container = _container(fake);
    await container.read(notificationListProvider.future);

    fake.pages[null] = fakePage([fakeNotification(5)]);
    await container.read(notificationListProvider.notifier).refresh();

    final state = container.read(notificationListProvider).value!;
    expect(state.items.map((n) => n.id), [5]);
    expect(state.nextCursor, isNull);
    expect(fake.listCursors, [null, null]);
  });
}
