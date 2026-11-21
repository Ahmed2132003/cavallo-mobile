/// Part BI-04: a daily trend line for one metric of one product.
///
/// A null value is NOT drawn as 0: it becomes a gap in the line (`FlSpot
/// .nullSpot`), because null means "no rollup for that day".
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

class ProductTrendChart extends StatelessWidget {
  const ProductTrendChart({
    super.key,
    required this.semanticsLabel,
    required this.dates,
    required this.values,
    this.color,
  }) : assert(dates.length == values.length);

  final String semanticsLabel;
  final List<DateTime> dates;
  final List<double?> values;
  final Color? color;

  static List<FlSpot> spotsFor(List<double?> values) {
    return <FlSpot>[
      for (int i = 0; i < values.length; i++)
        if (values[i] == null)
          FlSpot.nullSpot
        else
          FlSpot(i.toDouble(), values[i]!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final Color lineColor = color ?? colors.brand;
    final List<FlSpot> spots = spotsFor(values);

    final double span =
        values.length <= 1 ? 1.0 : (values.length - 1).toDouble();
    final double xInterval = (span / 4).ceil().clamp(1, 1 << 20).toDouble();
    final double maxValue = values.fold<double>(
      0,
      (double max, double? v) => v != null && v > max ? v : max,
    );
    final double yStep = maxValue <= 4 ? 1.0 : (maxValue / 4).ceilToDouble();
    final double maxY = yStep * 4;

    final TextStyle? labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.textSecondary,
    );

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: span,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: yStep,
                getDrawingHorizontalLine:
                    (double value) =>
                        FlLine(color: colors.outline, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: yStep,
                    getTitlesWidget:
                        (double value, TitleMeta meta) =>
                            Text(value.round().toString(), style: labelStyle),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: xInterval,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final int index = value.round();
                      if (index < 0 || index >= dates.length) {
                        return const SizedBox.shrink();
                      }
                      final DateTime date = dates[index];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${date.day}/${date.month}',
                          style: labelStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: <LineChartBarData>[
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  barWidth: 3,
                  color: lineColor,
                  dotData: FlDotData(show: spots.length <= 14),
                  belowBarData: BarAreaData(
                    show: true,
                    color: lineColor.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
