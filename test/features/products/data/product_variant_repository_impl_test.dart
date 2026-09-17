import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/products/data/product_variant_repository_impl.dart';

/// Part P-032B scope. Exercises [ProductVariantRepositoryImpl] against
/// a mocked Dio adapter shaped like the confirmed real
/// `/api/v1/products/<product_pk>/variants/...` contract (confirmed
/// directly from `products/views.py` / `products/serializers.py` on
/// `github.com/Ahmed2132003/cavallo-app` — not guessed). Mirrors
/// `product_repository_impl_test.dart`'s exact setup: a real
/// `ErrorInterceptor` attached to a mocked adapter.
///
/// Unlike that file, no `_FakeJsonAdapter` workaround is needed
/// anywhere here — every request body on this contract is a plain JSON
/// `Map` (never `FormData`), which `DioAdapter`'s own `data:` matcher
/// can match directly by equality.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ProductVariantRepositoryImpl repository;

  const variantJson = {'id': 1, 'name': 'Size', 'value': 'Large'};

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());

    repository = ProductVariantRepositoryImpl(dio: dio);
  });

  group('createVariant', () {
    test('POSTs {name, value} to the product-scoped variants endpoint', () async {
      adapter.onPost(
        '/api/v1/products/10/variants/',
        (server) => server.reply(201, variantJson),
        data: {'name': 'Size', 'value': 'Large'},
      );

      final variant = await repository.createVariant(
        productId: 10,
        name: 'Size',
        value: 'Large',
      );

      expect(variant.id, 1);
      expect(variant.name, 'Size');
      expect(variant.value, 'Large');
    });

    test('a 403 on a product owned by another business surfaces as AuthFailure', () async {
      adapter.onPost(
        '/api/v1/products/10/variants/',
        (server) => server.reply(403, {
          'error': {
            'code': 'PERMISSION_DENIED',
            'message':
                'You do not have permission to add a variant to this product.',
          },
        }),
        data: {'name': 'Size', 'value': 'Large'},
      );

      try {
        await repository.createVariant(
          productId: 10,
          name: 'Size',
          value: 'Large',
        );
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<AuthFailure>());
      }
    });
  });

  group('updateVariant', () {
    test('PATCHes only the fields actually passed', () async {
      adapter.onPatch(
        '/api/v1/products/10/variants/1/',
        (server) => server.reply(200, {
          'id': 1,
          'name': 'Size',
          'value': 'Medium',
        }),
        data: {'value': 'Medium'},
      );

      final variant = await repository.updateVariant(
        productId: 10,
        variantId: 1,
        value: 'Medium',
      );

      expect(variant.id, 1);
      expect(variant.value, 'Medium');
      // Reaching here proves the body contained *only* `value` — `name`
      // was correctly left out of the request.
    });
  });

  group('deleteVariant', () {
    test('DELETEs the variant by product id + variant id (real hard delete)', () async {
      adapter.onDelete(
        '/api/v1/products/10/variants/1/',
        (server) => server.reply(204, null),
      );

      await repository.deleteVariant(productId: 10, variantId: 1);
      // No exception thrown — success.
    });

    test('a 403 on a variant belonging to another business surfaces as AuthFailure', () async {
      adapter.onDelete(
        '/api/v1/products/10/variants/1/',
        (server) => server.reply(403, {
          'error': {
            'code': 'PERMISSION_DENIED',
            'message': 'You do not have permission to modify this variant.',
          },
        }),
      );

      try {
        await repository.deleteVariant(productId: 10, variantId: 1);
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<AuthFailure>());
      }
    });
  });
}