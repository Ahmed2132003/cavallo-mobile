/// Part BI-04: external platform numbers of ONE content item.
///
/// Shows ONLY what the API returned, grouped per platform, each metric with a
/// Manual / Synced badge, its source and its last update. A Manual number is
/// never presented as live. Missing platforms and metrics are simply absent
/// (there is no external "engagement" or "reach" metric in the contract).
library;

import 'package:flutter/material.dart';

import '../../../../../core/l10n/formatters.dart';
import '../../../../../core/l10n/l10n_context.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/analytics_content.dart';

String externalPlatformLabel(AppLocalizations l10n, String platform) {
  return switch (platform) {
    'instagram' => l10n.analyticsExternalPlatformInstagram,
    'facebook' => l10n.analyticsExternalPlatformFacebook,
    'tiktok' => l10n.analyticsExternalPlatformTiktok,
    _ => platform,
  };
}

String externalMetricLabel(AppLocalizations l10n, String metricType) {
  return switch (metricType) {
    'views' => l10n.analyticsExternalMetricViews,
    'likes' => l10n.analyticsExternalMetricLikes,
    'shares' => l10n.analyticsExternalMetricShares,
    'saves' => l10n.analyticsExternalMetricSaves,
    _ => metricType,
  };
}

class ExternalSourceBadge extends StatelessWidget {
  const ExternalSourceBadge({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final bool synced = source == 'synced';
    final bool manual = source == 'manual';
    final Color background =
        synced
            ? colors.successSubtle
            : manual
            ? colors.warningSubtle
            : colors.surfaceVariant;
    final Color foreground =
        synced
            ? colors.successText
            : manual
            ? colors.warningText
            : colors.textSecondary;
    final String label =
        synced
            ? l10n.analyticsExternalBadgeSynced
            : manual
            ? l10n.analyticsExternalBadgeManual
            : source;
    return Container(
      key: Key('analytics-external-badge-$source'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            synced ? Icons.sync : Icons.edit_note,
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class ExternalMetricsPanel extends StatelessWidget {
  const ExternalMetricsPanel({
    super.key,
    required this.metrics,
    required this.onEdit,
  });

  final List<ExternalMetric> metrics;

  /// Opens the manual entry form. Null hides the button.
  final VoidCallback? onEdit;

  static const List<String> _platformOrder = <String>[
    'instagram',
    'facebook',
    'tiktok',
  ];

  List<String> _platforms() {
    final Set<String> present = <String>{for (final m in metrics) m.platform};
    return <String>[
      for (final String p in _platformOrder)
        if (present.contains(p)) p,
      for (final String p in present)
        if (!_platformOrder.contains(p)) p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final AppFormatters formatters = AppFormatters.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (metrics.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.analyticsExternalEmpty,
              key: const Key('analytics-external-empty'),
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
        for (final String platform in _platforms()) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              externalPlatformLabel(l10n, platform),
              key: Key('analytics-external-platform-$platform'),
              style: text.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final ExternalMetric metric in metrics.where(
            (ExternalMetric m) => m.platform == platform,
          ))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${externalMetricLabel(l10n, metric.metricType)}: '
                          '${metric.value}',
                          style: text.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          metric.source == 'synced'
                              ? l10n.analyticsExternalSourceSynced
                              : l10n.analyticsExternalSourceManual,
                          style: text.labelSmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        if (metric.externalReference.trim().isNotEmpty)
                          Text(
                            l10n.analyticsExternalReference(
                              metric.externalReference,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        Text(
                          l10n.analyticsExternalLastUpdated(
                            (metric.lastUpdated == null ? '—' : formatters.absoluteDateTime(metric.lastUpdated!)),
                          ),
                          style: text.labelSmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExternalSourceBadge(source: metric.source),
                ],
              ),
            ),
        ],
        if (onEdit != null) ...<Widget>[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('analytics-external-edit'),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.analyticsExternalAddUpdate),
          ),
        ],
      ],
    );
  }
}
