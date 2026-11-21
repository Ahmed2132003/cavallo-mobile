import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/business_console/data/business_analytics_repository.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_content.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_orders_summary.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_overview.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_period.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_products.dart';

import '../bi_fixtures.dart';

/// Part BI-04: the repository contract. Each `onGet` pins the exact path AND
/// the exact query parameters, so a wrong name (`period=`, `business_id`, a
/// missing `date_to`) makes the request fail loudly. A real [ErrorInterceptor]
/// sits on a mocked adapter, like the P-085 repository test.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late BusinessAnalyticsRepositoryImpl repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());
    repository = BusinessAnalyticsRepositoryImpl(dio: dio);
  });

  final AnalyticsPeriod period = AnalyticsPeriod.resolve(
    AnalyticsPreset.custom,
    now: DateTime.utc(2026, 10, 15),
    customFrom: DateTime.utc(2026, 10, 1),
    customTo: DateTime.utc(2026, 10, 7),
  );
  const Map<String, dynamic> dates = <String, dynamic>{
    'date_from': '2026-10-01',
    'date_to': '2026-10-07',
  };

  group('paths', () {
    test('every endpoint path', () {
      expect(
        BusinessAnalyticsRepositoryImpl.overviewPath(42),
        '/api/v1/analytics/business/42/overview/',
      );
      expect(
        BusinessAnalyticsRepositoryImpl.productsPath(42),
        '/api/v1/analytics/business/42/products/',
      );
      expect(
        BusinessAnalyticsRepositoryImpl.productDetailPath(42, 7),
        '/api/v1/analytics/business/42/products/7/',
      );
      expect(
        BusinessAnalyticsRepositoryImpl.contentPath(42),
        '/api/v1/analytics/business/42/content/',
      );
      expect(
        BusinessAnalyticsRepositoryImpl.contentDetailPath(42, 'reel', 9),
        '/api/v1/analytics/business/42/content/reel/9/',
      );
      expect(
        BusinessAnalyticsRepositoryImpl.externalMetricsPath(42, 'post', 5),
        '/api/v1/analytics/business/42/content/post/5/external-metrics/',
      );
      expect(
        BusinessAnalyticsRepositoryImpl.ordersSummaryPath(42),
        '/api/v1/analytics/business/42/orders-summary/',
      );
    });
  });

  group('overview', () {
    test(
      'sends only date_from + date_to (no period, no business_id)',
      () async {
        adapter.onGet(
          BusinessAnalyticsRepositoryImpl.overviewPath(42),
          (server) => server.reply(200, biOverviewJson()),
          queryParameters: dates,
        );

        final AnalyticsOverview o = await repository.fetchOverview(
          businessId: 42,
          period: period,
        );

        expect(o.businessId, 42);
        expect(o.metrics.orders, 10);
        expect(o.previous, isNull);
      },
    );
  });

  group('products: sorting and pagination', () {
    test('defaults: page 1, page_size 20, ordering -views', () async {
      adapter.onGet(
        BusinessAnalyticsRepositoryImpl.productsPath(42),
        (server) => server.reply(200, biProductsPageJson()),
        queryParameters: <String, dynamic>{
          ...dates,
          'page': 1,
          'page_size': 20,
          'ordering': '-views',
        },
      );

      final ProductsPage page = await repository.fetchProducts(
        businessId: 42,
        period: period,
        sort: ProductSort.mostViewed,
        page: 1,
      );

      expect(page.results, hasLength(1));
      expect(BusinessAnalyticsRepositoryImpl.defaultPageSize, 20);
      expect(BusinessAnalyticsRepositoryImpl.maxPageSize, 100);
    });

    test('every ProductSort sends its exact ordering value', () async {
      for (final ProductSort sort in ProductSort.values) {
        adapter.onGet(
          BusinessAnalyticsRepositoryImpl.productsPath(42),
          (server) => server.reply(200, biProductsPageJson()),
          queryParameters: <String, dynamic>{
            ...dates,
            'page': 1,
            'page_size': 20,
            'ordering': sort.ordering,
          },
        );

        final ProductsPage page = await repository.fetchProducts(
          businessId: 42,
          period: period,
          sort: sort,
          page: 1,
        );

        expect(page.results, isNotEmpty, reason: sort.name);
      }
    });

    test('lowest conversion sends ordering=conversion (ascending)', () async {
      adapter.onGet(
        BusinessAnalyticsRepositoryImpl.productsPath(42),
        (server) => server.reply(200, biProductsPageJson()),
        queryParameters: <String, dynamic>{
          ...dates,
          'page': 1,
          'page_size': 20,
          'ordering': 'conversion',
        },
      );

      final ProductsPage page = await repository.fetchProducts(
        businessId: 42,
        period: period,
        sort: ProductSort.lowestConversion,
        page: 1,
      );

      expect(page.results, hasLength(1));
    });

    test('page 2 with a custom page size', () async {
      adapter.onGet(
        BusinessAnalyticsRepositoryImpl.productsPath(42),
        (server) => server.reply(
          200,
          biProductsPageJson(page: 2, pageSize: 50, totalPages: 2),
        ),
        queryParameters: <String, dynamic>{
          ...dates,
          'page': 2,
          'page_size': 50,
          'ordering': '-orders',
        },
      );

      final ProductsPage page = await repository.fetchProducts(
        businessId: 42,
        period: period,
        sort: ProductSort.mostOrdered,
        page: 2,
        pageSize: 50,
      );

      expect(page.meta.page, 2);
      expect(page.meta.hasMore, isFalse);
    });

    test('page < 1 and page_size outside 1..100 are rejected locally', () {
      expect(
        () => repository.fetchProducts(
          businessId: 42,
          period: period,
          sort: ProductSort.mostViewed,
          page: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.fetchProducts(
          businessId: 42,
          period: period,
          sort: ProductSort.mostViewed,
          page: 1,
          pageSize: 101,
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.fetchProducts(
          businessId: 42,
          period: period,
          sort: ProductSort.mostViewed,
          page: 1,
          pageSize: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('product detail', () {
    test('GET products/{id}/ with the period only', () async {
      adapter.onGet(
        BusinessAnalyticsRepositoryImpl.productDetailPath(42, 1),
        (server) => server.reply(200, biProductDetailJson()),
        queryParameters: dates,
      );

      final ProductAnalyticsDetail d = await repository.fetchProductDetail(
        businessId: 42,
        productId: 1,
        period: period,
      );

      expect(d.product.productId, 1);
      expect(d.trend, hasLength(2));
    });

    test('another merchant\'s / missing product is a 404 ApiFailure', () async {
      adapter.onGet(
        BusinessAnalyticsRepositoryImpl.productDetailPath(42, 999),
        (server) =>
            server.reply(404, <String, dynamic>{'detail': 'Not found.'}),
        queryParameters: dates,
      );

      await expectLater(
        repository.fetchProductDetail(
          businessId: 42,
          productId: 999,
          period: period,
        ),
        throwsA(isA<ApiFailure>()),
      );
    });
  });

  group('content', () {
    test('sends type, page, page_size and ordering', () async {
      adapter.onGet(
        BusinessAnalyticsRepositoryImpl.contentPath(42),
        (server) => server.reply(200, biContentPageJson()),
        queryParameters: <String, dynamic>{
          ...dates,
          'type': 'all',
          'page': 1,
          'page_size': 20,
          'ordering': '-views',
        },
      );

      final ContentPage page = await repository.fetchContent(
        businessId: 42,
        period: period,
        type: ContentTypeFilter.all,
        sort: ContentSort.mostViewed,
        page: 1,
      );

      expect(page.results, hasLength(1));
    });

    test('every ContentSort and type sends its exact wire value', () async {
      for (final ContentTypeFilter type in ContentTypeFilter.values) {
        for (final ContentSort sort in ContentSort.values) {
          adapter.onGet(
            BusinessAnalyticsRepositoryImpl.contentPath(42),
            (server) =>
                server.reply(200, biContentPageJson(type: type.wire)),
            queryParameters: <String, dynamic>{
              ...dates,
              'type': type.wire,
              'page': 1,
              'page_size': 20,
              'ordering': sort.ordering,
            },
          );

          final ContentPage page = await repository.fetchContent(
            businessId: 42,
            period: period,
            type: type,
            sort: sort,
            page: 1,
          );

          expect(page.type, type.wire, reason: '${type.name}/${sort.name}');
        }
      }
    });

    test('detail path uses the content type and id', () async {
      adapter.onGet(
        BusinessAnalyticsRepositoryImpl.contentDetailPath(42, 'post', 5),
        (server) => server.reply(200, biContentDetailJson()),
        queryParameters: dates,
      );

      final ContentDetail d = await repository.fetchContentDetail(
        businessId: 42,
        period: period,
        contentType: 'post',
        contentId: 5,
      );

      expect(d.content.contentId, 5);
    });

    test('a content type other than post/reel is rejected locally', () {
      expect(
        () => repository.fetchContentDetail(
          businessId: 42,
          period: period,
          contentType: 'story',
          contentId: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.fetchExternalMetrics(
          businessId: 42,
          contentType: 'story',
          contentId: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('external metrics', () {
    test('GET returns the latest snapshots', () async {
      adapter.onGet(
        BusinessAnalyticsRepositoryImpl.externalMetricsPath(42, 'post', 5),
        (server) => server.reply(200, biExternalMetricsJson()),
      );

      final ExternalMetricsResponse r = await repository.fetchExternalMetrics(
        businessId: 42,
        contentType: 'post',
        contentId: 5,
      );

      expect(r.metrics.single.value, 1200);
      expect(r.providersRegistered, isEmpty);
    });

    test('POST sends the manual body and parses the 201 metric', () async {
      adapter.onPost(
        BusinessAnalyticsRepositoryImpl.externalMetricsPath(42, 'post', 5),
        (server) => server.reply(201, biExternalMetricJson()),
        data: <String, dynamic>{
          'platform': 'instagram',
          'metric_type': 'views',
          'metric_value': 1200,
        },
      );

      final ExternalMetric m = await repository.submitExternalMetric(
        businessId: 42,
        contentType: 'post',
        contentId: 5,
        input: ExternalMetricInput(
          platform: 'instagram',
          metricType: 'views',
          metricValue: 1200,
        ),
      );

      expect(m.platform, 'instagram');
      expect(m.value, 1200);
      expect(m.isManual, isTrue);
    });

    test('a 400 validation error on POST surfaces as an ApiFailure', () async {
      adapter.onPost(
        BusinessAnalyticsRepositoryImpl.externalMetricsPath(42, 'post', 5),
        (server) => server.reply(400, <String, dynamic>{
          'captured_at': <String>['Must not be in the future.'],
        }),
        data: <String, dynamic>{
          'platform': 'instagram',
          'metric_type': 'views',
          'metric_value': 1,
        },
      );

      await expectLater(
        repository.submitExternalMetric(
          businessId: 42,
          contentType: 'post',
          contentId: 5,
          input: ExternalMetricInput(
            platform: 'instagram',
            metricType: 'views',
            metricValue: 1,
          ),
        ),
        throwsA(isA<ApiFailure>()),
      );
    });
  });

  group('orders summary', () {
    test('always sends date_to and the default top = 5', () async {
      adapter.onGet(
        BusinessAnalyticsRepositoryImpl.ordersSummaryPath(42),
        (server) => server.reply(200, biOrdersSummaryJson()),
        queryParameters: <String, dynamic>{...dates, 'top': 5},
      );

      final OrdersSummary s = await repository.fetchOrdersSummary(
        businessId: 42,
        period: period,
      );

      expect(s.orders, 10);
      expect(BusinessAnalyticsRepositoryImpl.defaultTop, 5);
      expect(BusinessAnalyticsRepositoryImpl.maxTop, 20);
    });

    test('top 20 is accepted; 0 and 21 are rejected locally', () async {
      adapter.onGet(
        BusinessAnalyticsRepositoryImpl.ordersSummaryPath(42),
        (server) => server.reply(200, biOrdersSummaryJson()),
        queryParameters: <String, dynamic>{...dates, 'top': 20},
      );

      final OrdersSummary s = await repository.fetchOrdersSummary(
        businessId: 42,
        period: period,
        top: 20,
      );
      expect(s.orders, 10);

      expect(
        () => repository.fetchOrdersSummary(
          businessId: 42,
          period: period,
          top: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.fetchOrdersSummary(
          businessId: 42,
          period: period,
          top: 21,
        ),
        throwsArgumentError,
      );
    });
  });

  group('failures', () {
    test('an HTTP error becomes the typed ApiFailure', () async {
      adapter.onGet(
        BusinessAnalyticsRepositoryImpl.overviewPath(42),
        (server) =>
            server.reply(403, <String, dynamic>{'detail': 'Forbidden.'}),
        queryParameters: dates,
      );

      await expectLater(
        repository.fetchOverview(businessId: 42, period: period),
        throwsA(isA<ApiFailure>()),
      );
    });

    test('a bare array instead of an object is an UnknownFailure', () async {
      adapter.onGet(
        BusinessAnalyticsRepositoryImpl.overviewPath(42),
        (server) => server.reply(200, <dynamic>[]),
        queryParameters: dates,
      );

      await expectLater(
        repository.fetchOverview(businessId: 42, period: period),
        throwsA(isA<UnknownFailure>()),
      );
    });

    test(
      'a response with a missing section is an UnknownFailure, not zeros',
      () async {
        final Map<String, dynamic> broken =
            biOverviewJson()..remove('overview');
        adapter.onGet(
          BusinessAnalyticsRepositoryImpl.overviewPath(42),
          (server) => server.reply(200, broken),
          queryParameters: dates,
        );

        await expectLater(
          repository.fetchOverview(businessId: 42, period: period),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );
  });
}
