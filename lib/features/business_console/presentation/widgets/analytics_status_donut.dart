/// Part BI-04: orders by status as a donut with a legend.
///
/// The slices use the backend's counts as they are. Statuses with 0 orders
/// have no slice but stay in the legend (label + icon + count), so the legend
/// is complete and never depends on colour alone.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/formatters.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/analytics_orders_summary.dart';
import 'analytics_common_widgets.dart';
import 'analytics_order_status.dart';

class AnalyticsStatusDonut extends StatelessWidget {
  const AnalyticsStatusDonut({
    super.key,
    required this.counts,
    required this.semanticsLabel,
  });

  final List<OrderStatusCount> counts;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final AppFormatters formatters = AppFormatters.of(context);

    int total = 0;
    for (final OrderStatusCount item in counts) {
      total += item.orders;
    }

    final List<PieChartSectionData> sections = <PieChartSectionData>[
      for (final OrderStatusCount item in counts)
        if (item.orders > 0)
          PieChartSectionData(
            value: item.orders.toDouble(),
            color: analyticsStatusColor(colors, item.status),
            radius: 26,
            showTitle: false,
          ),
    ];

    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.biOrdersByStatusTitle,
            style: text.titleSmall?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            label: semanticsLabel,
            child: ExcludeSemantics(
              child: SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 54,
                        sections: sections,
                        pieTouchData: PieTouchData(enabled: false),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          formatters.compactCount(total),
                          style: text.headlineSmall?.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          l10n.biOrdersTotal,
                          style: text.labelSmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: <Widget>[
              for (final OrderStatusCount item in counts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      analyticsStatusIcon(item.status),
                      size: 16,
                      color: analyticsStatusColor(colors, item.status),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${analyticsStatusLabel(context, item.status)}: '
                      '${formatters.compactCount(item.orders)}',
                      style: text.labelMedium,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
