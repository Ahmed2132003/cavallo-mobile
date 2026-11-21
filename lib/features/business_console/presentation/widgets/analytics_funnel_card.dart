/// Part BI-04: the visual funnel Views -> Interests -> Orders -> Confirmed ->
/// Completed.
///
/// Counts, conversion rates and the overall rate are the backend's values
/// exactly as sent: nothing is recomputed from counts. The only derived
/// number is the "drop" label, which is the complement of the backend's rate
/// (1 - rate) and is shown only when that rate is between 0 and 1.
///
/// The bar widths are a visual proportion of each stage's count against the
/// largest count; a stage whose count is null (views not available) shows a
/// dash and no bar. Views are UNIQUE views while the other stages are
/// DISTINCT customers, which the card states in one line.
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/formatters.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/analytics_common.dart';
import 'analytics_common_widgets.dart';
import 'analytics_format.dart';

class AnalyticsFunnelCard extends StatelessWidget {
  const AnalyticsFunnelCard({super.key, required this.funnel});

  final Funnel funnel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final AppFormatters formatters = AppFormatters.of(context);

    int maxCount = 0;
    for (final FunnelStage stage in funnel.stages) {
      final int? count = stage.count;
      if (count != null && count > maxCount) maxCount = count;
    }

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < funnel.stages.length; i++) {
      final FunnelStage stage = funnel.stages[i];
      if (i > 0) {
        rows.add(
          _ConversionRow(
            rate: _rateBetween(funnel.stages[i - 1].key, stage.key),
          ),
        );
      }
      rows.add(
        _StageRow(
          label: _stageLabel(context, stage.key),
          count: stage.count,
          maxCount: maxCount,
          formatters: formatters,
        ),
      );
    }

    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.biFunnelTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.biFunnelUnitsNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ...rows,
          const SizedBox(height: 12),
          Text(
            l10n.biFunnelOverall(analyticsPercent(funnel.overallRate)),
            key: const ValueKey<String>('bi-funnel-overall'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }

  /// The backend conversion for `from -> to`; null when it has none or it is
  /// null.
  double? _rateBetween(String from, String to) {
    for (final FunnelConversion conversion in funnel.conversions) {
      if (conversion.from == from && conversion.to == to) {
        return conversion.rate;
      }
    }
    return null;
  }

  static String _stageLabel(BuildContext context, String key) {
    final l10n = context.l10n;
    return switch (key) {
      'views' => l10n.biFunnelViews,
      'interests' => l10n.biFunnelInterests,
      'orders' => l10n.biFunnelOrders,
      'confirmed' => l10n.biFunnelConfirmed,
      'completed' => l10n.biFunnelCompleted,
      _ => key,
    };
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.formatters,
  });

  final String label;
  final int? count;
  final int maxCount;
  final AppFormatters formatters;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final int? value = count;
    final double factor =
        (value == null || maxCount == 0) ? 0 : value / maxCount;
    final String countText = analyticsCount(formatters, value);

    return Semantics(
      container: true,
      label: '$label $countText',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(label, style: text.bodyMedium)),
                Text(
                  countText,
                  style: text.titleSmall?.copyWith(color: colors.textPrimary),
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
                    widthFactor: factor,
                    child: Container(color: colors.brand),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversionRow extends StatelessWidget {
  const _ConversionRow({required this.rate});

  final double? rate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final TextStyle? style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: colors.textSecondary);
    final double? value = rate;
    final bool showDrop = value != null && value >= 0 && value <= 1;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 0, 6),
      child: Row(
        children: <Widget>[
          Icon(Icons.south, size: 14, color: colors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 12,
              children: <Widget>[
                Text(
                  l10n.biFunnelConversion(analyticsPercent(value)),
                  style: style,
                ),
                if (showDrop)
                  Text(
                    l10n.biFunnelDrop(analyticsPercent(1 - value)),
                    style: style,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
