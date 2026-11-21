/// Part BI-04: the Trends block of the product detail: views / interests /
/// orders / sales, one chart at a time.
///
/// `sales` in a trend row is a MAP currency -> string, so the sales chart is
/// drawn for ONE currency at a time (chips when there are several); amounts
/// of different currencies are never added together.
library;

import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_context.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/analytics_products.dart';
import 'product_trend_chart.dart';

enum ProductTrendMetric { views, interests, orders, sales }

class ProductTrendsSection extends StatefulWidget {
  const ProductTrendsSection({
    super.key,
    required this.trend,
    required this.currencies,
  });

  final List<ProductTrendPoint> trend;

  /// Currencies that appear in the product's sales, sorted.
  final List<String> currencies;

  @override
  State<ProductTrendsSection> createState() => _ProductTrendsSectionState();
}

class _ProductTrendsSectionState extends State<ProductTrendsSection> {
  ProductTrendMetric _metric = ProductTrendMetric.views;
  String? _currency;

  String? get _activeCurrency {
    if (widget.currencies.isEmpty) {
      return null;
    }
    final String? chosen = _currency;
    if (chosen != null && widget.currencies.contains(chosen)) {
      return chosen;
    }
    return widget.currencies.first;
  }

  double _salesOf(ProductTrendPoint point, String? currency) {
    if (currency == null) {
      return 0;
    }
    final String? raw = point.sales[currency];
    if (raw == null) {
      return 0;
    }
    return double.tryParse(raw) ?? 0;
  }

  List<double?> _values() {
    switch (_metric) {
      case ProductTrendMetric.views:
        return <double?>[for (final p in widget.trend) p.views?.toDouble()];
      case ProductTrendMetric.interests:
        return <double?>[for (final p in widget.trend) p.interests?.toDouble()];
      case ProductTrendMetric.orders:
        return <double?>[for (final p in widget.trend) p.orders.toDouble()];
      case ProductTrendMetric.sales:
        final String? currency = _activeCurrency;
        return <double?>[for (final p in widget.trend) _salesOf(p, currency)];
    }
  }

  String _label(ProductTrendMetric metric) {
    final l10n = context.l10n;
    return switch (metric) {
      ProductTrendMetric.views => l10n.analyticsProdMetricViews,
      ProductTrendMetric.interests => l10n.analyticsProdMetricInterests,
      ProductTrendMetric.orders => l10n.analyticsProdMetricOrders,
      ProductTrendMetric.sales => l10n.analyticsProdMetricSales,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final List<double?> values = _values();
    final bool hasAny = values.any((double? v) => v != null);
    final String? currency = _activeCurrency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<ProductTrendMetric>(
            key: const Key('analytics-product-trend-metric'),
            showSelectedIcon: false,
            segments: <ButtonSegment<ProductTrendMetric>>[
              for (final ProductTrendMetric metric in ProductTrendMetric.values)
                ButtonSegment<ProductTrendMetric>(
                  value: metric,
                  label: Text(_label(metric), maxLines: 1),
                ),
            ],
            selected: <ProductTrendMetric>{_metric},
            onSelectionChanged:
                (Set<ProductTrendMetric> next) =>
                    setState(() => _metric = next.first),
          ),
        ),
        if (_metric == ProductTrendMetric.sales &&
            widget.currencies.length > 1) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final String code in widget.currencies)
                ChoiceChip(
                  key: Key('analytics-product-trend-currency-$code'),
                  label: Text(code),
                  selected: code == currency,
                  onSelected: (bool _) => setState(() => _currency = code),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (!hasAny)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l10n.analyticsProdTrendNoData,
                key: const Key('analytics-product-trend-empty'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ),
          )
        else
          ProductTrendChart(
            key: const Key('analytics-product-trend-chart'),
            semanticsLabel: _label(_metric),
            dates: <DateTime>[for (final p in widget.trend) p.date],
            values: values,
          ),
      ],
    );
  }
}
