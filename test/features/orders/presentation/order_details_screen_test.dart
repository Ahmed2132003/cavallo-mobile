import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/orders/domain/order_note.dart';
import 'package:social_commerce_app/features/orders/domain/order_status.dart';
import 'package:social_commerce_app/features/orders/domain/order_status_event.dart';
import 'package:social_commerce_app/features/orders/presentation/order_details_screen.dart';
import 'package:social_commerce_app/features/orders/presentation/order_status_chip.dart';

import '../orders_test_helpers.dart';

void main() {
  final en = l10nFor('en');

  OrderEvents events() => OrderEvents(
    timeline: [
      OrderStatusEvent(
        id: 1,
        type: OrderEventType.created,
        createdAt: DateTime.utc(2026, 11, 18, 12),
      ),
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
        note: 'Private note',
        isInternal: true,
        createdAt: DateTime.utc(2026, 11, 18, 14),
      ),
      OrderNote(
        id: 4,
        note: 'Shared note',
        isInternal: false,
        createdAt: DateTime.utc(2026, 11, 18, 15),
      ),
    ],
  );

  FakeOrdersRepository full() =>
      FakeOrdersRepository()
        ..order = testOrder(customerNote: 'Call me', internalNote: 'VIP buyer')
        ..events = events();

  testWidgets('shows the order, timeline, notes and the three actions', (
    tester,
  ) async {
    await pumpOrdersApp(
      tester,
      const OrderDetailsScreen(orderId: '5'),
      repository: full(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cotton T-Shirt'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(textOfKey(tester, 'orderDetailsTotal'), '598.50 EGP');
    expect(textOfKey(tester, 'orderCustomerNote'), 'Call me');
    expect(textOfKey(tester, 'orderInternalNote'), 'VIP buyer');
    expect(find.byType(OrderStatusChip), findsOneWidget);

    expect(find.text(en.ordersTimelineCreated), findsOneWidget);
    expect(
      find.text(
        en.ordersTimelineStatusChanged(
          orderStatusLabel(en, OrderStatus.pending),
          orderStatusLabel(en, OrderStatus.confirmed),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Ships Sunday'), findsOneWidget);

    expect(byKeyName('orderUpdateStatusButton'), findsOneWidget);
    expect(byKeyName('orderAddNoteButton'), findsOneWidget);
    expect(byKeyName('orderOpenConversationButton'), findsOneWidget);
  });

  testWidgets('only the internal note carries the Internal badge', (
    tester,
  ) async {
    await pumpOrdersApp(
      tester,
      const OrderDetailsScreen(orderId: '5'),
      repository: full(),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: byKeyName('orderNote_3'),
        matching: find.text(en.ordersInternalBadge),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKeyName('orderNote_4'),
        matching: find.text(en.ordersInternalBadge),
      ),
      findsNothing,
    );
  });

  testWidgets('no allowed next status: the Update status button is hidden', (
    tester,
  ) async {
    final repo =
        full()
          ..order = testOrder(status: OrderStatus.delivered, next: const []);
    await pumpOrdersApp(
      tester,
      const OrderDetailsScreen(orderId: '5'),
      repository: repo,
    );
    await tester.pumpAndSettle();

    expect(byKeyName('orderUpdateStatusButton'), findsNothing);
    expect(byKeyName('orderAddNoteButton'), findsOneWidget);
  });

  testWidgets('Update status opens the sheet with the server-allowed options', (
    tester,
  ) async {
    await pumpOrdersApp(
      tester,
      const OrderDetailsScreen(orderId: '5'),
      repository: full(),
    );
    await tester.pumpAndSettle();

    await tester.tap(byKeyName('orderUpdateStatusButton'));
    await tester.pumpAndSettle();

    expect(byKeyName('statusOption_confirmed'), findsOneWidget);
    expect(byKeyName('statusOption_cancelled'), findsOneWidget);
    expect(byKeyName('statusOption_delivered'), findsNothing);
  });

  testWidgets('no notes: shows the empty-notes text', (tester) async {
    final repo = full()..events = const OrderEvents();
    await pumpOrdersApp(
      tester,
      const OrderDetailsScreen(orderId: '5'),
      repository: repo,
    );
    await tester.pumpAndSettle();

    expect(byKeyName('orderNotesEmpty'), findsOneWidget);
  });

  testWidgets('loading state', (tester) async {
    final repo = full()..fetchOrderGate = Completer<void>();
    await pumpOrdersApp(
      tester,
      const OrderDetailsScreen(orderId: '5'),
      repository: repo,
    );

    expect(byKeyName('orderLoading'), findsOneWidget);

    repo.fetchOrderGate!.complete();
    await tester.pumpAndSettle();
    expect(byKeyName('orderLoading'), findsNothing);
  });

  testWidgets('error state with Retry', (tester) async {
    final repo =
        full()..fetchOrderError = const NetworkFailure(message: 'down');
    await pumpOrdersApp(
      tester,
      const OrderDetailsScreen(orderId: '5'),
      repository: repo,
    );
    await tester.pumpAndSettle();

    expect(byKeyName('orderError'), findsOneWidget);
    expect(find.text(en.ordersErrorNetwork), findsOneWidget);

    repo.fetchOrderError = null;
    await tester.tap(byKeyName('orderRetryButton'));
    await tester.pumpAndSettle();

    expect(byKeyName('orderError'), findsNothing);
    expect(byKeyName('orderDetailsTotal'), findsOneWidget);
  });

  testWidgets('a non-numeric id is not-found without any request', (
    tester,
  ) async {
    final repo = full();
    await pumpOrdersApp(
      tester,
      const OrderDetailsScreen(orderId: 'abc'),
      repository: repo,
    );
    await tester.pumpAndSettle();

    expect(byKeyName('orderNotFound'), findsOneWidget);
    expect(find.text(en.ordersNotFound), findsOneWidget);
  });

  testWidgets('Arabic renders RTL with Arabic labels', (tester) async {
    await pumpOrdersApp(
      tester,
      const OrderDetailsScreen(orderId: '5'),
      repository: full(),
      locale: const Locale('ar'),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(OrderDetailsScreen));
    expect(Directionality.of(element), TextDirection.rtl);
    expect(find.text(l10nFor('ar').ordersTimelineTitle), findsOneWidget);
  });
}
