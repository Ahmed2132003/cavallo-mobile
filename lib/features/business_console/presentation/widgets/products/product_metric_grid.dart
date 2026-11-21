/// Part BI-04: a small grid of "value over label" cells (3 per row).
library;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

class ProductMetric {
  const ProductMetric(this.label, this.value);

  final String label;
  final String value;
}

class ProductMetricGrid extends StatelessWidget {
  const ProductMetricGrid({super.key, required this.metrics, this.columns = 3});

  final List<ProductMetric> metrics;
  final int columns;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cellWidth =
            (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: <Widget>[
            for (final ProductMetric metric in metrics)
              SizedBox(width: cellWidth, child: _MetricCell(metric: metric)),
          ],
        );
      },
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.metric});

  final ProductMetric metric;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '${metric.value} ${metric.label}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            metric.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
