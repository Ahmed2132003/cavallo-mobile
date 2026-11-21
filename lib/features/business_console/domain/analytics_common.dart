/// Part BI-04: shapes shared by several analytics endpoints
/// (api_contract_BI02.md): coverage, response period, sales per currency,
/// funnel, and page-based pagination metadata.
///
/// Money is always a String with 2 decimals (never a double). Missing data is
/// null, never 0: every nullable field here means "the backend did not have
/// the number", and the UI shows a dash for it.
library;

class AnalyticsCoverage {
  const AnalyticsCoverage({
    required this.daysInRange,
    required this.rollupDays,
    required this.viewsAvailable,
    required this.viewsComplete,
  });

  final int daysInRange;
  final int rollupDays;

  /// false -> every view / engagement number is null.
  final bool viewsAvailable;

  /// false -> conversion rates involving views are null and previous_period
  /// is null.
  final bool viewsComplete;
}

/// The `period` object of a RESPONSE (not the app's selected filter, see
/// `AnalyticsPeriod`).
class AnalyticsPeriodInfo {
  const AnalyticsPeriodInfo({
    required this.dateFrom,
    required this.dateTo,
    required this.days,
    this.label,
  });

  final DateTime dateFrom;
  final DateTime dateTo;
  final int days;

  /// "7d" | "30d" | "90d" | "custom"; null where the contract omits it.
  final String? label;
}

/// One currency's sales. Sales are NEVER summed across currencies.
///
/// [soldOrders], [units] and [aov] are null in rows where the contract only
/// carries `currency` + `sales_value` (the products list).
class SalesEntry {
  const SalesEntry({
    required this.currency,
    required this.salesValue,
    this.soldOrders,
    this.units,
    this.aov,
  });

  final String currency;
  final String salesValue;
  final int? soldOrders;
  final int? units;
  final String? aov;
}

class FunnelStage {
  const FunnelStage({required this.key, required this.count});

  /// views | interests | orders | confirmed | completed
  final String key;
  final int? count;
}

class FunnelConversion {
  const FunnelConversion({
    required this.from,
    required this.to,
    required this.rate,
  });

  final String from;
  final String to;

  /// Fraction (0.1523 = 15.23%), null when it cannot be computed.
  final double? rate;
}

/// The funnel exactly as the backend returned it. Nothing is recomputed.
class Funnel {
  const Funnel({
    required this.stages,
    required this.conversions,
    required this.overallRate,
    required this.unitNote,
  });

  final List<FunnelStage> stages;
  final List<FunnelConversion> conversions;
  final double? overallRate;
  final String? unitNote;

  FunnelStage? stage(String key) {
    for (final FunnelStage s in stages) {
      if (s.key == key) return s;
    }
    return null;
  }
}

/// Page-based pagination of the products and content lists.
class PageMeta {
  const PageMeta({
    required this.count,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final int count;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasMore => page < totalPages;
}
