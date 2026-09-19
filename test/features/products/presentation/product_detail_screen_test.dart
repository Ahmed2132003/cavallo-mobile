import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/products/data/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_variant_entity.dart';
import 'package:social_commerce_app/features/products/presentation/product_detail_screen.dart';
import 'package:social_commerce_app/features/products/presentation/product_price_framing.dart';

/// Hand-rolled test double for [ProductPublicRepository] — this project
/// uses no mockito/mocktail (see
/// `business_profile_public_screen_test.dart`, Part P-029, whose shape
/// this mirrors): a mutable result and error, a call counter so a test
/// can assert Retry really re-fetches, and an optional [pending]
/// completer so the loading state is observable deterministically.
///
/// [error] is thrown as-is (a bare `ApiFailure`), the shape every
/// hand-rolled fake in this project throws; the screen also handles the
/// real `DioException`-wrapped shape.
class _FakeProductPublicRepository implements ProductPublicRepository {
  _FakeProductPublicRepository({this.result, this.error, this.pending});

  Product? result;
  Object? error;
  Completer<Product?>? pending;
  int callCount = 0;

  @override
  Future<Product?> fetchPublicProduct(int id) async {
    callCount++;
    if (pending != null) {
      return pending!.future;
    }
    if (error != null) {
      throw error!;
    }
    return result;
  }

  @override
  Future<PaginatedResponse<Product>> fetchBusinessProducts(int businessId) {
    throw UnimplementedError('not used by ProductDetailScreen');
  }
}

const _product = Product(
  id: 10,
  businessId: 7,
  categoryId: 3,
  name: 'Cotton T-Shirt',
  description: 'Plain white cotton t-shirt.',
  price: '199.99',
  currency: Currency.egp,
  variants: [
    ProductVariant(id: 1, name: 'Size', value: 'Large'),
    ProductVariant(id: 2, name: 'Color', value: 'Blue'),
  ],
);

const _productNoExtras = Product(
  id: 11,
  businessId: 7,
  categoryId: 3,
  name: 'Plain Cap',
  description: '',
  price: '50.00',
  currency: Currency.sar,
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required String productId,
  required _FakeProductPublicRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productPublicRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: ProductDetailScreen(productId: productId)),
    ),
  );
}

void main() {
  group('ProductDetailScreen — non-numeric id', () {
    testWidgets('shows not-found immediately, without calling the repository', (
      tester,
    ) async {
      final repository = _FakeProductPublicRepository(result: _product);

      await _pumpScreen(
        tester,
        productId: 'sample-product-1',
        repository: repository,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Product not found.\nIt may have been removed.'),
        findsOneWidget,
      );
      expect(repository.callCount, 0);
    });
  });

  group('ProductDetailScreen — loading', () {
    testWidgets('shows a LoadingIndicator before the fetch resolves', (
      tester,
    ) async {
      final completer = Completer<Product?>();
      final repository = _FakeProductPublicRepository(pending: completer);

      await _pumpScreen(tester, productId: '10', repository: repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Resolve it and confirm the screen actually moves on — guards
      // against a false pass where loading renders only because nothing
      // else ever would.
      completer.complete(_product);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Cotton T-Shirt'), findsOneWidget);
    });
  });

  group('ProductDetailScreen — found', () {
    testWidgets('shows name, description and read-only variants', (
      tester,
    ) async {
      final repository = _FakeProductPublicRepository(result: _product);

      await _pumpScreen(tester, productId: '10', repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Cotton T-Shirt'), findsOneWidget);
      expect(find.text('Plain white cotton t-shirt.'), findsOneWidget);
      expect(find.text('Variants'), findsOneWidget);
      expect(find.text('Size: Large'), findsOneWidget);
      expect(find.text('Color: Blue'), findsOneWidget);
    });

    testWidgets('PRICE FRAMING (architecture Section 20): the required '
        'copy is present in the widget tree', (tester) async {
      final repository = _FakeProductPublicRepository(result: _product);

      await _pumpScreen(tester, productId: '10', repository: repository);
      await tester.pumpAndSettle();

      // Exact copy.
      expect(find.text('Starting from 199.99 EGP'), findsOneWidget);
      expect(find.text(ProductPriceCopy.note), findsOneWidget);
      // The key words the requirement is about, asserted independently
      // so a future copy edit cannot silently drop them.
      expect(find.textContaining('Approximate'), findsOneWidget);
      expect(find.textContaining('negotiable'), findsOneWidget);
      expect(find.textContaining('Message the business'), findsOneWidget);
    });

    testWidgets('the price never appears as a bare number — only inside '
        'the framed headline', (tester) async {
      final repository = _FakeProductPublicRepository(result: _product);

      await _pumpScreen(tester, productId: '10', repository: repository);
      await tester.pumpAndSettle();

      // Exactly one widget mentions the number, and it is the framed
      // headline.
      expect(find.textContaining('199.99'), findsOneWidget);
      expect(find.text('199.99'), findsNothing);
      expect(find.text('199.99 EGP'), findsNothing);
    });

    testWidgets('the currency code follows the product (SAR here)', (
      tester,
    ) async {
      final repository = _FakeProductPublicRepository(result: _productNoExtras);

      await _pumpScreen(tester, productId: '11', repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Starting from 50.00 SAR'), findsOneWidget);
      expect(find.text(ProductPriceCopy.note), findsOneWidget);
    });

    testWidgets('a product with no variants hides the Variants heading, and '
        'an empty description shows the placeholder', (tester) async {
      final repository = _FakeProductPublicRepository(result: _productNoExtras);

      await _pumpScreen(tester, productId: '11', repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Variants'), findsNothing);
      expect(
        find.text('This business hasn\'t added a description yet.'),
        findsOneWidget,
      );
    });

    testWidgets('"Message Business" is visibly present but DISABLED, with a '
        '"(coming soon)" note', (tester) async {
      final repository = _FakeProductPublicRepository(result: _product);

      await _pumpScreen(tester, productId: '10', repository: repository);
      await tester.pumpAndSettle();

      final button = find.widgetWithText(AppButton, 'Message Business');
      expect(button, findsOneWidget);
      expect(tester.widget<AppButton>(button).onPressed, isNull);
      expect(find.text('(coming soon)'), findsOneWidget);
    });

    testWidgets('NO transactional UI: no cart/buy/quantity pattern anywhere '
        'on the screen', (tester) async {
      final repository = _FakeProductPublicRepository(result: _product);

      await _pumpScreen(tester, productId: '10', repository: repository);
      await tester.pumpAndSettle();

      // No cart-style icons.
      expect(find.byIcon(Icons.shopping_cart), findsNothing);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsNothing);
      expect(find.byIcon(Icons.add_shopping_cart), findsNothing);
      expect(find.byIcon(Icons.shopping_bag), findsNothing);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
      expect(find.byIcon(Icons.shopping_basket), findsNothing);

      // No purchase-flow wording anywhere.
      expect(
        find.textContaining(
          RegExp(
            r'buy now|add to cart|checkout|quantity|purchase|pay now',
            caseSensitive: false,
          ),
        ),
        findsNothing,
      );

      // No quantity selector / input controls.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(DropdownButton<int>), findsNothing);
      expect(find.byType(IconButton), findsNothing);

      // The ONLY button on the screen is the disabled "Message
      // Business" stub.
      //
      // NOTE: `find.bySubtype`, NOT `find.byType`. `byType` matches the
      // exact runtime type only, and the real widget is a `FilledButton`
      // (inside `AppButton`) — `byType(ButtonStyleButton)` matches
      // nothing even when a button is present, which would make the
      // "no buttons" style assertions vacuous.
      expect(find.bySubtype<ButtonStyleButton>(), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(find.bySubtype<ButtonStyleButton>())
            .onPressed,
        isNull,
      );
    });
  });

  group('ProductDetailScreen — not found (404 or inactive)', () {
    testWidgets('a null result shows not-found with NO Retry button', (
      tester,
    ) async {
      final repository = _FakeProductPublicRepository(result: null);

      await _pumpScreen(tester, productId: '999999', repository: repository);
      await tester.pumpAndSettle();

      expect(
        find.text('Product not found.\nIt may have been removed.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Retry'), findsNothing);
      expect(repository.callCount, 1);
    });
  });

  group('ProductDetailScreen — error', () {
    testWidgets('a genuine failure shows the backend message and a Retry '
        'button, not the not-found copy', (tester) async {
      final repository = _FakeProductPublicRepository(
        error: const ServerFailure(message: 'Something broke.'),
      );

      await _pumpScreen(tester, productId: '10', repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Something broke.'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Retry'), findsOneWidget);
      expect(
        find.text('Product not found.\nIt may have been removed.'),
        findsNothing,
      );
    });

    testWidgets('tapping Retry re-invokes the repository', (tester) async {
      final repository = _FakeProductPublicRepository(
        error: const ServerFailure(message: 'Something broke.'),
      );

      await _pumpScreen(tester, productId: '10', repository: repository);
      await tester.pumpAndSettle();

      expect(repository.callCount, 1);

      // Fix the "backend" before retrying, mirroring a transient
      // failure that clears up.
      repository.error = null;
      repository.result = _product;

      await tester.tap(find.widgetWithText(AppButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
      expect(find.text('Cotton T-Shirt'), findsOneWidget);
    });
  });
}
