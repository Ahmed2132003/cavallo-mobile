/// Part BI-04: wire parsing of the overview response.
library;

import '../../domain/analytics_overview.dart';
import 'analytics_common_dto.dart';
import 'dto_parsing.dart';

abstract final class OverviewDto {
  static const String _path = 'overview response';

  static AnalyticsOverview parse(Map<String, dynamic> json) {
    final Object? previousRaw = json['previous_period'];
    return AnalyticsOverview(
      businessId: DtoParsing.reqInt(json, 'business_id', _path),
      period: AnalyticsCommonDto.period(
        DtoParsing.reqMap(json, 'period', _path),
        '$_path.period',
      ),
      metrics: metrics(
        DtoParsing.reqMap(json, 'overview', _path),
        '$_path.overview',
      ),
      funnel: AnalyticsCommonDto.funnel(
        DtoParsing.reqMap(json, 'funnel', _path),
        '$_path.funnel',
      ),
      previous:
          previousRaw == null
              ? null
              : _previous(
                DtoParsing.asMap(previousRaw, '$_path.previous_period'),
                '$_path.previous_period',
              ),
      coverage: AnalyticsCommonDto.coverage(
        DtoParsing.reqMap(json, 'coverage', _path),
        '$_path.coverage',
      ),
      dataUpdatedAt: DtoParsing.optDateTime(json, 'data_updated_at', _path),
      ordersDataUpdatedAt: DtoParsing.optDateTime(
        json,
        'orders_data_updated_at',
        _path,
      ),
    );
  }

  static OverviewMetrics metrics(Map<String, dynamic> json, String path) {
    return OverviewMetrics(
      productViews: DtoParsing.optInt(json, 'product_views', path),
      productUniqueViews: DtoParsing.optInt(json, 'product_unique_views', path),
      interests: DtoParsing.reqInt(json, 'interests', path),
      interestedCustomers: DtoParsing.reqInt(
        json,
        'interested_customers',
        path,
      ),
      orders: DtoParsing.reqInt(json, 'orders', path),
      pendingOrders: DtoParsing.reqInt(json, 'pending_orders', path),
      confirmedOrders: DtoParsing.reqInt(json, 'confirmed_orders', path),
      completedOrders: DtoParsing.reqInt(json, 'completed_orders', path),
      cancelledOrders: DtoParsing.reqInt(json, 'cancelled_orders', path),
      units: DtoParsing.reqInt(json, 'units', path),
      sales: AnalyticsCommonDto.salesList(json, 'sales', path),
      contentViews: DtoParsing.optInt(json, 'content_views', path),
      contentUniqueViews: DtoParsing.optInt(json, 'content_unique_views', path),
      likes: DtoParsing.optInt(json, 'likes', path),
      comments: DtoParsing.optInt(json, 'comments', path),
      saves: DtoParsing.optInt(json, 'saves', path),
      inAppShares: DtoParsing.optInt(json, 'in_app_shares', path),
    );
  }

  static PreviousPeriod _previous(Map<String, dynamic> json, String path) {
    final Map<String, dynamic> deltasJson = DtoParsing.reqMap(
      json,
      'deltas',
      path,
    );
    final Map<String, MetricDelta> deltas = <String, MetricDelta>{};
    for (final String key in deltasJson.keys) {
      final String deltaPath = '$path.deltas.$key';
      final Map<String, dynamic> item = DtoParsing.asMap(
        deltasJson[key],
        deltaPath,
      );
      deltas[key] = MetricDelta(
        current: DtoParsing.optNum(item, 'current', deltaPath),
        previous: DtoParsing.optNum(item, 'previous', deltaPath),
        change: DtoParsing.optNum(item, 'change', deltaPath),
        changePct: DtoParsing.optDouble(item, 'change_pct', deltaPath),
      );
    }
    return PreviousPeriod(
      period: AnalyticsCommonDto.period(
        DtoParsing.reqMap(json, 'period', path),
        '$path.period',
      ),
      metrics: metrics(
        DtoParsing.reqMap(json, 'overview', path),
        '$path.overview',
      ),
      funnel: AnalyticsCommonDto.funnel(
        DtoParsing.reqMap(json, 'funnel', path),
        '$path.funnel',
      ),
      coverage: AnalyticsCommonDto.coverage(
        DtoParsing.reqMap(json, 'coverage', path),
        '$path.coverage',
      ),
      dataUpdatedAt: DtoParsing.optDateTime(json, 'data_updated_at', path),
      deltas: deltas,
    );
  }
}
