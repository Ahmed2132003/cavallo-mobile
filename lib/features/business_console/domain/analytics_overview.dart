/// Part BI-04: the overview endpoint
/// `GET /api/v1/analytics/business/{id}/overview/`.
library;

import 'analytics_common.dart';

/// The `overview` object. Nullable ints are "not available", never 0;
/// order and interest counts are real counts (0 means 0).
class OverviewMetrics {
  const OverviewMetrics({
    required this.productViews,
    required this.productUniqueViews,
    required this.interests,
    required this.interestedCustomers,
    required this.orders,
    required this.pendingOrders,
    required this.confirmedOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.units,
    required this.sales,
    required this.contentViews,
    required this.contentUniqueViews,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.inAppShares,
  });

  final int? productViews;
  final int? productUniqueViews;
  final int interests;
  final int interestedCustomers;
  final int orders;
  final int pendingOrders;
  final int confirmedOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int units;

  /// One entry per currency. Empty list = no sales.
  final List<SalesEntry> sales;
  final int? contentViews;
  final int? contentUniqueViews;
  final int? likes;
  final int? comments;
  final int? saves;
  final int? inAppShares;
}

/// `deltas.<key>`. [changePct] is a FRACTION (0.15 = +15%), null when the
/// previous value is 0 or missing.
class MetricDelta {
  const MetricDelta({
    required this.current,
    required this.previous,
    required this.change,
    required this.changePct,
  });

  final num? current;
  final num? previous;
  final num? change;
  final double? changePct;
}

class PreviousPeriod {
  const PreviousPeriod({
    required this.period,
    required this.metrics,
    required this.funnel,
    required this.coverage,
    required this.dataUpdatedAt,
    required this.deltas,
  });

  final AnalyticsPeriodInfo period;
  final OverviewMetrics metrics;
  final Funnel funnel;
  final AnalyticsCoverage coverage;
  final DateTime? dataUpdatedAt;

  /// Keys: see [OverviewMetricKeys.withDelta]. There is NO delta for sales
  /// or AOV.
  final Map<String, MetricDelta> deltas;
}

class AnalyticsOverview {
  const AnalyticsOverview({
    required this.businessId,
    required this.period,
    required this.metrics,
    required this.funnel,
    required this.previous,
    required this.coverage,
    required this.dataUpdatedAt,
    required this.ordersDataUpdatedAt,
  });

  final int businessId;
  final AnalyticsPeriodInfo period;
  final OverviewMetrics metrics;
  final Funnel funnel;

  /// Null unless BOTH windows are fully covered -> "no previous data".
  final PreviousPeriod? previous;
  final AnalyticsCoverage coverage;

  /// Real last rollup time (null if none). Shown instead of any "live" label.
  final DateTime? dataUpdatedAt;
  final DateTime? ordersDataUpdatedAt;
}

/// The delta keys the backend sends (and the only ones the UI may compare).
abstract final class OverviewMetricKeys {
  static const String productViews = 'product_views';
  static const String productUniqueViews = 'product_unique_views';
  static const String interests = 'interests';
  static const String interestedCustomers = 'interested_customers';
  static const String orders = 'orders';
  static const String pendingOrders = 'pending_orders';
  static const String confirmedOrders = 'confirmed_orders';
  static const String completedOrders = 'completed_orders';
  static const String cancelledOrders = 'cancelled_orders';
  static const String units = 'units';
  static const String contentViews = 'content_views';
  static const String contentUniqueViews = 'content_unique_views';
  static const String likes = 'likes';
  static const String comments = 'comments';
  static const String saves = 'saves';
  static const String inAppShares = 'in_app_shares';

  static const List<String> withDelta = <String>[
    productViews,
    productUniqueViews,
    interests,
    interestedCustomers,
    orders,
    pendingOrders,
    confirmedOrders,
    completedOrders,
    cancelledOrders,
    units,
    contentViews,
    contentUniqueViews,
    likes,
    comments,
    saves,
    inAppShares,
  ];
}

enum ComparisonKind { noPreviousData, up, down, unchanged }

/// What a KPI card shows next to its number.
///
/// No percentage is ever computed on the client: it only reads the backend's
/// `change_pct`. [ComparisonKind.noPreviousData] covers a null
/// `previous_period`, a metric without a delta (sales, AOV) and a null
/// `change_pct` (previous value was 0 or missing).
class MetricComparison {
  const MetricComparison._(this.kind, this.fraction);

  final ComparisonKind kind;

  /// The backend's signed fraction (0.15 = +15%); null for noPreviousData.
  final double? fraction;

  static const MetricComparison none = MetricComparison._(
    ComparisonKind.noPreviousData,
    null,
  );

  factory MetricComparison.forMetric(AnalyticsOverview overview, String key) {
    final PreviousPeriod? previous = overview.previous;
    if (previous == null) return none;
    final double? pct = previous.deltas[key]?.changePct;
    if (pct == null) return none;
    if (pct > 0) return MetricComparison._(ComparisonKind.up, pct);
    if (pct < 0) return MetricComparison._(ComparisonKind.down, pct);
    return MetricComparison._(ComparisonKind.unchanged, pct);
  }
}
