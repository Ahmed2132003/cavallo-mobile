import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/products/data/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';

/// Part P-034 scope. Exercises [ProductPublicRepositoryImpl] against a
/// mocked Dio adapter shaped like the real public contract confirmed in
/// Part P-032's `products/views.py` (`ProductDetailView` GET,
/// `ProductPublicListView`). Same setup as
/// `business_profile_public_repository_impl_test.dart` (Part P-029): a
/// real [ErrorInterceptor] attached to a mocked adapter, so failure-path
/// assertions see genuine [ApiFailure] variants.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ProductPublicRepositoryImpl repository;

  const fullJson = {
    'id': 10,
    'business': 7,
    'category': 3,
    'name': 'Cotton T-Shirt',
    'description': 'Plain white cotton t-shirt',
    'price': '199.99',
    'currency': 'EGP',
    'image': 'https://cdn.example.com/products/10.png',
    'is_active': true,
    'variants': [
      {'id': 1, 'name': 'Size', 'value': 'Large'},
      {'id': 2, 'name': 'Color', 'value': 'Blue'},
    ],
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-02T12:30:00Z',
  };

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());

    repository = ProductPublicRepositoryImpl(dio: dio);
  });

  group('fetchPublicProduct', () {
    test('maps a 200 response to a Product, including variants', () async {
      adapter.onGet(
        '/api/v1/products/10/',
        (server) => server.reply(200, fullJson),
      );

      final product = await repository.fetchPublicProduct(10);

      expect(product, isNotNull);
      expect(product!.id, 10);
      expect(product.businessId, 7);
      expect(product.name, 'Cotton T-Shirt');
      expect(product.price, '199.99');
      expect(product.currency, Currency.egp);
      expect(product.imageUrl, 'https://cdn.example.com/products/10.png');
      expect(product.variants, hasLength(2));
      expect(product.variants.first.name, 'Size');
      expect(product.variants.first.value, 'Large');
    });

    test('an inactive product (is_active false) returns null — the backend '
        'detail GET serves hidden products, a public reader must not see '
        'them', () async {
      adapter.onGet(
        '/api/v1/products/11/',
        (server) =>
            server.reply(200, {...fullJson, 'id': 11, 'is_active': false}),
      );

      final product = await repository.fetchPublicProduct(11);

      expect(product, isNull);
    });

    test('a 404 (product does not exist) returns null — never thrown as an '
        'error', () async {
      adapter.onGet(
        '/api/v1/products/999999/',
        (server) => server.reply(404, {
          'error': {'code': 'NOT_FOUND', 'message': 'Not found.'},
        }),
      );

      final product = await repository.fetchPublicProduct(999999);

      expect(product, isNull);
    });

    test('a genuine 500 still propagates as ServerFailure, not null', () async {
      adapter.onGet(
        '/api/v1/products/10/',
        (server) => server.reply(500, {
          'error': {'code': 'SERVER_ERROR', 'message': 'Something broke'},
        }),
      );

      try {
        await repository.fetchPublicProduct(10);
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ServerFailure>());
      }
    });

    test(
      'a network failure (no connectivity) propagates as NetworkFailure',
      () async {
        adapter.onGet(
          '/api/v1/products/10/',
          (server) => server.throws(
            0,
            DioException.connectionError(
              requestOptions: RequestOptions(path: '/api/v1/products/10/'),
              reason: 'Failed host lookup',
            ),
          ),
        );

        try {
          await repository.fetchPublicProduct(10);
          fail('Expected a DioException to be thrown');
        } on DioException catch (e) {
          expect(e.error, isA<NetworkFailure>());
        }
      },
    );
  });

  group('fetchBusinessProducts', () {
    test('sends business_id and parses a paginated response', () async {
      adapter.onGet(
        '/api/v1/products/public/',
        (server) => server.reply(200, {
          'results': [
            fullJson,
            {...fullJson, 'id': 12, 'name': 'Denim Jacket'},
          ],
          'next': null,
          'previous': null,
        }),
        queryParameters: {'business_id': 7},
      );

      final page = await repository.fetchBusinessProducts(7);

      expect(page.results, hasLength(2));
      expect(page.results.first.id, 10);
      expect(page.results.last.name, 'Denim Jacket');
      expect(page.next, isNull);
    });

    test('an empty results list is a valid empty page, not an error', () async {
      adapter.onGet(
        '/api/v1/products/public/',
        (server) =>
            server.reply(200, {'results': [], 'next': null, 'previous': null}),
        queryParameters: {'business_id': 8},
      );

      final page = await repository.fetchBusinessProducts(8);

      expect(page.results, isEmpty);
    });

    test('a genuine 500 propagates as ServerFailure', () async {
      adapter.onGet(
        '/api/v1/products/public/',
        (server) => server.reply(500, {
          'error': {'code': 'SERVER_ERROR', 'message': 'Something broke'},
        }),
        queryParameters: {'business_id': 7},
      );

      try {
        await repository.fetchBusinessProducts(7);
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ServerFailure>());
      }
    });
  });
}
