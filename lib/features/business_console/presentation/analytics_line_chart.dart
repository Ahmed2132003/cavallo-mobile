import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../domain/daily_stats_entity.dart';

/// Part P-085 scope: one single-metric line chart over the rows the
/// backend returned.
///
/// * **No zero-fill (E3).** One point per returned row. The X position is
///   the real calendar offset from the first row, so a missing day shows
///   up as a visible gap in the line, not as a fabricated 0.
/// * **Y starts at 0** and always uses whole-number ticks (these are
///   counts).
/// * **Readable X axis.** At most ~5 date labels (`d/M`), whatever the
///   period, so 30 days never crowd.
/// * **A single row** is drawn as one visible dot.
///
/// [rows] must be sorted ascending by date (the data layer guarantees it).
class AnalyticsLineChart extends StatelessWidget {
  const AnalyticsLineChart({
    super.key,
    required this.title,
    required this.semanticsLabel,
    required this.rows,
    required this.valueOf,
    this.color,
  });

  /// Heading shown above the chart.
  final String title;

  /// Text summary read by screen readers instead of the drawing, e.g.
  /// "New followers: 14 total over 7 days".
  final String semanticsLabel;

  final List<DailyStats> rows;

  /// Picks the single metric this chart plots from a row.
  final int Function(DailyStats row) valueOf;

  final Color? color;

  /// Whole days between the calendar dates of [a] and [b], DST-safe.
  static int dayOffset(DateTime a, DateTime b) {
    final first = DateTime.utc(a.year, a.month, a.day);
    final second = DateTime.utc(b.year, b.month, b.day);
    return second.difference(first).inDays;
  }

  /// The plotted points: X = day offset from the first row, Y = metric.
  static List<FlSpot> spotsFor(
    List<DailyStats> rows,
    int Function(DailyStats row) valueOf,
  ) {
    if (rows.isEmpty) return const [];
    final first = rows.first.date;
    return [
      for (final row in rows)
        FlSpot(dayOffset(first, row.date).toDouble(), valueOf(row).toDouble()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = color ?? theme.colorScheme.primary;
    final spots = spotsFor(rows, valueOf);

    final span = spots.isEmpty ? 0.0 : spots.last.x;
    final maxX = span == 0 ? 1.0 : span;
    final xInterval = (span / 4).ceil().clamp(1, 1 << 20).toDouble();

    final maxValue = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);
    final yInterval = maxValue <= 4 ? 1.0 : (maxValue / 4).ceilToDouble();
    final maxY = yInterval * 4;

    final labelStyle = theme.textTheme.labelSmall;

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: maxX,
                      minY: 0,
                      maxY: maxY,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: yInterval,
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            interval: yInterval,
                            getTitlesWidget:
                                (value, meta) => Text(
                                  value.round().toString(),
                                  style: labelStyle,
                                ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: xInterval,
                            getTitlesWidget: (value, meta) {
                              if (rows.isEmpty || value > span + 0.001) {
                                return const SizedBox.shrink();
                              }
                              final date = DateTime.utc(
                                rows.first.date.year,
                                rows.first.date.month,
                                rows.first.date.day,
                              ).add(Duration(days: value.round()));
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
                      lineBarsData: [
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
