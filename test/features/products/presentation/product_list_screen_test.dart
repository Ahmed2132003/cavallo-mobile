import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/products/data/product_repository_impl.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_variant_entity.dart';
import 'package:social_commerce_app/features/products/presentation/product_list_screen.dart';

/// Hand-rolled test double for [ProductRepository] — this project
/// doesn't use mockito/mocktail anywhere (confirmed against
/// `own_products_provider_test.dart`'s own note). Scoped to exactly
/// what `ProductListScreen` exercises through `ownProductsProvider`:
/// [fetchOwnProducts] (list + error + pending-for-loading-state) and
/// [deleteProduct] (with a call counter so the confirm-dialog flow can
/// be asserted). [createProduct]/[updateProduct] are never called by
/// this screen — implemented only to satisfy the interface, and throw
/// if ever hit, so an accidental future call site here wouldn't fail
/// silently.
class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({List<Product> fetchResults = const []})
    : currentProducts = List.of(fetchResults);

  List<Product> currentProducts;
  Object? currentFetchError;
  Completer<PaginatedResponse<Product>>? pendingFetch;

  int deleteProductCallCount = 0;
  int? lastDeletedProductId;

  @override
  Future<PaginatedResponse<Product>> fetchOwnProducts() async {
    if (pendingFetch != null) {
      return pendingFetch!.future;
    }
    if (currentFetchError != null) {
      throw currentFetchError!;
    }
    return PaginatedResponse<Product>(
      results: List.of(currentProducts),
      next: null,
      previous: null,
    );
  }

  @override
  Future<void> deleteProduct(int productId) async {
    deleteProductCallCount++;
    lastDeletedProductId = productId;
    currentProducts = currentProducts
        .where((p) => p.id != productId)
        .toList();
  }

  @override
  Future<Product> createProduct({
    required int categoryId,
    required String name,
    required String description,
    required String price,
    required Currency currency,
    dynamic imageFile,
    bool isActive = true,
  }) => throw UnimplementedError('Not used by ProductListScreen');

  @override
  Future<Product> updateProduct({
    required int productId,
    int? categoryId,
    String? name,
    String? description,
    String? price,
    Currency? currency,
    dynamic imageFile,
    bool? isActive,
  }) => throw UnimplementedError('Not used by ProductListScreen');
}

const _productA = Product(
  id: 1,
  businessId: 1,
  categoryId: 3,
  name: 'Cotton T-Shirt',
  description: 'Plain white cotton t-shirt',
  price: '199.99',
  currency: Currency.egp,
);

const _productB = Product(
  id: 2,
  businessId: 1,
  categoryId: 4,
  name: 'Leather Belt',
  description: 'Brown leather belt',
  price: '89.99',
  currency: Currency.egp,
  variants: [ProductVariant(id: 5, name: 'Size', value: 'M')],
);

/// Pumps [ProductListScreen] with [productRepositoryProvider] overridden
/// to [repository]. Deliberately a plain [MaterialApp] — NOT
/// `MaterialApp.router`/`GoRouter` — per `product_list_screen.dart`'s
/// own docstring: navigation is injected via [onCreateNew]/
/// [onEditProduct], so no router is needed to test this screen at all.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeProductRepository repository,
  VoidCallback? onCreateNew,
  void Function(Product product)? onEditProduct,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [productRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: ProductListScreen(
          onCreateNew: onCreateNew ?? () {},
          onEditProduct: onEditProduct ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('ProductListScreen — loading', () {
    testWidgets('shows a LoadingIndicator before the fetch resolves', (
      tester,
    ) async {
      final completer = Completer<PaginatedResponse<Product>>();
      final repository = _FakeProductRepository()..pendingFetch = completer;

      await _pumpScreen(tester, repository: repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        const PaginatedResponse<Product>(
          results: [_productA],
          next: null,
          previous: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Cotton T-Shirt'), findsOneWidget);
    });
  });

  group('ProductListScreen — empty', () {
    testWidgets('a business with no products yet shows the empty state', (
      tester,
    ) async {
      final repository = _FakeProductRepository(fetchResults: const []);

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No products yet.\nTap "Create New" to add your first product.',
        ),
        findsOneWidget,
      );
    });
  });

  group('ProductListScreen — populated', () {
    testWidgets('shows each product\'s name, price and currency', (
      tester,
    ) async {
      final repository = _FakeProductRepository(
        fetchResults: const [_productA, _productB],
      );

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Cotton T-Shirt'), findsOneWidget);
      expect(find.text('199.99 EGP'), findsOneWidget);
      expect(find.text('Leather Belt'), findsOneWidget);
      expect(find.text('89.99 EGP'), findsOneWidget);
      expect(find.text('1 variant'), findsOneWidget);
    });

    testWidgets('tapping "Create New" invokes onCreateNew', (tester) async {
      var createNewTapped = false;
      final repository = _FakeProductRepository(
        fetchResults: const [_productA],
      );

      await _pumpScreen(
        tester,
        repository: repository,
        onCreateNew: () => createNewTapped = true,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(createNewTapped, isTrue);
    });

    testWidgets('tapping a product\'s Edit action invokes onEditProduct '
        'with that exact product', (tester) async {
      Product? editedProduct;
      final repository = _FakeProductRepository(
        fetchResults: const [_productA, _productB],
      );

      await _pumpScreen(
        tester,
        repository: repository,
        onEditProduct: (product) => editedProduct = product,
      );
      await tester.pumpAndSettle();

      // _productB is the second item — its Edit icon is index 1.
      await tester.tap(find.byIcon(Icons.edit_outlined).at(1));
      await tester.pumpAndSettle();

      expect(editedProduct, _productB);
    });
  });

  group('ProductListScreen — delete', () {
    testWidgets('tapping Delete shows a confirmation dialog; Cancel leaves '
        'the product untouched', (tester) async {
      final repository = _FakeProductRepository(
        fetchResults: const [_productA],
      );

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete product?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repository.deleteProductCallCount, 0);
      expect(find.text('Cotton T-Shirt'), findsOneWidget);
    });

    testWidgets('confirming Delete removes the product from the list', (
      tester,
    ) async {
      final repository = _FakeProductRepository(
        fetchResults: const [_productA, _productB],
      );

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      // Delete _productA (first item, index 0).
      await tester.tap(find.byIcon(Icons.delete_outline).at(0));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.deleteProductCallCount, 1);
      expect(repository.lastDeletedProductId, _productA.id);
      expect(find.text('Cotton T-Shirt'), findsNothing);
      expect(find.text('Leather Belt'), findsOneWidget);
    });
  });

  group('ProductListScreen — error', () {
    testWidgets('a genuine failure shows the backend message and a Retry '
        'button', (tester) async {
      final repository = _FakeProductRepository()
        ..currentFetchError = const ServerFailure(message: 'Something broke.');

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Something broke.'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Retry'), findsOneWidget);
    });

    testWidgets('tapping Retry re-fetches and shows the recovered list', (
      tester,
    ) async {
      final repository = _FakeProductRepository()
        ..currentFetchError = const ServerFailure(message: 'Something broke.');

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      repository.currentFetchError = null;
      repository.currentProducts = [_productA];

      await tester.tap(find.widgetWithText(AppButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Cotton T-Shirt'), findsOneWidget);
    });
  });
}