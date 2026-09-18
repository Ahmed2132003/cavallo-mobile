import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/categories/data/category_repository_impl.dart';
import 'package:social_commerce_app/features/categories/domain/category_entity.dart';
import 'package:social_commerce_app/features/categories/domain/category_repository.dart';
import 'package:social_commerce_app/features/products/data/product_repository_impl.dart';
import 'package:social_commerce_app/features/products/data/product_variant_repository_impl.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_variant_entity.dart';
import 'package:social_commerce_app/features/products/presentation/product_form_screen.dart';

/// Hand-rolled test double for [CategoryRepository] — this project
/// doesn't use mockito/mocktail anywhere.
class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository({this.tree = const []});

  final List<CategoryNode> tree;

  @override
  Future<List<CategoryNode>> fetchCategoryTree({
    bool forceRefresh = false,
  }) async => tree;
}

/// Hand-rolled test double for [ProductRepository], scoped to exactly
/// what `ProductFormScreen` calls through `ownProductsProvider`:
/// [createProduct]/[updateProduct] (with their arguments captured for
/// assertions) and [fetchOwnProducts] (only ever called for the
/// post-save `refreshProducts()` — never actually awaited by anything
/// this test asserts on, so `throw UnimplementedError()` is enough:
/// no test here reads `ownProductsProvider`'s own list state).
class _FakeProductRepository implements ProductRepository {
  int createProductCallCount = 0;
  int updateProductCallCount = 0;
  Map<String, dynamic>? lastCreateArgs;
  Object? createProductError;

  @override
  Future<PaginatedResponse<Product>> fetchOwnProducts() async =>
      throw UnimplementedError('Not exercised by product_form_screen_test.dart');

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
    lastCreateArgs = {
      'categoryId': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'isActive': isActive,
    };
    if (createProductError != null) {
      throw createProductError!;
    }
    return Product(
      id: 42,
      businessId: 1,
      categoryId: categoryId,
      name: name,
      description: description,
      price: price,
      currency: currency,
      isActive: isActive,
    );
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
    return Product(
      id: productId,
      businessId: 1,
      categoryId: categoryId ?? 1,
      name: name ?? '',
      description: description ?? '',
      price: price ?? '0',
      currency: currency ?? Currency.egp,
      isActive: isActive ?? true,
    );
  }

  @override
  Future<void> deleteProduct(int productId) async {}
}

/// Hand-rolled test double for [ProductVariantRepository] — records
/// every create call so a test can assert variants were actually sent.
class _FakeProductVariantRepository implements ProductVariantRepository {
  int createVariantCallCount = 0;
  final List<({int productId, String name, String value})> createdVariants =
      [];

  @override
  Future<ProductVariant> createVariant({
    required int productId,
    required String name,
    required String value,
  }) async {
    createVariantCallCount++;
    createdVariants.add((productId: productId, name: name, value: value));
    return ProductVariant(
      id: 900 + createVariantCallCount,
      name: name,
      value: value,
    );
  }

  @override
  Future<ProductVariant> updateVariant({
    required int productId,
    required int variantId,
    String? name,
    String? value,
  }) async =>
      ProductVariant(id: variantId, name: name ?? '', value: value ?? '');

  @override
  Future<void> deleteVariant({
    required int productId,
    required int variantId,
  }) async {}
}

const _categories = [
  CategoryNode(
    id: 1,
    name: 'Fashion',
    slug: 'fashion',
    children: [CategoryNode(id: 2, name: 'Men', slug: 'men')],
  ),
];

/// Enlarges the test surface well beyond this form's real height (name,
/// description×4 lines, price, currency, category, active switch, image
/// picker, variants, submit — confirmed too tall for the default 800×600
/// on the real machine: `ensureVisible` left the submit button's tap
/// point at Offset y=696, still outside the 600-tall root render view,
/// so the tap silently missed). This is the same class of test-harness
/// fix `business_onboarding_screen_test.dart` already documents for its
/// own tall form — there, `ensureVisible` alone was enough because that
/// form is shorter; here it isn't, so the surface itself is resized
/// instead, which sidesteps the scroll-precision issue entirely rather
/// than fighting it.
void _growTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeProductRepository productRepository,
  _FakeProductVariantRepository? variantRepository,
  List<CategoryNode> categories = _categories,
  Product? existingProduct,
}) async {
  _growTestSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(productRepository),
        productVariantRepositoryProvider.overrideWithValue(
          variantRepository ?? _FakeProductVariantRepository(),
        ),
        categoryRepositoryProvider.overrideWith(
          (ref) async => _FakeCategoryRepository(tree: categories),
        ),
      ],
      child: MaterialApp(
        home: ProductFormScreen(existingProduct: existingProduct),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final finder = find.byKey(const Key('productForm_submitButton'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('ProductFormScreen — validation', () {
    testWidgets(
      'submitting an empty form shows every required-field error',
      (tester) async {
        await _pumpScreen(tester, productRepository: _FakeProductRepository());

        await _tapSubmit(tester);

        expect(find.text('Name is required.'), findsOneWidget);
        expect(find.text('Description is required.'), findsOneWidget);
        expect(find.text('Price is required.'), findsOneWidget);
        expect(find.text('Currency is required.'), findsOneWidget);
        expect(find.text('Category is required.'), findsOneWidget);
      },
    );

    testWidgets('an invalid price shows a validation error', (tester) async {
      await _pumpScreen(tester, productRepository: _FakeProductRepository());

      await tester.enterText(
        find.byKey(const Key('productForm_priceField')),
        'not-a-number',
      );
      await _tapSubmit(tester);

      expect(find.text('Enter a valid price (e.g. 199.99).'), findsOneWidget);
    });
  });

  group('ProductFormScreen — currency choices', () {
    testWidgets(
      "the currency dropdown offers exactly the backend's 4 choices",
      (tester) async {
        await _pumpScreen(tester, productRepository: _FakeProductRepository());

        await tester.tap(find.byKey(const Key('productForm_currencyDropdown')));
        await tester.pumpAndSettle();

        expect(find.text('EGP'), findsOneWidget);
        expect(find.text('SAR'), findsOneWidget);
        expect(find.text('AED'), findsOneWidget);
        expect(find.text('JOD'), findsOneWidget);
      },
    );
  });

  group('ProductFormScreen — create', () {
    testWidgets(
      'a valid submission calls createProduct with the entered fields, '
      'syncs the added variant, and pops with true',
      (tester) async {
        _growTestSurface(tester);
        final productRepository = _FakeProductRepository();
        final variantRepository = _FakeProductVariantRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              productRepositoryProvider.overrideWithValue(productRepository),
              productVariantRepositoryProvider.overrideWithValue(
                variantRepository,
              ),
              categoryRepositoryProvider.overrideWith(
                (ref) async => _FakeCategoryRepository(tree: _categories),
              ),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const ProductFormScreen(),
                        ),
                      );
                      // Surfacing the pop result as text lets the test
                      // assert on it without needing a GoRouter harness
                      // (this screen deliberately has no `RouteNames`
                      // dependency — see its own class docstring).
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('POPPED_WITH:$result')),
                      );
                    },
                    child: const Text('Open form'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open form'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('productForm_nameField')),
          'Cotton T-Shirt',
        );
        await tester.enterText(
          find.byKey(const Key('productForm_descriptionField')),
          'Plain white cotton t-shirt',
        );
        await tester.enterText(
          find.byKey(const Key('productForm_priceField')),
          '199.99',
        );
        await tester.tap(find.byKey(const Key('productForm_currencyDropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('EGP').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('productForm_categoryDropdown')));
        await tester.pumpAndSettle();
        // The child category renders with its indentation prefix
        // ('— Men'), not the bare name — confirmed against
        // `_flattenCategories`/`_buildCategoryField`'s own rendering
        // (`'—' * depth` + a space + the name for any depth > 0).
        await tester.tap(find.text('— Men').last);
        await tester.pumpAndSettle();

        // Add one variant.
        await tester.tap(
          find.byKey(const Key('productForm_addVariantButton')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('productForm_variantName_0')),
          'Size',
        );
        await tester.enterText(
          find.byKey(const Key('productForm_variantValue_0')),
          'Large',
        );

        await _tapSubmit(tester);

        expect(productRepository.createProductCallCount, 1);
        expect(productRepository.lastCreateArgs?['name'], 'Cotton T-Shirt');
        expect(productRepository.lastCreateArgs?['price'], '199.99');
        expect(productRepository.lastCreateArgs?['currency'], Currency.egp);
        expect(productRepository.lastCreateArgs?['categoryId'], 2);

        expect(variantRepository.createVariantCallCount, 1);
        expect(variantRepository.createdVariants.single.name, 'Size');
        expect(variantRepository.createdVariants.single.value, 'Large');
        expect(variantRepository.createdVariants.single.productId, 42);

        expect(find.text('POPPED_WITH:true'), findsOneWidget);
      },
    );
  });

  group('ProductFormScreen — edit', () {
    const existing = Product(
      id: 7,
      businessId: 1,
      categoryId: 1,
      name: 'Leather Belt',
      description: 'Brown leather belt',
      price: '89.99',
      currency: Currency.aed,
      variants: [ProductVariant(id: 3, name: 'Size', value: 'M')],
    );

    testWidgets('pre-fills every field from the existing product', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        productRepository: _FakeProductRepository(),
        existingProduct: existing,
      );

      expect(find.text('Edit product'), findsOneWidget);
      expect(find.text('Leather Belt'), findsOneWidget);
      expect(find.text('Brown leather belt'), findsOneWidget);
      expect(find.text('89.99'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      // The pre-existing variant row is shown, pre-filled.
      expect(
        find.byKey(const Key('productForm_variantName_0')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('productForm_variantName_0')),
                matching: find.byType(TextField),
              ),
            )
            .controller
            ?.text,
        'Size',
      );
    });
  });
}