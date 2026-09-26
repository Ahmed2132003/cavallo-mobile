import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/search/data/search_repository_impl.dart';
import 'package:social_commerce_app/features/search/domain/search_filters.dart';
import 'package:social_commerce_app/features/search/domain/search_result_entity.dart';

/// Part P-065 STEP 2 scope. Exercises [SearchRepositoryImpl] against a
/// mocked Dio adapter shaped like the real `GET /api/v1/search/`
/// contract confirmed from `search/views.py`/`search/serializers.py`
/// on `cavallo-app` main. Same setup convention as
/// `feed_repository_test.dart` (Part P-061): a real [ErrorInterceptor]
/// on a mocked adapter.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late SearchRepositoryImpl repository;

  const businessJson = {
    'result_type': 'business',
    'id': 7,
    'business_name': 'Cairo Textiles',
    'business_type': 'factory',
    'country': 'Egypt',
    'city': 'Cairo',
    'description': 'Wholesale fabric factory',
    'phone_number': '+201001234567',
    'category': 3,
    'is_verified': true,
    'follower_count': 240,
  };

  const productJson = {
    'result_type': 'product',
    'id': 55,
    'business': 7,
    'category': 3,
    'name': 'Cotton Roll',
    'description': 'Raw cotton fabric roll',
    'price': '199.99',
    'currency': 'EGP',
    'image': 'https://cdn.example.com/products/55.png',
    'is_active': true,
    'variants': [],
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
  };

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());

    repository = SearchRepositoryImpl(dio: dio);
  });

  group('search', () {
    test(
      'a bare call (no q, no filters, no cursor) sends an empty query '
      'string and parses mixed business/product items in order',
      () async {
        adapter.onGet(
          '/api/v1/search/',
          (server) => server.reply(200, {
            'items': [businessJson, productJson],
            'next_cursor': 'abc123opaque',
          }),
          queryParameters: {},
        );

        final page = await repository.search();

        expect(page.items, hasLength(2));

        expect(page.items[0], isA<BusinessSearchResult>());
        final business = (page.items[0] as BusinessSearchResult).business;
        expect(business.id, 7);
        expect(business.businessName, 'Cairo Textiles');
        expect(business.businessType, BusinessType.factory);
        expect(business.phoneNumber, '+201001234567');
        expect(business.isVerified, isTrue);

        expect(page.items[1], isA<ProductSearchResult>());
        final product = (page.items[1] as ProductSearchResult).product;
        expect(product.id, 55);
        expect(product.name, 'Cotton Roll');
        expect(product.price, '199.99');
        expect(product.currency, Currency.egp);

        expect(page.nextCursor, 'abc123opaque');
      },
    );

    test(
      'q and every filter field are sent as their own query parameter, '
      'combinable in a single call',
      () async {
        adapter.onGet(
          '/api/v1/search/',
          (server) => server.reply(200, {'items': [], 'next_cursor': null}),
          queryParameters: {
            'q': 'fabric',
            'category': '3',
            'country': 'Egypt',
            'city': 'Cairo',
            'business_type': 'factory',
            'min_rating': '4',
            'featured_only': 'true',
            'min_price': '50',
            'max_price': '500',
          },
        );

        final page = await repository.search(
          q: 'fabric',
          filters: const SearchFilters(
            categoryId: 3,
            country: 'Egypt',
            city: 'Cairo',
            businessType: 'factory',
            minRating: '4',
            featuredOnly: true,
            minPrice: '50',
            maxPrice: '500',
          ),
        );

        expect(page.items, isEmpty);
      },
    );

    test(
      'featured_only is omitted entirely (not sent as false) when unset',
      () async {
        adapter.onGet(
          '/api/v1/search/',
          (server) => server.reply(200, {'items': [], 'next_cursor': null}),
          queryParameters: {'q': 'fabric'},
        );

        await repository.search(q: 'fabric');
      },
    );

    test(
      'a non-null cursor is sent back to the server completely verbatim, '
      'never parsed or rebuilt',
      () async {
        const opaqueCursor = 'eyJ2IjoxLCJwIjoiZiJ9-weird-but-opaque';
        adapter.onGet(
          '/api/v1/search/',
          (server) => server.reply(200, {'items': [], 'next_cursor': null}),
          queryParameters: {'cursor': opaqueCursor},
        );

        final page = await repository.search(cursor: opaqueCursor);

        expect(page.items, isEmpty);
        expect(page.nextCursor, isNull);
      },
    );

    test('next_cursor: null means no more pages', () async {
      adapter.onGet(
        '/api/v1/search/',
        (server) => server.reply(200, {
          'items': [productJson],
          'next_cursor': null,
        }),
        queryParameters: {},
      );

      final page = await repository.search();

      expect(page.nextCursor, isNull);
    });

    test('an unknown result_type throws FormatException', () async {
      adapter.onGet(
        '/api/v1/search/',
        (server) => server.reply(200, {
          'items': [
            {...productJson, 'result_type': 'post'},
          ],
          'next_cursor': null,
        }),
        queryParameters: {},
      );

      expect(() => repository.search(), throwsFormatException);
    });

    test('a genuine 500 propagates as ServerFailure', () async {
      adapter.onGet(
        '/api/v1/search/',
        (server) => server.reply(500, {
          'error': {'code': 'SERVER_ERROR', 'message': 'Something broke'},
        }),
        queryParameters: {},
      );

      try {
        await repository.search();
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ServerFailure>());
      }
    });
  });
}