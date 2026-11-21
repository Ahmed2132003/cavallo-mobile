/// Part BI-04: KPI card, comparison line and the two-column grid.
///
/// The comparison line only DISPLAYS the backend's `change_pct`
/// ([MetricComparison]); it never computes a percentage. A card without a
/// delta in the contract (sales, AOV) uses
/// [AnalyticsComparisonLine.unavailable], which shows a dash.
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/analytics_overview.dart';
import 'analytics_format.dart';

class AnalyticsKpiCard extends StatelessWidget {
  const AnalyticsKpiCard({
    super.key,
    required this.label,
    required this.icon,
    required this.values,
    this.footer,
  });

  final String label;
  final IconData icon;

  /// One line per value (one per currency for money). Already formatted.
  final List<String> values;

  /// Usually an [AnalyticsComparisonLine]; null for plain counters.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final Widget? foot = footer;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: colors.brandText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: text.labelMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final String value in values)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  maxLines: 1,
                  style: text.headlineSmall?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            if (foot != null) ...<Widget>[const SizedBox(height: 6), foot],
          ],
        ),
      ),
    );
  }
}

class AnalyticsComparisonLine extends StatelessWidget {
  const AnalyticsComparisonLine(this.comparison, {super.key});

  /// No comparison exists for this metric in the contract: shows a dash.
  const AnalyticsComparisonLine.unavailable({super.key}) : comparison = null;

  final MetricComparison? comparison;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextStyle? base = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: colors.textSecondary);
    final MetricComparison? value = comparison;

    if (value == null) {
      return Text(kAnalyticsDash, style: base);
    }

    switch (value.kind) {
      case ComparisonKind.noPreviousData:
        return Text(context.l10n.biNoPreviousData, style: base);
      case ComparisonKind.up:
        return _directional(
          Icons.arrow_upward,
          colors.successText,
          analyticsSignedPercent(value.fraction!),
          base,
        );
      case ComparisonKind.down:
        return _directional(
          Icons.arrow_downward,
          colors.dangerText,
          analyticsSignedPercent(value.fraction!),
          base,
        );
      case ComparisonKind.unchanged:
        return _directional(
          Icons.remove,
          colors.textSecondary,
          analyticsSignedPercent(value.fraction!),
          base,
        );
    }
  }

  Widget _directional(
    IconData icon,
    Color color,
    String text,
    TextStyle? base,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: base?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Two cards per row, wrapping; each card keeps its natural height.
class AnalyticsKpiGrid extends StatelessWidget {
  const AnalyticsKpiGrid({super.key, required this.children});

  final List<Widget> children;

  static const double _spacing = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = (constraints.maxWidth - _spacing) / 2;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
