import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/orders/data/orders_repository.dart';
import 'package:social_commerce_app/features/orders/domain/order_note.dart';
import 'package:social_commerce_app/features/orders/domain/order_status.dart';
import 'package:social_commerce_app/features/orders/domain/order_status_event.dart';
import 'package:social_commerce_app/features/orders/domain/order_summary.dart';
import 'package:social_commerce_app/features/orders/presentation/orders_providers.dart';

import '../orders_test_helpers.dart';

ProviderContainer _container(FakeOrdersRepository repo) {
  final container = ProviderContainer(
    overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('pure helpers', () {
    final orders = [
      testOrder(id: 1, status: OrderStatus.pending),
      testOrder(id: 2, status: OrderStatus.pending),
      testOrder(id: 3, status: OrderStatus.shipped),
      testOrder(id: 4, status: OrderStatus.unknown),
    ];

    test('ordersCountByStatus has every lifecycle status, unknown ignored', () {
      final counts = ordersCountByStatus(orders);
      expect(counts.keys.toSet(), OrderStatus.lifecycle.toSet());
      expect(counts[OrderStatus.pending], 2);
      expect(counts[OrderStatus.shipped], 1);
      expect(counts[OrderStatus.delivered], 0);
    });

    test('filterOrdersByStatus: null is All', () {
      expect(filterOrdersByStatus(orders, null), hasLength(4));
      expect(
        filterOrdersByStatus(orders, OrderStatus.pending).map((o) => o.id),
        <int>[1, 2],
      );
      expect(filterOrdersByStatus(orders, OrderStatus.cancelled), isEmpty);
    });
  });

  group('ordersListProvider', () {
    test('follows the cursor across pages and is not truncated', () async {
      final repo =
          FakeOrdersRepository()
            ..pages = [
              [testOrder(id: 1)],
              [testOrder(id: 2)],
            ];
      final container = _container(repo);
      final sub = container.listen(ordersListProvider(''), (_, __) {});
      addTearDown(sub.close);

      final snapshot = await container.read(ordersListProvider('').future);

      expect(snapshot.orders.map((o) => o.id), <int>[1, 2]);
      expect(snapshot.truncated, isFalse);
      expect(repo.listCalls, 2);
    });

    test('stops at kOrdersMaxPages and reports truncated', () async {
      final repo =
          FakeOrdersRepository()
            ..pages = List.generate(
              kOrdersMaxPages + 3,
              (i) => [testOrder(id: i + 1)],
            );
      final container = _container(repo);
      final sub = container.listen(ordersListProvider(''), (_, __) {});
      addTearDown(sub.close);

      final snapshot = await container.read(ordersListProvider('').future);

      expect(repo.listCalls, kOrdersMaxPages);
      expect(snapshot.orders, hasLength(kOrdersMaxPages));
      expect(snapshot.truncated, isTrue);
    });

    test('forwards the search text', () async {
      final repo = FakeOrdersRepository();
      final container = _container(repo);
      final sub = container.listen(ordersListProvider('ORD-9'), (_, __) {});
      addTearDown(sub.close);

      await container.read(ordersListProvider('ORD-9').future);

      expect(repo.searches.single, 'ORD-9');
    });

    test('a repository failure becomes the provider error', () async {
      final repo =
          FakeOrdersRepository()
            ..listError = const NetworkFailure(message: 'down');
      final container = _container(repo);
      final sub = container.listen(ordersListProvider(''), (_, __) {});
      addTearDown(sub.close);

      await expectLater(
        container.read(ordersListProvider('').future),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('chatOrderLiveProvider', () {
    final detail = CustomerOrderDetail(
      order: testOrder(customerNote: 'Thanks'),
      events: OrderEvents(
        timeline: [
          OrderStatusEvent(
            id: 2,
            type: OrderEventType.statusChanged,
            fromStatus: OrderStatus.pending,
            toStatus: OrderStatus.confirmed,
            note: 'Ships Sunday',
            createdAt: DateTime.utc(2026, 11, 18, 13),
          ),
        ],
        notes: [
          OrderNote(
            id: 3,
            note: 'SECRET',
            isInternal: true,
            createdAt: DateTime.utc(2026, 11, 18, 13),
          ),
          OrderNote(
            id: 4,
            note: 'Visible',
            isInternal: false,
            createdAt: DateTime.utc(2026, 11, 18, 13),
          ),
        ],
      ),
    );

    test(
      'customer: only customer-visible notes, internal ones filtered',
      () async {
        final repo = FakeOrdersRepository()..myOrder = detail;
        final container = _container(repo);
        const key = ChatOrderKey(orderId: 5, asMerchant: false);
        final sub = container.listen(chatOrderLiveProvider(key), (_, __) {});
        addTearDown(sub.close);

        final live = await container.read(chatOrderLiveProvider(key).future);

        expect(live.visibleNotes, <String>['Ships Sunday', 'Visible']);
        expect(live.visibleNotes, isNot(contains('SECRET')));
      },
    );

    test(
      'merchant: uses the merchant endpoint and shows no notes on the card',
      () async {
        final repo =
            FakeOrdersRepository()
              ..order = testOrder(internalNote: 'VIP')
              ..myOrder = detail;
        final container = _container(repo);
        const key = ChatOrderKey(orderId: 5, asMerchant: true);
        final sub = container.listen(chatOrderLiveProvider(key), (_, __) {});
        addTearDown(sub.close);

        final live = await container.read(chatOrderLiveProvider(key).future);

        expect(live.order.internalNote, 'VIP');
        expect(live.visibleNotes, isEmpty);
      },
    );

    test('ChatOrderKey equality', () {
      expect(
        const ChatOrderKey(orderId: 1, asMerchant: true),
        const ChatOrderKey(orderId: 1, asMerchant: true),
      );
      expect(
        const ChatOrderKey(orderId: 1, asMerchant: true),
        isNot(const ChatOrderKey(orderId: 1, asMerchant: false)),
      );
    });
  });

  test(
    'recordedOrdersProvider keeps a recorded order by source message id',
    () {
      final container = _container(FakeOrdersRepository());
      final sub = container.listen(recordedOrdersProvider, (_, __) {});
      addTearDown(sub.close);

      expect(container.read(recordedOrdersProvider), isEmpty);
      container
          .read(recordedOrdersProvider.notifier)
          .record(77, testOrder().toSummary());

      final OrderSummary? summary = container.read(recordedOrdersProvider)[77];
      expect(summary?.orderNumber, 'ORD-5');
      expect(summary?.status, OrderStatus.pending);
    },
  );

  group('OrderActions', () {
    test('changeStatus and addNote hit the repository', () async {
      final repo = FakeOrdersRepository();
      final container = _container(repo);

      final actions = container.read(orderActionsProvider);
      await actions.changeStatus(
        orderId: 5,
        status: OrderStatus.confirmed,
        note: 'ok',
      );
      await actions.addNote(orderId: 5, note: 'n', isInternal: false);

      expect(repo.statusCalls.single.status, OrderStatus.confirmed);
      expect(repo.noteCalls.single.isInternal, isFalse);
    });
  });
}
