/// Part BI-04: a multi-series line chart over daily rows (orders over time,
/// revenue over time, and in Part 3 the product trends).
///
/// * One value per date; X = real calendar offset from the first date.
/// * A null value is a GAP in the line (`FlSpot.nullSpot`), never a 0: days
///   the rollup has not covered stay visibly empty.
/// * Y starts at 0 with whole-number ticks; labels come from [formatY] so the
///   caller picks compact counts or money.
/// * Colours come from `context.appColors`; meaning never rides on colour
///   alone: every series has a legend entry with its name and each extra
///   series gets its own dash pattern.
/// * At most ~5 date labels, whatever the period, so 90 or 366 days never
///   crowd a small screen.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'analytics_format.dart';

class AnalyticsSeries {
  const AnalyticsSeries({
    required this.name,
    required this.values,
    this.color,
    this.dashArray,
  });

  final String name;

  /// One entry per date of the chart; null = no data for that day.
  final List<double?> values;

  /// Null = a palette colour by position.
  final Color? color;

  /// Null = solid line.
  final List<int>? dashArray;
}

class AnalyticsSeriesLineChart extends StatelessWidget {
  AnalyticsSeriesLineChart({
    super.key,
    required this.title,
    required this.semanticsLabel,
    required this.dates,
    required this.series,
    required this.formatY,
  }) : assert(
         series.every((AnalyticsSeries s) => s.values.length == dates.length),
         'every series needs exactly one value per date',
       );

  final String title;

  /// Text read by screen readers instead of the drawing.
  final String semanticsLabel;

  /// Calendar dates, ascending (UTC midnights).
  final List<DateTime> dates;
  final List<AnalyticsSeries> series;

  /// Y axis label of a value (compact count or money).
  final String Function(double value) formatY;

  static int _dayOffset(DateTime a, DateTime b) {
    return DateTime.utc(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  }

  static List<FlSpot> _spots(List<DateTime> dates, List<double?> values) {
    final List<FlSpot> spots = <FlSpot>[];
    for (int i = 0; i < dates.length; i++) {
      final double? value = values[i];
      if (value == null) {
        spots.add(FlSpot.nullSpot);
      } else {
        spots.add(FlSpot(_dayOffset(dates.first, dates[i]).toDouble(), value));
      }
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final List<Color> palette = <Color>[
      colors.brand,
      colors.warningText,
      colors.successText,
      colors.dangerText,
    ];

    final DateTime first = dates.first;
    final double span = _dayOffset(first, dates.last).toDouble();
    final double maxX = span == 0 ? 1.0 : span;
    final double xInterval = (span / 4).ceil().clamp(1, 1 << 20).toDouble();

    double maxValue = 0;
    for (final AnalyticsSeries s in series) {
      for (final double? v in s.values) {
        if (v != null && v > maxValue) maxValue = v;
      }
    }
    final double yStep = maxValue <= 4 ? 1.0 : (maxValue / 4).ceilToDouble();
    final double maxY = yStep * 4;

    final TextStyle? labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.textSecondary,
    );

    final List<LineChartBarData> bars = <LineChartBarData>[];
    final List<Color> lineColors = <Color>[];
    for (int i = 0; i < series.length; i++) {
      final AnalyticsSeries s = series[i];
      final Color lineColor = s.color ?? palette[i % palette.length];
      lineColors.add(lineColor);
      bars.add(
        LineChartBarData(
          spots: _spots(dates, s.values),
          isCurved: false,
          barWidth: 3,
          color: lineColor,
          dashArray: s.dashArray,
          dotData: FlDotData(show: dates.length <= 14),
          belowBarData: BarAreaData(
            show: series.length == 1,
            color: lineColor.withValues(alpha: 0.12),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 4,
                    bottom: 8,
                  ),
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (series.length > 1)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 4,
                      bottom: 12,
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: <Widget>[
                        for (int i = 0; i < series.length; i++)
                          _LegendItem(
                            color: lineColors[i],
                            name: series[i].name,
                            dashed: series[i].dashArray != null,
                          ),
                      ],
                    ),
                  ),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: maxX,
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
                            reservedSize: 40,
                            interval: yStep,
                            getTitlesWidget:
                                (double value, TitleMeta meta) =>
                                    Text(formatY(value), style: labelStyle),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: xInterval,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value > span + 0.001) {
                                return const SizedBox.shrink();
                              }
                              final DateTime date = DateTime.utc(
                                first.year,
                                first.month,
                                first.day,
                              ).add(Duration(days: value.round()));
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  analyticsDateLabel(date),
                                  style: labelStyle,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: bars,
                    ),
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

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.name,
    required this.dashed,
  });

  final Color color;
  final String name;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 22,
          height: 4,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < (dashed ? 3 : 1); i++) ...<Widget>[
                Expanded(child: Container(color: color)),
                if (dashed && i < 2) const SizedBox(width: 2),
              ],
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          name,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}
