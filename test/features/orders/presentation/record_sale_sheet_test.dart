import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';
import 'package:social_commerce_app/features/chat/domain/shared_content.dart';
import 'package:social_commerce_app/features/orders/domain/order_status.dart';
import 'package:social_commerce_app/features/orders/presentation/orders_providers.dart';
import 'package:social_commerce_app/features/orders/presentation/record_sale_sheet.dart';
import 'package:social_commerce_app/features/products/data/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_public_repository.dart';

import '../orders_test_helpers.dart';

class _FakeProductPublicRepository implements ProductPublicRepository {
  @override
  Future<Product?> fetchPublicProduct(int id) async => _product;

  @override
  Future<PaginatedResponse<Product>> fetchBusinessProducts(int businessId) {
    throw UnimplementedError('not used');
  }
}

const Product _product = Product(
  id: 10,
  businessId: 7,
  categoryId: 3,
  name: 'Cotton T-Shirt',
  description: 'Plain white cotton t-shirt.',
  price: '199.99',
  currency: Currency.egp,
);

final Message _message = Message(
  id: 77,
  conversationId: 42,
  senderId: 1,
  text: '',
  status: MessageStatus.sent,
  createdAt: DateTime(2026, 11, 18, 12),
);

const SharedContent _shared = SharedContent(
  type: SharedContentType.product,
  objectId: 10,
  available: true,
  businessId: 7,
  businessName: 'Al Anaqa',
  previewText: 'Cotton T-Shirt',
);

Future<ProviderContainer> _openSheet(
  WidgetTester tester,
  FakeOrdersRepository repo,
) async {
  final container = await pumpOrdersApp(
    tester,
    Builder(
      builder:
          (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const ValueKey<String>('openSheet'),
                onPressed:
                    () => showRecordSaleSheet(
                      context,
                      message: _message,
                      shared: _shared,
                      customerName: 'Sara',
                    ),
                child: const SizedBox(width: 40, height: 20),
              ),
            ),
          ),
    ),
    repository: repo,
    overrides: [
      productPublicRepositoryProvider.overrideWithValue(
        _FakeProductPublicRepository(),
      ),
    ],
  );
  await tester.tap(byKeyName('openSheet'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  final en = l10nFor('en');

  testWidgets('prefills the product price and currency, shows product and '
      'customer, total is automatic', (tester) async {
    await _openSheet(tester, FakeOrdersRepository());

    expect(
      tester.widget<TextField>(byKeyName('recordSalePrice')).controller!.text,
      '199.99',
    );
    expect(textOfKey(tester, 'recordSaleCurrency'), 'EGP');
    expect(find.text('Cotton T-Shirt'), findsWidgets);
    expect(find.text('${en.ordersCustomerLabel}: Sara'), findsOneWidget);
    expect(textOfKey(tester, 'recordSaleTotal'), '199.99 EGP');

    await tester.enterText(byKeyName('recordSaleQuantity'), '3');
    await tester.pump();
    expect(textOfKey(tester, 'recordSaleTotal'), '599.97 EGP');
    expect(byKeyName('recordSaleSummary'), findsOneWidget);
  });

  testWidgets('the agreed price is editable and Arabic digits are accepted', (
    tester,
  ) async {
    await _openSheet(tester, FakeOrdersRepository());

    await tester.enterText(byKeyName('recordSalePrice'), '150.5');
    await tester.enterText(byKeyName('recordSaleQuantity'), '٢');
    await tester.pump();

    expect(textOfKey(tester, 'recordSaleTotal'), '301.00 EGP');
  });

  testWidgets('invalid quantity or price blocks the request and shows the '
      'validation text', (tester) async {
    final repo = FakeOrdersRepository();
    await _openSheet(tester, repo);

    await tester.enterText(byKeyName('recordSaleQuantity'), '0');
    await tester.tap(byKeyName('recordSaleConfirmButton'));
    await tester.pump();
    expect(find.text(en.ordersValidationQuantity), findsOneWidget);
    expect(repo.createCalls, isEmpty);

    await tester.enterText(byKeyName('recordSaleQuantity'), '1');
    await tester.enterText(byKeyName('recordSalePrice'), '0');
    await tester.tap(byKeyName('recordSaleConfirmButton'));
    await tester.pump();
    expect(find.text(en.ordersValidationPrice), findsOneWidget);
    expect(repo.createCalls, isEmpty);
  });

  testWidgets('confirm sends the right body, closes the sheet, remembers the '
      'order for the chat card and shows success', (tester) async {
    final repo = FakeOrdersRepository();
    final container = await _openSheet(tester, repo);
    final sub = container.listen(recordedOrdersProvider, (_, __) {});
    addTearDown(sub.close);

    await tester.enterText(byKeyName('recordSaleQuantity'), '2');
    await tester.enterText(byKeyName('recordSaleCustomerNote'), ' Thanks ');
    await tester.enterText(byKeyName('recordSaleInternalNote'), 'VIP');
    await tester.tap(byKeyName('recordSaleConfirmButton'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, hasLength(1));
    final call = repo.createCalls.single;
    expect(call.conversationId, 42);
    expect(call.sourceMessageId, 77);
    expect(call.quantity, 2);
    expect(call.agreedUnitPrice, '199.99');
    expect(call.customerNote, 'Thanks');
    expect(call.internalNote, 'VIP');

    expect(find.byType(RecordSaleSheet), findsNothing);
    expect(find.text(en.ordersRecordedSuccess('ORD-5')), findsOneWidget);

    final recorded = container.read(recordedOrdersProvider)[77];
    expect(recorded?.orderNumber, 'ORD-5');
    expect(recorded?.status, OrderStatus.pending);
  });

  testWidgets('a double tap while sending creates ONE request and disables '
      'the button', (tester) async {
    final repo = FakeOrdersRepository()..createGate = Completer<void>();
    await _openSheet(tester, repo);

    await tester.tap(byKeyName('recordSaleConfirmButton'));
    await tester.pump();
    await tester.tap(byKeyName('recordSaleConfirmButton'), warnIfMissed: false);
    await tester.pump();

    expect(repo.createCalls, hasLength(1));
    expect(
      tester
          .widget<FilledButton>(byKeyName('recordSaleConfirmButton'))
          .onPressed,
      isNull,
    );
    expect(find.text(en.ordersSubmitting), findsOneWidget);

    repo.createGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.createCalls, hasLength(1));
  });

  testWidgets('a lost response then Try again reuses the SAME source message: '
      'no duplicate, server answers "already recorded"', (tester) async {
    final repo = FakeOrdersRepository()..createFailuresLeft = 1;
    final container = await _openSheet(tester, repo);
    final sub = container.listen(recordedOrdersProvider, (_, __) {});
    addTearDown(sub.close);

    await tester.tap(byKeyName('recordSaleConfirmButton'));
    await tester.pumpAndSettle();

    expect(byKeyName('recordSaleError'), findsOneWidget);
    expect(find.text(en.ordersErrorNetwork), findsOneWidget);
    expect(find.text(en.ordersErrorSafeRetry), findsOneWidget);
    expect(find.text(en.ordersRetryRecord), findsOneWidget);
    expect(find.byType(RecordSaleSheet), findsOneWidget);

    await tester.tap(byKeyName('recordSaleConfirmButton'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, hasLength(2));
    expect(
      repo.createCalls[1].sourceMessageId,
      repo.createCalls[0].sourceMessageId,
    );
    expect(
      repo.createCalls[1].agreedUnitPrice,
      repo.createCalls[0].agreedUnitPrice,
    );
    expect(find.byType(RecordSaleSheet), findsNothing);
    expect(find.text(en.ordersAlreadyRecorded('ORD-5')), findsOneWidget);
    expect(container.read(recordedOrdersProvider)[77]?.id, 5);
  });

  testWidgets('Arabic: RTL and Arabic title', (tester) async {
    // Re-uses the same opener with an Arabic locale.
    final repo = FakeOrdersRepository();
    await pumpOrdersApp(
      tester,
      Builder(
        builder:
            (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const ValueKey<String>('openSheet'),
                  onPressed:
                      () => showRecordSaleSheet(
                        context,
                        message: _message,
                        shared: _shared,
                      ),
                  child: const SizedBox(width: 40, height: 20),
                ),
              ),
            ),
      ),
      repository: repo,
      locale: const Locale('ar'),
      dark: true,
      overrides: [
        productPublicRepositoryProvider.overrideWithValue(
          _FakeProductPublicRepository(),
        ),
      ],
    );
    await tester.tap(byKeyName('openSheet'));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(RecordSaleSheet));
    expect(Directionality.of(element), TextDirection.rtl);
    expect(find.text(l10nFor('ar').ordersRecordSaleTitle), findsOneWidget);
  });
}
