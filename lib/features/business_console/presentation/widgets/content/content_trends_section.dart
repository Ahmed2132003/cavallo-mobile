/// Part BI-04: daily trends of one content item (internal numbers only):
/// views, interactions (likes + comments + saves + in-app shares) and the
/// engagement rate.
///
/// A day where any part of the sum is null (no rollup) is a GAP, never 0.
library;

import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_context.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/analytics_content.dart';
import '../products/product_trend_chart.dart';

enum ContentTrendMetric { views, interactions, engagementRate }

class ContentTrendsSection extends StatefulWidget {
  const ContentTrendsSection({super.key, required this.trend});

  final List<ContentTrendPoint> trend;

  @override
  State<ContentTrendsSection> createState() => _ContentTrendsSectionState();
}

class _ContentTrendsSectionState extends State<ContentTrendsSection> {
  ContentTrendMetric _metric = ContentTrendMetric.views;

  double? _interactions(ContentTrendPoint p) {
    final int? likes = p.likes;
    final int? comments = p.comments;
    final int? saves = p.saves;
    final int? shares = p.inAppShares;
    if (likes == null || comments == null || saves == null || shares == null) {
      return null;
    }
    return (likes + comments + saves + shares).toDouble();
  }

  List<double?> _values() {
    switch (_metric) {
      case ContentTrendMetric.views:
        return <double?>[for (final p in widget.trend) p.views?.toDouble()];
      case ContentTrendMetric.interactions:
        return <double?>[for (final p in widget.trend) _interactions(p)];
      case ContentTrendMetric.engagementRate:
        return <double?>[
          for (final p in widget.trend)
            p.engagementRate == null ? null : p.engagementRate! * 100,
        ];
    }
  }

  String _label(ContentTrendMetric metric) {
    final l10n = context.l10n;
    return switch (metric) {
      ContentTrendMetric.views => l10n.analyticsProdMetricViews,
      ContentTrendMetric.interactions => l10n.analyticsContentTrendInteractions,
      ContentTrendMetric.engagementRate =>
        l10n.analyticsContentMetricEngagementRate,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final List<double?> values = _values();
    final bool hasAny = values.any((double? v) => v != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<ContentTrendMetric>(
            key: const Key('analytics-content-trend-metric'),
            showSelectedIcon: false,
            segments: <ButtonSegment<ContentTrendMetric>>[
              for (final ContentTrendMetric metric in ContentTrendMetric.values)
                ButtonSegment<ContentTrendMetric>(
                  value: metric,
                  label: Text(_label(metric), maxLines: 1),
                ),
            ],
            selected: <ContentTrendMetric>{_metric},
            onSelectionChanged:
                (Set<ContentTrendMetric> next) =>
                    setState(() => _metric = next.first),
          ),
        ),
        const SizedBox(height: 12),
        if (!hasAny)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l10n.analyticsProdTrendNoData,
                key: const Key('analytics-content-trend-empty'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ),
          )
        else
          ProductTrendChart(
            key: const Key('analytics-content-trend-chart'),
            semanticsLabel: _label(_metric),
            dates: <DateTime>[for (final p in widget.trend) p.date],
            values: values,
          ),
      ],
    );
  }
}
