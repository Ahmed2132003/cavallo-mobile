/// Part BI-04: `GET /api/v1/analytics/business/{id}/orders-summary/`.
///
/// Computed live from orders (no rollup). These are merchant-recorded sales,
/// not collected payments. Sales Value = confirmed + processing + shipped +
/// delivered; pending and cancelled are never revenue. [sales] is one entry
/// per currency and is never summed across currencies.
library;

import '../../orders/domain/order_status.dart';
import 'analytics_common.dart';

class OrderStatusCount {
  const OrderStatusCount({required this.status, required this.orders});

  /// [OrderStatus.unknown] if the server sends a status this app does not
  /// know.
  final OrderStatus status;
  final int orders;
}

class OrdersTrendPoint {
  const OrdersTrendPoint({
    required this.date,
    required this.orders,
    required this.soldOrders,
    required this.sales,
  });

  final DateTime date;
  final int orders;
  final int soldOrders;

  /// currency -> amount string; empty when none.
  final Map<String, String> sales;
}

class TopProduct {
  const TopProduct({
    required this.productId,
    required this.name,
    required this.currency,
    required this.salesValue,
    required this.soldOrders,
    required this.units,
  });

  final int productId;
  final String name;
  final String currency;
  final String salesValue;
  final int soldOrders;
  final int units;
}

class OrdersSummary {
  const OrdersSummary({
    required this.businessId,
    required this.period,
    required this.orders,
    required this.units,
    required this.byStatus,
    required this.sales,
    required this.salesDefinition,
    required this.trend,
    required this.topProducts,
    required this.dataUpdatedAt,
  });

  final int businessId;
  final AnalyticsPeriodInfo period;
  final int orders;

  /// Units of SOLD orders.
  final int units;

  /// All 6 statuses, in lifecycle order.
  final List<OrderStatusCount> byStatus;
  final List<SalesEntry> sales;
  final String? salesDefinition;

  /// One row per day of the range.
  final List<OrdersTrendPoint> trend;

  /// By sales value, descending.
  final List<TopProduct> topProducts;
  final DateTime? dataUpdatedAt;
}
