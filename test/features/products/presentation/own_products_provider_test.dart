import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/products/data/product_repository_impl.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_repository.dart';
import 'package:social_commerce_app/features/products/presentation/own_products_provider.dart';

/// Hand-rolled test double for [ProductRepository] — this project
/// doesn't use mockito/mocktail anywhere (confirmed against
/// `business_profile_provider_test.dart`'s own note before writing this
/// file); every prior provider test either hits a real Dio adapter or
/// hand-rolls a fake, mirroring `FakeBusinessProfileRepository` exactly.
class FakeProductRepository implements ProductRepository {
  FakeProductRepository({
    List<Product> fetchResults = const [],
    Object? fetchError,
    this.createProductBehavior,
    this.updateProductBehavior,
    this.deleteProductBehavior,
  }) : currentProducts = List.of(fetchResults),
       currentFetchError = fetchError;

  /// The fake "backend" list. Mutable (not constructor-only `final`),
  /// same reasoning as `FakeBusinessProfileRepository.currentFetchResult`
  /// (Part P-028B): [refreshProducts]'s whole contract is "re-run the
  /// same GET and see whatever it now returns," which isn't exercisable
  /// from a fake whose fetch result is frozen at construction time.
  List<Product> currentProducts;

  /// When non-null, [fetchOwnProducts] throws this instead of resolving.
  Object? currentFetchError;

  /// Invoked by [createProduct]. Return the [Product] to "create," or
  /// `throw` to simulate a backend rejection. `null` (the default)
  /// returns a fixed successful [Product] and appends it to
  /// [currentProducts] — mirroring a real POST's persisted effect.
  final Future<Product> Function()? createProductBehavior;

  /// Same shape as [createProductBehavior], for [updateProduct]. `null`
  /// (the default) applies the patch on top of the matching product in
  /// [currentProducts] (via [Product.copyWith]) and persists it there.
  final Future<Product> Function()? updateProductBehavior;

  /// Same shape, for [deleteProduct]. `null` (the default) removes the
  /// matching product from [currentProducts].
  final Future<void> Function()? deleteProductBehavior;

  int fetchOwnProductsCallCount = 0;
  int createProductCallCount = 0;
  int updateProductCallCount = 0;
  int deleteProductCallCount = 0;
  int? lastDeletedProductId;

  static const _defaultCreatedProduct = Product(
    id: 100,
    businessId: 1,
    categoryId: 3,
    name: 'New Product',
    description: 'A new product',
    price: '50.00',
    currency: Currency.egp,
  );

  @override
  Future<PaginatedResponse<Product>> fetchOwnProducts() async {
    fetchOwnProductsCallCount++;
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
  Future<Product> createProduct({
    required int categoryId,
    required String name,
    required String description,
    required String price,
    required Currency currency,
    File? imageFile,
    bool isActive = true,
  }) async {
    createProductCallCount++;
    final created = createProductBehavior != null
        ? await createProductBehavior!()
        : _defaultCreatedProduct;
    currentProducts = [...currentProducts, created];
    return created;
  }

  @override
  Future<Product> updateProduct({
    required int productId,
    int? categoryId,
    String? name,
    String? description,
    String? price,
    Currency? currency,
    File? imageFile,
    bool? isActive,
  }) async {
    updateProductCallCount++;
    if (updateProductBehavior != null) {
      return updateProductBehavior!();
    }
    final existing = currentProducts.firstWhere((p) => p.id == productId);
    final updated = existing.copyWith(
      categoryId: categoryId,
      name: name,
      description: description,
      price: price,
      currency: currency,
      isActive: isActive,
    );
    currentProducts = [
      for (final p in currentProducts) if (p.id == productId) updated else p,
    ];
    return updated;
  }

  @override
  Future<void> deleteProduct(int productId) async {
    deleteProductCallCount++;
    lastDeletedProductId = productId;
    if (deleteProductBehavior != null) {
      await deleteProductBehavior!();
      return;
    }
    currentProducts = currentProducts
        .where((p) => p.id != productId)
        .toList();
  }
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
);

void main() {
  group('OwnProductsNotifier.build', () {
    test('resolves to the fetched product list', () async {
      final container = ProviderContainer(
        overrides: [
          productRepositoryProvider.overrideWithValue(
            FakeProductRepository(fetchResults: [_productA, _productB]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(ownProductsProvider.future);

      expect(result, [_productA, _productB]);
      // Compared via `.value`, not by comparing two `AsyncData`
      // instances directly with `==`: `AsyncData.==` delegates to
      // `List.==`, which Dart's `List` never overrides for content —
      // two structurally-identical-but-different-instance lists are
      // never `==` to each other that way. `expect(actual, matcher)`
      // wraps a bare `List` argument in `equals()` automatically, which
      // *does* do an element-by-element comparison for Iterables — the
      // same reason `expect(result, [...])` right above this already
      // passes.
      final state = container.read(ownProductsProvider);
      expect(state.hasValue, isTrue);
      expect(state.value, [_productA, _productB]);
    });

    test(
      'resolves to AsyncData([]) — not AsyncError — for a business with '
      'no products yet',
      () async {
        final container = ProviderContainer(
          overrides: [
            productRepositoryProvider.overrideWithValue(
              FakeProductRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(ownProductsProvider.future);

        expect(result, isEmpty);
        final state = container.read(ownProductsProvider);
        expect(state.hasError, isFalse);
      },
    );

    test('a genuine repository failure becomes AsyncError', () async {
      final container = ProviderContainer(
        overrides: [
          productRepositoryProvider.overrideWithValue(
            FakeProductRepository(fetchError: Exception('network down')),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(
        ownProductsProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(ownProductsProvider);
      expect(state.hasError, isTrue);
      expect(state.hasValue, isFalse);
    });
  });

  group('OwnProductsNotifier.createProduct', () {
    test(
      'on success, forwards to the repository and refreshes state to '
      'include the created product',
      () async {
        final fakeRepo = FakeProductRepository(fetchResults: [_productA]);
        final container = ProviderContainer(
          overrides: [productRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);
        await container.read(ownProductsProvider.future);

        final created = await container
            .read(ownProductsProvider.notifier)
            .createProduct(
              categoryId: 3,
              name: 'New Product',
              description: 'A new product',
              price: '50.00',
              currency: Currency.egp,
            );

        expect(fakeRepo.createProductCallCount, 1);
        expect(created.id, 100);

        final state = container.read(ownProductsProvider);
        expect(state.value, [_productA, created]);
      },
    );

    test(
      'on failure, rethrows to the caller and leaves state untouched',
      () async {
        final failure = Exception('validation failed');
        final fakeRepo = FakeProductRepository(
          fetchResults: [_productA],
          createProductBehavior: () async => throw failure,
        );
        final container = ProviderContainer(
          overrides: [productRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);
        await container.read(ownProductsProvider.future);

        await expectLater(
          container
              .read(ownProductsProvider.notifier)
              .createProduct(
                categoryId: 3,
                name: 'New Product',
                description: 'A new product',
                price: '50.00',
                currency: Currency.egp,
              ),
          throwsA(failure),
        );

        // The list must still show exactly what it did before the
        // failed attempt — a failed create must never wipe or corrupt
        // the existing list.
        final state = container.read(ownProductsProvider);
        expect(state.value, [_productA]);
      },
    );
  });

  group('OwnProductsNotifier.updateProduct', () {
    test(
      'on success, forwards to the repository and refreshes state with '
      "the backend's own updated product",
      () async {
        final fakeRepo = FakeProductRepository(fetchResults: [_productA]);
        final container = ProviderContainer(
          overrides: [productRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);
        await container.read(ownProductsProvider.future);

        final updated = await container
            .read(ownProductsProvider.notifier)
            .updateProduct(productId: _productA.id, name: 'Updated Name');

        expect(fakeRepo.updateProductCallCount, 1);
        expect(updated.name, 'Updated Name');

        final state = container.read(ownProductsProvider);
        expect(state.value!.single.name, 'Updated Name');
      },
    );
  });

  group('OwnProductsNotifier.deleteProduct', () {
    test(
      'on success, forwards the id to the repository and removes the '
      'product from state',
      () async {
        final fakeRepo = FakeProductRepository(
          fetchResults: [_productA, _productB],
        );
        final container = ProviderContainer(
          overrides: [productRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);
        await container.read(ownProductsProvider.future);

        await container
            .read(ownProductsProvider.notifier)
            .deleteProduct(_productA.id);

        expect(fakeRepo.deleteProductCallCount, 1);
        expect(fakeRepo.lastDeletedProductId, _productA.id);

        final state = container.read(ownProductsProvider);
        expect(state.value, [_productB]);
      },
    );

    test(
      'on failure, rethrows to the caller and leaves state untouched',
      () async {
        final failure = Exception('cross-business delete rejected');
        final fakeRepo = FakeProductRepository(
          fetchResults: [_productA],
          deleteProductBehavior: () async => throw failure,
        );
        final container = ProviderContainer(
          overrides: [productRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);
        await container.read(ownProductsProvider.future);

        await expectLater(
          container.read(ownProductsProvider.notifier).deleteProduct(999),
          throwsA(failure),
        );

        final state = container.read(ownProductsProvider);
        expect(state.value, [_productA]);
      },
    );
  });

  group('OwnProductsNotifier.refreshProducts', () {
    test('a failed refresh becomes AsyncError without throwing', () async {
      final fakeRepo = FakeProductRepository(fetchResults: [_productA]);
      final container = ProviderContainer(
        overrides: [productRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);
      await container.read(ownProductsProvider.future);

      fakeRepo.currentFetchError = Exception('network down');

      // Deliberately not awaited via expectLater/throwsA — this method
      // must NOT throw at all, unlike createProduct/updateProduct/
      // deleteProduct above.
      await container.read(ownProductsProvider.notifier).refreshProducts();

      final state = container.read(ownProductsProvider);
      expect(state.hasError, isTrue);
    });
  });
}