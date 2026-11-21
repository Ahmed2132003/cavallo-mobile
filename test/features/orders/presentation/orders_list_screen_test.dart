import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:social_commerce_app/features/orders/domain/order_status.dart';
import 'package:social_commerce_app/features/orders/presentation/orders_list_screen.dart';
import 'package:social_commerce_app/features/orders/presentation/orders_providers.dart';

import '../orders_test_helpers.dart';

void main() {
  final en = l10nFor('en');
  final ar = l10nFor('ar');

  FakeOrdersRepository sample() =>
      FakeOrdersRepository()
        ..orders = [
          testOrder(id: 1, status: OrderStatus.pending),
          testOrder(id: 2, status: OrderStatus.pending),
          testOrder(id: 3, status: OrderStatus.shipped),
          testOrder(id: 4, status: OrderStatus.delivered),
        ];

  testWidgets('loading, then overview counters and one tile per order', (
    tester,
  ) async {
    final repo = sample()..listGate = Completer<void>();
    await pumpOrdersApp(tester, const OrdersListScreen(), repository: repo);

    expect(byKeyName('ordersLoading'), findsOneWidget);

    repo.listGate!.complete();
    await tester.pumpAndSettle();

    expect(byKeyName('ordersLoading'), findsNothing);
    expect(textOfKey(tester, 'ordersOverviewTotal'), '4');
    expect(textOfKey(tester, 'ordersCounterValue_pending'), '2');
    expect(textOfKey(tester, 'ordersCounterValue_shipped'), '1');
    expect(textOfKey(tester, 'ordersCounterValue_delivered'), '1');
    expect(textOfKey(tester, 'ordersCounterValue_confirmed'), '0');
    for (final id in <int>[1, 2, 3, 4]) {
      expect(byKeyName('orderTile_$id'), findsOneWidget);
    }
    expect(byKeyName('ordersTruncatedNote'), findsNothing);
  });

  testWidgets('filter chips narrow the list; All brings everything back', (
    tester,
  ) async {
    await pumpOrdersApp(tester, const OrdersListScreen(), repository: sample());
    await tester.pumpAndSettle();

    await tester.tap(byKeyName('ordersFilter_shipped'));
    await tester.pumpAndSettle();
    expect(byKeyName('orderTile_3'), findsOneWidget);
    expect(byKeyName('orderTile_1'), findsNothing);
    expect(byKeyName('orderTile_4'), findsNothing);

    await tester.tap(byKeyName('ordersFilter_all'));
    await tester.pumpAndSettle();
    expect(byKeyName('orderTile_1'), findsOneWidget);
    expect(byKeyName('orderTile_4'), findsOneWidget);
  });

  testWidgets('tapping a counter filters like its chip, and again clears it', (
    tester,
  ) async {
    await pumpOrdersApp(tester, const OrdersListScreen(), repository: sample());
    await tester.pumpAndSettle();

    await tester.tap(byKeyName('ordersCounter_pending'));
    await tester.pumpAndSettle();
    expect(byKeyName('orderTile_1'), findsOneWidget);
    expect(byKeyName('orderTile_3'), findsNothing);

    await tester.tap(byKeyName('ordersCounter_pending'));
    await tester.pumpAndSettle();
    expect(byKeyName('orderTile_3'), findsOneWidget);
  });

  testWidgets('empty list shows the empty state with its body text', (
    tester,
  ) async {
    await pumpOrdersApp(
      tester,
      const OrdersListScreen(),
      repository: FakeOrdersRepository(),
    );
    await tester.pumpAndSettle();

    expect(byKeyName('ordersEmpty'), findsOneWidget);
    expect(find.text(en.ordersEmptyTitle), findsOneWidget);
    expect(find.text(en.ordersEmptyBody), findsOneWidget);
  });

  testWidgets('a filter with no match shows the filtered-empty title', (
    tester,
  ) async {
    await pumpOrdersApp(tester, const OrdersListScreen(), repository: sample());
    await tester.pumpAndSettle();

    await tester.tap(byKeyName('ordersFilter_cancelled'));
    await tester.pumpAndSettle();

    expect(find.text(en.ordersEmptyFilteredTitle), findsOneWidget);
    expect(find.text(en.ordersEmptyBody), findsNothing);
  });

  testWidgets('error state shows the localized reason; Retry loads the data', (
    tester,
  ) async {
    final repo =
        FakeOrdersRepository()
          ..listError = const NetworkFailure(message: 'down');
    await pumpOrdersApp(tester, const OrdersListScreen(), repository: repo);
    await tester.pumpAndSettle();

    expect(byKeyName('ordersError'), findsOneWidget);
    expect(find.text(en.ordersErrorLoad), findsOneWidget);
    expect(find.text(en.ordersErrorNetwork), findsOneWidget);

    repo
      ..listError = null
      ..orders = [testOrder(id: 8)];
    await tester.tap(byKeyName('ordersRetryButton'));
    await tester.pumpAndSettle();

    expect(byKeyName('ordersError'), findsNothing);
    expect(byKeyName('orderTile_8'), findsOneWidget);
  });

  testWidgets('search is debounced and sent to the server; clear resets it', (
    tester,
  ) async {
    final repo = sample();
    await pumpOrdersApp(tester, const OrdersListScreen(), repository: repo);
    await tester.pumpAndSettle();
    expect(byKeyName('ordersSearchClear'), findsNothing);

    await tester.enterText(byKeyName('ordersSearchField'), 'ORD-42');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(repo.searches, contains('ORD-42'));
    expect(byKeyName('ordersSearchClear'), findsOneWidget);

    await tester.tap(byKeyName('ordersSearchClear'));
    await tester.pumpAndSettle();

    expect(byKeyName('ordersSearchClear'), findsNothing);
    expect(
      tester.widget<TextField>(byKeyName('ordersSearchField')).controller!.text,
      isEmpty,
    );
  });

  testWidgets('an empty search result uses the search-empty title', (
    tester,
  ) async {
    final repo = sample();
    await pumpOrdersApp(tester, const OrdersListScreen(), repository: repo);
    await tester.pumpAndSettle();

    repo.orders = <Never>[];
    await tester.enterText(byKeyName('ordersSearchField'), 'ORD-999');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text(en.ordersEmptySearchTitle), findsOneWidget);
  });

  testWidgets('pull-to-refresh reloads the list', (tester) async {
    final repo = sample();
    await pumpOrdersApp(tester, const OrdersListScreen(), repository: repo);
    await tester.pumpAndSettle();
    final before = repo.listCalls;

    await tester.drag(find.byType(ListView).first, const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(repo.listCalls, greaterThan(before));
  });

  testWidgets('hitting the page cap shows the truncated note', (tester) async {
    final repo =
        FakeOrdersRepository()
          ..pages = List.generate(
            kOrdersMaxPages + 1,
            (i) => [testOrder(id: i + 1)],
          );
    await pumpOrdersApp(tester, const OrdersListScreen(), repository: repo);
    await tester.pumpAndSettle();

    expect(repo.listCalls, kOrdersMaxPages);
    expect(byKeyName('ordersTruncatedNote'), findsOneWidget);
  });

  testWidgets('a tile shows number, product, customer, qty x price and total', (
    tester,
  ) async {
    final repo = FakeOrdersRepository()..orders = [testOrder(id: 1)];
    await pumpOrdersApp(tester, const OrdersListScreen(), repository: repo);
    await tester.pumpAndSettle();

    final tile = byKeyName('orderTile_1');
    expect(
      find.descendant(of: tile, matching: find.text('ORD-1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.text('Cotton T-Shirt')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tile,
        matching: find.text('${en.ordersCustomerLabel}: Sara'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.text('598.50 EGP')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tile,
        matching: find.text(en.ordersQuantityTimesPrice(3, '199.50 EGP')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Arabic: RTL layout and Arabic texts', (tester) async {
    await pumpOrdersApp(
      tester,
      const OrdersListScreen(),
      repository: sample(),
      locale: const Locale('ar'),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(OrdersListScreen));
    expect(Directionality.of(element), TextDirection.rtl);
    expect(find.text(ar.ordersTitle), findsOneWidget);
    expect(find.text(en.ordersTitle), findsNothing);
    expect(find.text(ar.ordersFilterAll), findsOneWidget);
  });

  testWidgets('Dark theme uses the dark tokens', (tester) async {
    await pumpOrdersApp(
      tester,
      const OrdersListScreen(),
      repository: sample(),
      dark: true,
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(OrdersListScreen));
    expect(element.appColors, AppColors.dark);
    expect(byKeyName('ordersOverview'), findsOneWidget);
  });
}
