/// Part BI-04: product analytics
/// (`.../products/` list and `.../products/{product_id}/` detail).
///
/// Gaps of the list row, by contract (never invented here): NO image, NO
/// price, NO conversations count, NO separate confirmed/completed counts.
/// Image and price come from the products feature by [ProductAnalyticsRow.productId].
/// `soldOrders` = confirmed-and-beyond.
library;

import 'analytics_common.dart';

/// Ordering keys of the products list. There is no "lowest conversion" key:
/// it is `conversion` ascending. Best-selling and highest-revenue are the
/// same single backend key (`sales`).
enum ProductSort {
  mostViewed('-views'),
  mostInterested('-interests'),
  mostOrdered('-orders'),
  highestSales('-sales'),
  highestConversion('-conversion'),
  lowestConversion('conversion');

  const ProductSort(this.ordering);

  /// The exact `ordering=` value.
  final String ordering;
}

class ProductAnalyticsRow {
  const ProductAnalyticsRow({
    required this.productId,
    required this.name,
    required this.isActive,
    required this.currency,
    required this.views,
    required this.uniqueViews,
    required this.interests,
    required this.saves,
    required this.orders,
    required this.soldOrders,
    required this.units,
    required this.sales,
    required this.conversion,
  });

  final int productId;
  final String name;
  final bool isActive;
  final String currency;
  final int? views;
  final int? uniqueViews;

  /// Distinct customers.
  final int interests;
  final int? saves;
  final int orders;
  final int soldOrders;
  final int units;
  final List<SalesEntry> sales;

  /// sold_orders / unique_views; null unless views are complete.
  final double? conversion;
}

class ProductsPage {
  const ProductsPage({
    required this.businessId,
    required this.period,
    required this.meta,
    required this.results,
    required this.coverage,
    required this.dataUpdatedAt,
  });

  final int businessId;
  final AnalyticsPeriodInfo period;
  final PageMeta meta;
  final List<ProductAnalyticsRow> results;
  final AnalyticsCoverage coverage;
  final DateTime? dataUpdatedAt;
}

class ProductAnalyticsHeader {
  const ProductAnalyticsHeader({
    required this.productId,
    required this.name,
    required this.currency,
    required this.isActive,
  });

  final int productId;
  final String name;
  final String currency;
  final bool isActive;
}

class ProductTotals {
  const ProductTotals({
    required this.views,
    required this.uniqueViews,
    required this.saves,
    required this.interests,
    required this.orders,
    required this.soldOrders,
    required this.units,
    required this.sales,
    required this.conversion,
  });

  final int? views;
  final int? uniqueViews;
  final int? saves;
  final int interests;
  final int orders;
  final int soldOrders;
  final int units;
  final List<SalesEntry> sales;
  final double? conversion;
}

/// One day of the product trend. `interests` comes from the rollup (null on
/// uncovered days) while `ProductTotals.interests` is live. [sales] is a map
/// currency -> amount string (empty when none).
class ProductTrendPoint {
  const ProductTrendPoint({
    required this.date,
    required this.views,
    required this.uniqueViews,
    required this.interests,
    required this.orders,
    required this.soldOrders,
    required this.sales,
  });

  final DateTime date;
  final int? views;
  final int? uniqueViews;
  final int? interests;
  final int orders;
  final int soldOrders;
  final Map<String, String> sales;
}

class ProductAnalyticsDetail {
  const ProductAnalyticsDetail({
    required this.businessId,
    required this.product,
    required this.period,
    required this.totals,
    required this.interestedCustomers,
    required this.funnel,
    required this.trend,
    required this.coverage,
    required this.dataUpdatedAt,
    required this.ordersDataUpdatedAt,
  });

  final int businessId;
  final ProductAnalyticsHeader product;
  final AnalyticsPeriodInfo period;
  final ProductTotals totals;
  final int interestedCustomers;
  final Funnel funnel;

  /// One row per day of the range.
  final List<ProductTrendPoint> trend;
  final AnalyticsCoverage coverage;
  final DateTime? dataUpdatedAt;
  final DateTime? ordersDataUpdatedAt;

  String get name => product.name;
  bool get isActive => product.isActive;
}
