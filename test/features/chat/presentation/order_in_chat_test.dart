import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/business_profile/presentation/own_business_id_provider.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';
import 'package:social_commerce_app/features/chat/domain/shared_content.dart';
import 'package:social_commerce_app/features/chat/presentation/message_bubble_widget.dart';
import 'package:social_commerce_app/features/orders/data/orders_repository.dart';
import 'package:social_commerce_app/features/orders/domain/order_status.dart';
import 'package:social_commerce_app/features/orders/domain/order_summary.dart';

import '../../orders/data/order_dtos_test.dart' show customerJson, eventJson;
import '../../orders/orders_test_helpers.dart';
import '../data/fake_http_client_adapter.dart';

SharedContent _shared({
  SharedContentType type = SharedContentType.product,
  bool available = true,
  int businessId = 7,
}) => SharedContent(
  type: type,
  objectId: 10,
  available: available,
  businessId: available ? businessId : null,
  businessName: available ? 'Al Anaqa' : null,
  previewText: available ? 'Cotton T-Shirt' : null,
);

Message _message({SharedContent? shared, OrderSummary? order}) => Message(
  id: 77,
  conversationId: 42,
  senderId: 1,
  text: '',
  status: MessageStatus.sent,
  createdAt: DateTime(2026, 11, 18, 12),
  sharedContent: shared ?? _shared(),
  order: order,
);

const OrderSummary _summary = OrderSummary(
  id: 5,
  orderNumber: 'ORD-5',
  status: OrderStatus.pending,
  quantity: 3,
  agreedUnitPrice: '199.50',
  totalAmount: '598.50',
  currency: 'EGP',
  productId: 10,
);

Future<void> _pump(
  WidgetTester tester,
  Message message, {
  required int? ownBusinessId,
  OrdersRepository? repository,
  Locale locale = const Locale('en'),
  bool dark = false,
}) async {
  await pumpOrdersApp(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        child: MessageBubbleWidget(
          message: message,
          isMine: true,
          customerName: 'Sara',
        ),
      ),
    ),
    repository: repository,
    locale: locale,
    dark: dark,
    overrides: [ownBusinessIdProvider.overrideWithValue(ownBusinessId)],
  );
  await tester.pumpAndSettle();
}

void main() {
  final en = l10nFor('en');

  group('Record Sale button visibility', () {
    testWidgets('shown to the merchant who owns the product', (tester) async {
      await _pump(tester, _message(), ownBusinessId: 7);
      expect(byKeyName('recordSaleButton'), findsOneWidget);
      expect(find.text(en.ordersRecordSale), findsOneWidget);
    });

    testWidgets('hidden from a customer (no own business)', (tester) async {
      await _pump(tester, _message(), ownBusinessId: null);
      expect(byKeyName('recordSaleButton'), findsNothing);
    });

    testWidgets('hidden from a merchant who does NOT own the product', (
      tester,
    ) async {
      await _pump(tester, _message(), ownBusinessId: 8);
      expect(byKeyName('recordSaleButton'), findsNothing);
    });

    testWidgets('hidden when the shared product is unavailable', (
      tester,
    ) async {
      await _pump(
        tester,
        _message(shared: _shared(available: false)),
        ownBusinessId: 7,
      );
      expect(byKeyName('recordSaleButton'), findsNothing);
    });

    testWidgets('hidden for a shared post (only products can be sold)', (
      tester,
    ) async {
      await _pump(
        tester,
        _message(shared: _shared(type: SharedContentType.post)),
        ownBusinessId: 7,
      );
      expect(byKeyName('recordSaleButton'), findsNothing);
    });

    testWidgets('hidden once the message already has an order', (tester) async {
      final repo = FakeOrdersRepository()..order = testOrder();
      await _pump(
        tester,
        _message(order: _summary),
        ownBusinessId: 7,
        repository: repo,
      );
      expect(byKeyName('recordSaleButton'), findsNothing);
      expect(byKeyName('orderCard_5'), findsOneWidget);
    });
  });

  group('OrderMessageCard', () {
    testWidgets('merchant sees summary data and the three actions', (
      tester,
    ) async {
      final repo =
          FakeOrdersRepository()
            ..order = testOrder(
              next: const [OrderStatus.confirmed],
              internalNote: 'VIP buyer',
            );
      await _pump(
        tester,
        _message(order: _summary),
        ownBusinessId: 7,
        repository: repo,
      );

      expect(find.text('ORD-5'), findsOneWidget);
      expect(textOfKey(tester, 'orderCardTotal'), '598.50 EGP');
      expect(
        find.text(en.ordersQuantityTimesPrice(3, '199.50 EGP')),
        findsOneWidget,
      );
      expect(byKeyName('orderCardUpdateStatus'), findsOneWidget);
      expect(byKeyName('orderCardAddNote'), findsOneWidget);
      expect(byKeyName('orderCardOpenDetails'), findsOneWidget);
      // The card never renders an internal note, even for the merchant.
      expect(find.text('VIP buyer'), findsNothing);
    });

    testWidgets('merchant: no allowed next status hides Update status', (
      tester,
    ) async {
      final repo =
          FakeOrdersRepository()
            ..order = testOrder(status: OrderStatus.delivered, next: const []);
      await _pump(
        tester,
        _message(order: _summary),
        ownBusinessId: 7,
        repository: repo,
      );
      expect(byKeyName('orderCardUpdateStatus'), findsNothing);
      expect(byKeyName('orderCardAddNote'), findsOneWidget);
    });

    testWidgets('customer sees status and allowed notes only, and an internal '
        'note returned by the API never appears', (tester) async {
      final adapter = FakeHttpClientAdapter();
      adapter.enqueue(
        statusCode: 200,
        data:
            customerJson()
              ..['events'] = <Map<String, dynamic>>[
                eventJson(1, 'created', to: 'pending'),
                eventJson(
                  2,
                  'status_changed',
                  from: 'pending',
                  to: 'confirmed',
                  note: 'Ready Sunday',
                ),
                eventJson(
                  3,
                  'note_added',
                  note: 'SECRET internal',
                  internal: true,
                ),
                eventJson(
                  4,
                  'note_added',
                  note: 'Visible note',
                  internal: false,
                ),
              ],
      );
      final dio =
          Dio(BaseOptions(baseUrl: 'http://test.local'))
            ..httpClientAdapter = adapter
            ..interceptors.add(ErrorInterceptor());

      await _pump(
        tester,
        _message(order: _summary),
        ownBusinessId: null,
        repository: OrdersRepository(dio),
      );

      expect(adapter.requestedOptions.single.path, '/api/v1/orders/my/5/');
      expect(textOfKey(tester, 'orderCardCustomerNote'), 'Thanks');
      expect(find.text('Ready Sunday'), findsOneWidget);
      expect(find.text('Visible note'), findsOneWidget);
      expect(find.text('SECRET internal'), findsNothing);
      expect(find.text('LEAK'), findsNothing);
      expect(byKeyName('orderCardUpdateStatus'), findsNothing);
      expect(byKeyName('orderCardAddNote'), findsNothing);
      expect(byKeyName('orderCardOpenDetails'), findsNothing);
    });

    testWidgets('renders from the summary alone when the live fetch fails', (
      tester,
    ) async {
      final repo = FakeOrdersRepository()..fetchOrderError = StateError('x');
      await _pump(
        tester,
        _message(order: _summary),
        ownBusinessId: 7,
        repository: repo,
      );
      expect(byKeyName('orderCard_5'), findsOneWidget);
      expect(textOfKey(tester, 'orderCardTotal'), '598.50 EGP');
    });

    testWidgets('Arabic + Dark: RTL card with the dark tokens', (tester) async {
      final repo = FakeOrdersRepository()..order = testOrder();
      await _pump(
        tester,
        _message(order: _summary),
        ownBusinessId: 7,
        repository: repo,
        locale: const Locale('ar'),
        dark: true,
      );
      final element = tester.element(byKeyName('orderCard_5'));
      expect(Directionality.of(element), TextDirection.rtl);
      expect(find.text('${l10nFor('ar').ordersTotalLabel}: '), findsOneWidget);
    });
  });
}
