import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/orders/data/orders_repository.dart';
import 'package:social_commerce_app/features/orders/domain/order.dart';
import 'package:social_commerce_app/features/orders/domain/order_note.dart';
import 'package:social_commerce_app/features/orders/domain/order_status.dart';
import 'package:social_commerce_app/features/orders/domain/order_status_event.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part BI-03 test helpers: fixtures, a scriptable [OrdersRepository] fake
/// and one app wrapper (theme, locale, localizations, providers).

AppLocalizations l10nFor(String languageCode) =>
    lookupAppLocalizations(Locale(languageCode));

Order testOrder({
  int id = 5,
  OrderStatus status = OrderStatus.pending,
  List<OrderStatus> next = const <OrderStatus>[
    OrderStatus.confirmed,
    OrderStatus.cancelled,
  ],
  String customerNote = '',
  String? internalNote,
  String? customerName = 'Sara',
}) {
  return Order(
    id: id,
    orderNumber: 'ORD-$id',
    conversationId: 42,
    productId: 10,
    productName: 'Cotton T-Shirt',
    quantity: 3,
    agreedUnitPrice: '199.50',
    totalAmount: '598.50',
    currency: 'EGP',
    status: status,
    createdAt: DateTime.utc(2026, 11, 18, 12, 5),
    updatedAt: DateTime.utc(2026, 11, 18, 12, 5),
    customerId: 9,
    customerName: customerName,
    sourceMessageId: 77,
    allowedNextStatuses: next,
    customerNote: customerNote,
    internalNote: internalNote,
  );
}

class CreateCall {
  const CreateCall({
    required this.conversationId,
    required this.sourceMessageId,
    required this.quantity,
    required this.agreedUnitPrice,
    required this.customerNote,
    required this.internalNote,
  });

  final int conversationId;
  final int sourceMessageId;
  final int quantity;
  final String agreedUnitPrice;
  final String customerNote;
  final String internalNote;
}

class StatusCall {
  const StatusCall(this.orderId, this.status, this.note);

  final int orderId;
  final OrderStatus status;
  final String note;
}

class NoteCall {
  const NoteCall(this.orderId, this.note, this.isInternal);

  final int orderId;
  final String note;
  final bool isInternal;
}

class FakeOrdersRepository extends OrdersRepository {
  FakeOrdersRepository() : super(Dio());

  // --- list ---
  List<Order> orders = <Order>[];

  /// When set, the list is served page by page (cursor `cursor:<index>`).
  List<List<Order>>? pages;
  Object? listError;
  Completer<void>? listGate;
  int listCalls = 0;
  final List<String?> searches = <String?>[];

  // --- details ---
  Order order = testOrder();
  Object? fetchOrderError;
  Completer<void>? fetchOrderGate;
  OrderEvents events = const OrderEvents();
  CustomerOrderDetail? myOrder;

  // --- create (simulates the backend: one order per source message) ---
  final List<CreateCall> createCalls = <CreateCall>[];

  /// The next N calls fail AFTER the server already stored the order (the
  /// "lost response" case). The retry then gets the 200 / created = false.
  int createFailuresLeft = 0;
  Completer<void>? createGate;
  Order createdOrder = testOrder();
  bool _serverHasOrder = false;

  // --- merchant writes ---
  Object? statusError;
  final List<StatusCall> statusCalls = <StatusCall>[];
  Object? noteError;
  final List<NoteCall> noteCalls = <NoteCall>[];

  @override
  Future<CreatedOrderResult> createFromChat({
    required int conversationId,
    required int sourceMessageId,
    required int quantity,
    required String agreedUnitPrice,
    String customerNote = '',
    String internalNote = '',
  }) async {
    createCalls.add(
      CreateCall(
        conversationId: conversationId,
        sourceMessageId: sourceMessageId,
        quantity: quantity,
        agreedUnitPrice: agreedUnitPrice,
        customerNote: customerNote,
        internalNote: internalNote,
      ),
    );
    if (createGate != null) {
      await createGate!.future;
    }
    if (createFailuresLeft > 0) {
      createFailuresLeft--;
      _serverHasOrder = true;
      throw const NetworkFailure(message: 'down');
    }
    final bool created = !_serverHasOrder;
    _serverHasOrder = true;
    return CreatedOrderResult(order: createdOrder, created: created);
  }

  @override
  Future<PaginatedResponse<Order>> listOrders({
    OrderStatus? status,
    String? search,
    String? cursor,
  }) async {
    listCalls++;
    searches.add(search);
    if (listGate != null) {
      await listGate!.future;
    }
    if (listError != null) {
      throw listError!;
    }
    final List<List<Order>> all = pages ?? <List<Order>>[orders];
    final int index = cursor == null ? 0 : int.parse(cursor.split(':').last);
    return PaginatedResponse<Order>(
      results: all[index],
      next: index + 1 < all.length ? 'cursor:${index + 1}' : null,
      previous: null,
    );
  }

  @override
  Future<Order> fetchOrder(int id) async {
    if (fetchOrderGate != null) {
      await fetchOrderGate!.future;
    }
    if (fetchOrderError != null) {
      throw fetchOrderError!;
    }
    return order;
  }

  @override
  Future<OrderEvents> fetchOrderEvents(int id) async => events;

  @override
  Future<CustomerOrderDetail> fetchMyOrder(int id) async {
    return myOrder ?? CustomerOrderDetail(order: order, events: events);
  }

  @override
  Future<Order> changeStatus({
    required int orderId,
    required OrderStatus status,
    String note = '',
  }) async {
    statusCalls.add(StatusCall(orderId, status, note));
    if (statusError != null) {
      throw statusError!;
    }
    return order;
  }

  @override
  Future<OrderNote> addNote({
    required int orderId,
    required String note,
    required bool isInternal,
  }) async {
    noteCalls.add(NoteCall(orderId, note, isInternal));
    if (noteError != null) {
      throw noteError!;
    }
    return OrderNote(
      id: 99,
      note: note,
      isInternal: isInternal,
      createdAt: DateTime.utc(2026, 11, 18, 13),
    );
  }
}

/// The app wrapper without any provider scope (for plain widgets).
Widget orderTestApp(
  Widget home, {
  Locale locale = const Locale('en'),
  bool dark = false,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

/// Pumps [home] once (no settle: a loading spinner never settles) inside a
/// tall surface, with [repository] behind `ordersRepositoryProvider`.
Future<ProviderContainer> pumpOrdersApp(
  WidgetTester tester,
  Widget home, {
  OrdersRepository? repository,
  Locale locale = const Locale('en'),
  bool dark = false,
  List<dynamic> overrides = const <dynamic>[],
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final ProviderContainer container = ProviderContainer(
    overrides: [
      ordersRepositoryProvider.overrideWithValue(
        repository ?? FakeOrdersRepository(),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: orderTestApp(home, locale: locale, dark: dark),
    ),
  );
  await tester.pump();
  return container;
}

String textOfKey(WidgetTester tester, String key) {
  return tester.widget<Text>(find.byKey(ValueKey<String>(key))).data!;
}

Finder byKeyName(String key) => find.byKey(ValueKey<String>(key));
