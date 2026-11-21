/// Part BI-04: the data layer of the Business Analytics DASHBOARD
/// (overview / products / content / external metrics / orders summary).
///
/// Separate from the older `AnalyticsRepository` (daily rollups, P-085),
/// which is left untouched.
///
/// ### Contract (api_contract_BI02.md, read from the real backend)
/// Base `/api/v1/analytics/business/{id}/...`, Bearer auth. Every method
/// sends the shared period as `date_from` + `date_to` (see `AnalyticsPeriod`).
/// Products and content lists are PAGE based (`page`, `page_size` max 100,
/// `ordering`), not cursor based. `business_id` is never sent in a query or
/// body (the path id is the only one the server honours).
///
/// ### Failures
/// Same convention as `AnalyticsRepositoryImpl`: the shared
/// `ErrorInterceptor` has already mapped transport/HTTP errors to a typed
/// `ApiFailure`, which is rethrown as-is. A response that does not match the
/// contract becomes an `UnknownFailure` (never a partial screen of zeros).
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_client.dart';
import '../domain/analytics_content.dart';
import '../domain/analytics_orders_summary.dart';
import '../domain/analytics_overview.dart';
import '../domain/analytics_period.dart';
import '../domain/analytics_products.dart';
import 'dtos/content_dto.dart';
import 'dtos/dto_parsing.dart';
import 'dtos/orders_summary_dto.dart';
import 'dtos/overview_dto.dart';
import 'dtos/products_dto.dart';

abstract class BusinessAnalyticsRepository {
  Future<AnalyticsOverview> fetchOverview({
    required int businessId,
    required AnalyticsPeriod period,
  });

  Future<ProductsPage> fetchProducts({
    required int businessId,
    required AnalyticsPeriod period,
    required ProductSort sort,
    required int page,
    int pageSize,
  });

  Future<ProductAnalyticsDetail> fetchProductDetail({
    required int businessId,
    required int productId,
    required AnalyticsPeriod period,
  });

  Future<ContentPage> fetchContent({
    required int businessId,
    required AnalyticsPeriod period,
    required ContentTypeFilter type,
    required ContentSort sort,
    required int page,
    int pageSize,
  });

  /// [contentType] is "post" or "reel".
  Future<ContentDetail> fetchContentDetail({
    required int businessId,
    required AnalyticsPeriod period,
    required String contentType,
    required int contentId,
  });

  Future<ExternalMetricsResponse> fetchExternalMetrics({
    required int businessId,
    required String contentType,
    required int contentId,
  });

  /// Manual entry. NOT idempotent: the app must not auto-retry it.
  Future<ExternalMetric> submitExternalMetric({
    required int businessId,
    required String contentType,
    required int contentId,
    required ExternalMetricInput input,
  });

  Future<OrdersSummary> fetchOrdersSummary({
    required int businessId,
    required AnalyticsPeriod period,
    int top,
  });
}

class BusinessAnalyticsRepositoryImpl implements BusinessAnalyticsRepository {
  BusinessAnalyticsRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const int defaultTop = 5;
  static const int maxTop = 20;

  static String _base(int businessId) =>
      '/api/v1/analytics/business/$businessId';

  static String overviewPath(int businessId) =>
      '${_base(businessId)}/overview/';

  static String productsPath(int businessId) =>
      '${_base(businessId)}/products/';

  static String productDetailPath(int businessId, int productId) =>
      '${_base(businessId)}/products/$productId/';

  static String contentPath(int businessId) => '${_base(businessId)}/content/';

  static String contentDetailPath(
    int businessId,
    String contentType,
    int contentId,
  ) => '${_base(businessId)}/content/$contentType/$contentId/';

  static String externalMetricsPath(
    int businessId,
    String contentType,
    int contentId,
  ) =>
      '${contentDetailPath(businessId, contentType, contentId)}external-metrics/';

  static String ordersSummaryPath(int businessId) =>
      '${_base(businessId)}/orders-summary/';

  @override
  Future<AnalyticsOverview> fetchOverview({
    required int businessId,
    required AnalyticsPeriod period,
  }) {
    return _guard(() async {
      final Map<String, dynamic> json = await _get(
        overviewPath(businessId),
        period.queryParameters,
      );
      return OverviewDto.parse(json);
    });
  }

  @override
  Future<ProductsPage> fetchProducts({
    required int businessId,
    required AnalyticsPeriod period,
    required ProductSort sort,
    required int page,
    int pageSize = defaultPageSize,
  }) {
    _checkPaging(page, pageSize);
    return _guard(() async {
      final Map<String, dynamic> json =
          await _get(productsPath(businessId), <String, dynamic>{
            ...period.queryParameters,
            'page': page,
            'page_size': pageSize,
            'ordering': sort.ordering,
          });
      return ProductsDto.parsePage(json);
    });
  }

  @override
  Future<ProductAnalyticsDetail> fetchProductDetail({
    required int businessId,
    required int productId,
    required AnalyticsPeriod period,
  }) {
    return _guard(() async {
      final Map<String, dynamic> json = await _get(
        productDetailPath(businessId, productId),
        period.queryParameters,
      );
      return ProductsDto.parseDetail(json);
    });
  }

  @override
  Future<ContentPage> fetchContent({
    required int businessId,
    required AnalyticsPeriod period,
    required ContentTypeFilter type,
    required ContentSort sort,
    required int page,
    int pageSize = defaultPageSize,
  }) {
    _checkPaging(page, pageSize);
    return _guard(() async {
      final Map<String, dynamic> json =
          await _get(contentPath(businessId), <String, dynamic>{
            ...period.queryParameters,
            'type': type.wire,
            'page': page,
            'page_size': pageSize,
            'ordering': sort.ordering,
          });
      return ContentDto.parsePage(json);
    });
  }

  @override
  Future<ContentDetail> fetchContentDetail({
    required int businessId,
    required AnalyticsPeriod period,
    required String contentType,
    required int contentId,
  }) {
    _checkContentType(contentType);
    return _guard(() async {
      final Map<String, dynamic> json = await _get(
        contentDetailPath(businessId, contentType, contentId),
        period.queryParameters,
      );
      return ContentDto.parseDetail(json);
    });
  }

  @override
  Future<ExternalMetricsResponse> fetchExternalMetrics({
    required int businessId,
    required String contentType,
    required int contentId,
  }) {
    _checkContentType(contentType);
    return _guard(() async {
      final Map<String, dynamic> json = await _get(
        externalMetricsPath(businessId, contentType, contentId),
        const <String, dynamic>{},
      );
      return ContentDto.parseExternalMetrics(json);
    });
  }

  @override
  Future<ExternalMetric> submitExternalMetric({
    required int businessId,
    required String contentType,
    required int contentId,
    required ExternalMetricInput input,
  }) {
    _checkContentType(contentType);
    return _guard(() async {
      final Response<dynamic> response = await _dio.post<dynamic>(
        externalMetricsPath(businessId, contentType, contentId),
        data: ContentDto.inputToJson(input),
      );
      return ContentDto.externalMetric(
        DtoParsing.asMap(response.data, 'external metric response'),
        'external metric response',
      );
    });
  }

  @override
  Future<OrdersSummary> fetchOrdersSummary({
    required int businessId,
    required AnalyticsPeriod period,
    int top = defaultTop,
  }) {
    if (top < 1 || top > maxTop) {
      throw ArgumentError.value(top, 'top', 'must be 1..$maxTop.');
    }
    return _guard(() async {
      // date_to is ALWAYS sent: the server's own default is its local "today".
      final Map<String, dynamic> json = await _get(
        ordersSummaryPath(businessId),
        <String, dynamic>{...period.queryParameters, 'top': top},
      );
      return OrdersSummaryDto.parse(json);
    });
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, dynamic> query,
  ) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      path,
      queryParameters: query,
    );
    return DtoParsing.asMap(response.data, 'response');
  }

  static void _checkPaging(int page, int pageSize) {
    if (page < 1) {
      throw ArgumentError.value(page, 'page', 'must be >= 1.');
    }
    if (pageSize < 1 || pageSize > maxPageSize) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'must be 1..$maxPageSize.',
      );
    }
  }

  static void _checkContentType(String contentType) {
    if (contentType != 'post' && contentType != 'reel') {
      throw ArgumentError.value(
        contentType,
        'contentType',
        'must be "post" or "reel".',
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      final Object? error = e.error;
      if (error is ApiFailure) throw error;
      rethrow;
    } on FormatException catch (e) {
      throw UnknownFailure(
        message: 'Unexpected analytics response: ${e.message}',
      );
    } on TypeError {
      throw const UnknownFailure(
        message: 'Unexpected analytics response shape.',
      );
    }
  }
}

final businessAnalyticsRepositoryProvider = Provider<
  BusinessAnalyticsRepository
>((ref) => BusinessAnalyticsRepositoryImpl(dio: ref.watch(dioClientProvider)));
