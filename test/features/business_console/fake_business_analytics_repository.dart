import 'dart:async';

import 'package:social_commerce_app/features/business_console/data/business_analytics_repository.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_content.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_orders_summary.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_overview.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_period.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_products.dart';

/// Part BI-04 (tests): hand-rolled fake of [BusinessAnalyticsRepository], same
/// convention as `FakeAnalyticsRepository` (no mocking package, no network).
///
/// * Returns exactly the entities it was given (no zero-fill).
/// * Records every call: [calls] holds one method name per call
///   (`overview`, `products`, `productDetail`, `content`, `contentDetail`,
///   `external`, `submit`, `orders`) and the typed lists below hold the
///   arguments.
/// * [errors] maps a method name to the object it must throw instead.
/// * [gate]: while a [Completer] is set and not completed, every call stays
///   pending, which keeps a screen in its loading state.
class FakeBusinessAnalyticsRepository implements BusinessAnalyticsRepository {
  FakeBusinessAnalyticsRepository({
    this.overview,
    this.productsPages = const <ProductsPage>[],
    this.productDetail,
    this.contentPages = const <ContentPage>[],
    this.contentDetail,
    this.externalMetrics,
    this.ordersSummary,
  });

  AnalyticsOverview? overview;

  /// Page N of the products list is `productsPages[N - 1]`.
  List<ProductsPage> productsPages;
  ProductAnalyticsDetail? productDetail;

  /// Page N of the content list is `contentPages[N - 1]`.
  List<ContentPage> contentPages;
  ContentDetail? contentDetail;
  ExternalMetricsResponse? externalMetrics;
  OrdersSummary? ordersSummary;

  final Map<String, Object> errors = <String, Object>{};
  Completer<void>? gate;

  final List<String> calls = <String>[];
  final List<({int businessId, AnalyticsPeriod period})> overviewCalls =
      <({int businessId, AnalyticsPeriod period})>[];
  final List<
    ({
      int businessId,
      AnalyticsPeriod period,
      ProductSort sort,
      int page,
      int pageSize,
    })
  >
  productsCalls =
      <
        ({
          int businessId,
          AnalyticsPeriod period,
          ProductSort sort,
          int page,
          int pageSize,
        })
      >[];
  final List<({int businessId, int productId, AnalyticsPeriod period})>
  productDetailCalls =
      <({int businessId, int productId, AnalyticsPeriod period})>[];
  final List<
    ({
      int businessId,
      AnalyticsPeriod period,
      ContentTypeFilter type,
      ContentSort sort,
      int page,
      int pageSize,
    })
  >
  contentCalls =
      <
        ({
          int businessId,
          AnalyticsPeriod period,
          ContentTypeFilter type,
          ContentSort sort,
          int page,
          int pageSize,
        })
      >[];
  final List<
    ({
      int businessId,
      AnalyticsPeriod period,
      String contentType,
      int contentId,
    })
  >
  contentDetailCalls =
      <
        ({
          int businessId,
          AnalyticsPeriod period,
          String contentType,
          int contentId,
        })
      >[];
  final List<({int businessId, String contentType, int contentId})>
  externalCalls = <({int businessId, String contentType, int contentId})>[];
  final List<ExternalMetricInput> submittedInputs = <ExternalMetricInput>[];
  final List<({int businessId, AnalyticsPeriod period, int top})> ordersCalls =
      <({int businessId, AnalyticsPeriod period, int top})>[];

  /// How many times [method] was called.
  int count(String method) => calls.where((String c) => c == method).length;

  Future<T> _answer<T>(String method, T? value) async {
    calls.add(method);
    final Completer<void>? pending = gate;
    if (pending != null) await pending.future;
    final Object? failure = errors[method];
    if (failure != null) throw failure;
    if (value == null) {
      throw StateError(
        'FakeBusinessAnalyticsRepository: no response configured for $method.',
      );
    }
    return value;
  }

  @override
  Future<AnalyticsOverview> fetchOverview({
    required int businessId,
    required AnalyticsPeriod period,
  }) {
    overviewCalls.add((businessId: businessId, period: period));
    return _answer<AnalyticsOverview>('overview', overview);
  }

  @override
  Future<ProductsPage> fetchProducts({
    required int businessId,
    required AnalyticsPeriod period,
    required ProductSort sort,
    required int page,
    int pageSize = BusinessAnalyticsRepositoryImpl.defaultPageSize,
  }) {
    productsCalls.add((
      businessId: businessId,
      period: period,
      sort: sort,
      page: page,
      pageSize: pageSize,
    ));
    final ProductsPage? value =
        page >= 1 && page <= productsPages.length
            ? productsPages[page - 1]
            : null;
    return _answer<ProductsPage>('products', value);
  }

  @override
  Future<ProductAnalyticsDetail> fetchProductDetail({
    required int businessId,
    required int productId,
    required AnalyticsPeriod period,
  }) {
    productDetailCalls.add((
      businessId: businessId,
      productId: productId,
      period: period,
    ));
    return _answer<ProductAnalyticsDetail>('productDetail', productDetail);
  }

  @override
  Future<ContentPage> fetchContent({
    required int businessId,
    required AnalyticsPeriod period,
    required ContentTypeFilter type,
    required ContentSort sort,
    required int page,
    int pageSize = BusinessAnalyticsRepositoryImpl.defaultPageSize,
  }) {
    contentCalls.add((
      businessId: businessId,
      period: period,
      type: type,
      sort: sort,
      page: page,
      pageSize: pageSize,
    ));
    final ContentPage? value =
        page >= 1 && page <= contentPages.length
            ? contentPages[page - 1]
            : null;
    return _answer<ContentPage>('content', value);
  }

  @override
  Future<ContentDetail> fetchContentDetail({
    required int businessId,
    required AnalyticsPeriod period,
    required String contentType,
    required int contentId,
  }) {
    contentDetailCalls.add((
      businessId: businessId,
      period: period,
      contentType: contentType,
      contentId: contentId,
    ));
    return _answer<ContentDetail>('contentDetail', contentDetail);
  }

  @override
  Future<ExternalMetricsResponse> fetchExternalMetrics({
    required int businessId,
    required String contentType,
    required int contentId,
  }) {
    externalCalls.add((
      businessId: businessId,
      contentType: contentType,
      contentId: contentId,
    ));
    return _answer<ExternalMetricsResponse>('external', externalMetrics);
  }

  @override
  Future<ExternalMetric> submitExternalMetric({
    required int businessId,
    required String contentType,
    required int contentId,
    required ExternalMetricInput input,
  }) {
    submittedInputs.add(input);
    return _answer<ExternalMetric>(
      'submit',
      ExternalMetric(
        platform: input.platform,
        metricType: input.metricType,
        value: input.metricValue,
        source: 'manual',
        lastUpdated: DateTime.utc(2026, 10, 8),
        externalReference: input.externalReference ?? '',
      ),
    );
  }

  @override
  Future<OrdersSummary> fetchOrdersSummary({
    required int businessId,
    required AnalyticsPeriod period,
    int top = BusinessAnalyticsRepositoryImpl.defaultTop,
  }) {
    ordersCalls.add((businessId: businessId, period: period, top: top));
    return _answer<OrdersSummary>('orders', ordersSummary);
  }
}
