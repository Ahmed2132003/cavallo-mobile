/// Part BI-04: the Orders & Sales tab (`orders-summary`, computed live).
///
/// * The fixed notice states these are sales the merchant recorded inside
///   Cavallo, not money collected electronically.
/// * Pending and cancelled orders are counted but are never revenue; the
///   definition line says so.
/// * Sales are listed and charted PER CURRENCY (never summed across
///   currencies).
/// * Orders over time, revenue over time (one chart per currency) and the
///   status donut use fl_chart. Top products are horizontal bars grouped by
///   currency, which stay readable on small screens where long product names
///   would not fit under vertical bars.
/// * Zero orders in the period is an empty state, not a screen of zeros.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/formatters.dart';
import '../../../../../core/l10n/l10n_context.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../domain/analytics_common.dart';
import '../../../domain/analytics_orders_summary.dart';
import '../../providers/analytics_dashboard_providers.dart';
import '../../providers/analytics_refresh.dart';
import '../analytics_common_widgets.dart';
import '../analytics_format.dart';
import '../analytics_freshness.dart';
import '../analytics_kpi_card.dart';
import '../analytics_order_status.dart';
import '../analytics_series_line_chart.dart';
import '../analytics_status_donut.dart';

class AnalyticsOrdersSection extends ConsumerWidget {
  const AnalyticsOrdersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OrdersSummary> value = ref.watch(
      analyticsOrdersSummaryProvider,
    );
    return AnalyticsAsyncSection<OrdersSummary>(
      value: value,
      onRefresh:
          () => refreshAnalytics(
            ref,
            waitFor: () => ref.read(analyticsOrdersSummaryProvider.future),
          ),
      onRetry:
          () => retryAnalytics(
            ref,
            () => ref.invalidate(analyticsOrdersSummaryProvider),
          ),
      builder: _children,
    );
  }

  static List<Widget> _children(BuildContext context, OrdersSummary summary) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final AppFormatters fmt = AppFormatters.of(context);
    final int days = summary.period.days;

    final List<Widget> head = <Widget>[
      AnalyticsFreshness(dataUpdatedAt: summary.dataUpdatedAt),
      const SizedBox(height: 8),
      AnalyticsCard(
        key: const ValueKey<String>('bi-sales-disclaimer'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline, size: 20, color: colors.brandText),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.biSalesDisclaimer,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    ];

    if (summary.orders == 0) {
      return <Widget>[
        ...head,
        SizedBox(
          height: 240,
          child: EmptyStateWidget(
            key: const ValueKey<String>('bi-orders-empty'),
            message: l10n.biOrdersEmpty,
            icon: Icons.receipt_long_outlined,
          ),
        ),
      ];
    }

    final List<DateTime> dates = <DateTime>[
      for (final OrdersTrendPoint p in summary.trend) p.date,
    ];

    return <Widget>[
      ...head,
      AnalyticsSectionHeading(l10n.biGroupOrders),
      AnalyticsKpiGrid(
        children: <Widget>[
          AnalyticsKpiCard(
            key: const ValueKey<String>('bi-orders-total-sales'),
            label: l10n.biTotalSales,
            icon: Icons.payments_outlined,
            values: analyticsMoneyLines(fmt, summary.sales),
          ),
          AnalyticsKpiCard(
            key: const ValueKey<String>('bi-orders-aov'),
            label: l10n.biKpiAov,
            icon: Icons.shopping_basket_outlined,
            values: analyticsMoneyLines(fmt, summary.sales, aov: true),
          ),
          AnalyticsKpiCard(
            key: const ValueKey<String>('bi-orders-units'),
            label: l10n.biUnits,
            icon: Icons.inventory_2_outlined,
            values: <String>[analyticsCount(fmt, summary.units)],
          ),
          AnalyticsKpiCard(
            key: const ValueKey<String>('bi-orders-count'),
            label: l10n.biOrdersTotal,
            icon: Icons.receipt_long_outlined,
            values: <String>[analyticsCount(fmt, summary.orders)],
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        l10n.biSalesDefinition,
        key: const ValueKey<String>('bi-sales-definition'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      AnalyticsSectionHeading(l10n.biOrdersByStatusTitle),
      AnalyticsKpiGrid(
        children: <Widget>[
          for (final OrderStatusCount item in summary.byStatus)
            AnalyticsKpiCard(
              key: ValueKey<String>('bi-status-${item.status.name}'),
              label: analyticsStatusLabel(context, item.status),
              icon: analyticsStatusIcon(item.status),
              values: <String>[analyticsCount(fmt, item.orders)],
            ),
        ],
      ),
      const SizedBox(height: 16),
      AnalyticsStatusDonut(
        key: const ValueKey<String>('bi-status-donut'),
        counts: summary.byStatus,
        semanticsLabel: l10n.biChartSemantics(l10n.biOrdersByStatusTitle, days),
      ),
      const SizedBox(height: 16),
      AnalyticsSeriesLineChart(
        key: const ValueKey<String>('bi-chart-orders'),
        title: l10n.biOrdersOverTimeTitle,
        semanticsLabel: l10n.biChartSemantics(l10n.biOrdersOverTimeTitle, days),
        dates: dates,
        series: <AnalyticsSeries>[
          AnalyticsSeries(
            name: l10n.biSeriesOrders,
            values: <double?>[
              for (final OrdersTrendPoint p in summary.trend)
                p.orders.toDouble(),
            ],
          ),
          AnalyticsSeries(
            name: l10n.biSeriesSoldOrders,
            values: <double?>[
              for (final OrdersTrendPoint p in summary.trend)
                p.soldOrders.toDouble(),
            ],
            dashArray: const <int>[8, 4],
          ),
        ],
        formatY: (double v) => fmt.compactCount(v.round()),
      ),
      ..._revenueCharts(context, summary, dates, days, fmt),
      AnalyticsSectionHeading(l10n.biTopProductsTitle),
      _TopProducts(products: summary.topProducts, fmt: fmt),
    ];
  }

  /// One revenue line chart per currency. Trend days come from live orders
  /// (no rollup), so a day without sales is a real 0.
  static List<Widget> _revenueCharts(
    BuildContext context,
    OrdersSummary summary,
    List<DateTime> dates,
    int days,
    AppFormatters fmt,
  ) {
    final l10n = context.l10n;
    final List<String> currencies = <String>[
      for (final SalesEntry s in summary.sales) s.currency,
    ];
    for (final OrdersTrendPoint p in summary.trend) {
      for (final String currency in p.sales.keys) {
        if (!currencies.contains(currency)) currencies.add(currency);
      }
    }

    if (currencies.isEmpty) {
      return <Widget>[
        const SizedBox(height: 16),
        AnalyticsCard(
          key: const ValueKey<String>('bi-revenue-none'),
          child: Text(
            l10n.biNoSalesInPeriod,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ];
    }

    return <Widget>[
      for (final String currency in currencies) ...<Widget>[
        const SizedBox(height: 16),
        AnalyticsSeriesLineChart(
          key: ValueKey<String>('bi-chart-revenue-$currency'),
          title: l10n.biRevenueOverTimeTitle(
            analyticsCurrencyName(context, currency),
          ),
          semanticsLabel: l10n.biChartSemantics(
            l10n.biRevenueOverTimeTitle(
              analyticsCurrencyName(context, currency),
            ),
            days,
          ),
          dates: dates,
          series: <AnalyticsSeries>[
            AnalyticsSeries(
              name: analyticsCurrencyName(context, currency),
              values: <double?>[
                for (final OrdersTrendPoint p in summary.trend)
                  p.sales[currency] == null
                      ? 0.0
                      : analyticsMoneyToDouble(p.sales[currency]!),
              ],
            ),
          ],
          formatY: (double v) => fmt.compactCount(v.round()),
        ),
      ],
    ];
  }
}

/// Top products by sales value, grouped by currency (values of different
/// currencies are never put on one scale).
class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.products, required this.fmt});

  final List<TopProduct> products;
  final AppFormatters fmt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (products.isEmpty) {
      return AnalyticsCard(
        key: const ValueKey<String>('bi-top-products-empty'),
        child: Text(
          l10n.biTopProductsEmpty,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final Map<String, List<TopProduct>> groups = <String, List<TopProduct>>{};
    for (final TopProduct product in products) {
      groups.putIfAbsent(product.currency, () => <TopProduct>[]).add(product);
    }

    return Column(
      key: const ValueKey<String>('bi-top-products'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final MapEntry<String, List<TopProduct>> group in groups.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnalyticsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (groups.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        analyticsCurrencyName(context, group.key),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  _BarRows(items: group.value, fmt: fmt),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BarRows extends StatelessWidget {
  const _BarRows({required this.items, required this.fmt});

  final List<TopProduct> items;
  final AppFormatters fmt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    double maxValue = 0;
    for (final TopProduct item in items) {
      final double value = analyticsMoneyToDouble(item.salesValue);
      if (value > maxValue) maxValue = value;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final TopProduct item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      fmt.price(item.salesValue, item.currency),
                      style: text.titleSmall?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 10,
                    color: colors.surfaceVariant,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor:
                            maxValue == 0
                                ? 0
                                : analyticsMoneyToDouble(item.salesValue) /
                                    maxValue,
                        child: Container(color: colors.brand),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.biTopProductSub(
                    fmt.compactCount(item.soldOrders),
                    fmt.compactCount(item.units),
                  ),
                  style: text.labelSmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
