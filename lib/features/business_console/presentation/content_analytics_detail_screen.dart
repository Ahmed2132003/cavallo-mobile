/// Part BI-04: analytics of ONE post or reel for the shared period.
///
/// Internal (in-app) numbers and external (platform) numbers are two
/// separate blocks with different styling and are never added together.
/// Reach is not shown: the contract says there is no reliable source for it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/cavallo_app_bar.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/analytics_content.dart';
import 'analytics_provider.dart' show AnalyticsBusinessUnavailableException;
import 'providers/analytics_content_providers.dart';
import 'widgets/content/content_analytics_card.dart';
import 'widgets/content/content_filter_bar.dart';
import 'widgets/content/content_trends_section.dart';
import 'widgets/external/external_metric_form_sheet.dart';
import 'widgets/external/external_metrics_panel.dart';
import 'widgets/products/product_analytics_format.dart';
import 'widgets/products/product_coverage_notice.dart';
import 'widgets/products/product_metric_grid.dart';

class ContentAnalyticsDetailScreen extends ConsumerWidget {
  const ContentAnalyticsDetailScreen({
    super.key,
    required this.contentType,
    required this.contentId,
  });

  /// 'post' or 'reel'.
  final String contentType;
  final int contentId;

  (String, int) get _key => (contentType, contentId);

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(contentExternalMetricsProvider(_key));
    ref.invalidate(contentAnalyticsDetailProvider(_key));
    try {
      await ref.read(contentAnalyticsDetailProvider(_key).future);
    } on Object {
      // The error state of the provider is what the user sees.
    }
  }

  String _errorText(AppLocalizations l10n, Object error) {
    return error is AnalyticsBusinessUnavailableException
        ? l10n.analyticsProdNoBusiness
        : l10n.analyticsContentLoadError;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<ContentAnalyticsDetail> async = ref.watch(
      contentAnalyticsDetailProvider(_key),
    );
    return Scaffold(
      appBar: CavalloAppBar(title: Text(contentTypeLabel(l10n, contentType))),
      body: async.when(
        loading: () => const _DetailSkeleton(),
        error:
            (Object error, StackTrace stackTrace) => ErrorStateWidget(
              message: _errorText(l10n, error),
              onRetry:
                  () => ref.invalidate(contentAnalyticsDetailProvider(_key)),
            ),
        data:
            (ContentAnalyticsDetail detail) => RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: _DetailBody(detail: detail),
            ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});

  final ContentAnalyticsDetail detail;

  Future<void> _editExternal(BuildContext context, WidgetRef ref) async {
    final bool? saved = await showExternalMetricSheet(
      context,
      contentType: detail.contentType,
      contentId: detail.contentId,
    );
    if (saved != true) {
      return;
    }
    final (String, int) key = (detail.contentType, detail.contentId);
    ref.invalidate(contentAnalyticsDetailProvider(key));
    ref.invalidate(contentExternalMetricsProvider(key));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.analyticsExternalSaved)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormatters formatters = AppFormatters.of(context);
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final ContentMetrics totals = detail.internal.totals;
    final String? thumb = ref.watch(
      analyticsContentThumbProvider((detail.contentType, detail.contentId)),
    );
    final DateTime? createdAt = detail.createdAt;
    final DateTime? updatedAt = detail.dataUpdatedAt;
    final String caption =
        detail.captionPreview.trim().isEmpty
            ? l10n.analyticsContentNoCaption
            : detail.captionPreview;

    final List<ProductMetric> metrics = <ProductMetric>[
      ProductMetric(
        l10n.analyticsProdMetricViews,
        productCountText(formatters, totals.views),
      ),
      ProductMetric(
        l10n.analyticsProdMetricUniqueViews,
        productCountText(formatters, totals.uniqueViews),
      ),
      ProductMetric(
        l10n.analyticsContentMetricLikes,
        productCountText(formatters, totals.likes),
      ),
      ProductMetric(
        l10n.analyticsContentMetricComments,
        productCountText(formatters, totals.comments),
      ),
      ProductMetric(
        l10n.analyticsProdMetricSaves,
        productCountText(formatters, totals.saves),
      ),
      ProductMetric(
        l10n.analyticsContentMetricInAppShares,
        productCountText(formatters, totals.inAppShares),
      ),
      ProductMetric(
        l10n.analyticsContentMetricEngagementRate,
        productRateText(l10n, totals.engagementRate),
      ),
    ];

    return ListView(
      key: const Key('analytics-content-detail-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        _SurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ContentThumb(
                imageUrl: thumb,
                contentType: detail.contentType,
                size: 80,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${contentTypeLabel(l10n, detail.contentType)}'
                      ' · '
                      '${createdAt == null ? kProductMissing : formatters.absoluteDate(createdAt)}',
                      style: text.labelSmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.analyticsProdUpdatedAt(
                        updatedAt == null
                            ? kProductMissing
                            : formatters.absoluteDateTime(updatedAt),
                      ),
                      key: const Key('analytics-content-detail-updated-at'),
                      style: text.labelSmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ProductCoverageNotice(coverage: detail.coverage),
        ),
        _SectionTitle(l10n.analyticsContentInternalTitle),
        _SurfaceCard(
          key: const Key('analytics-content-internal-block'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ProductMetricGrid(metrics: metrics),
              const SizedBox(height: 8),
              Text(
                l10n.analyticsContentInAppNote,
                style: text.labelSmall?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.analyticsProdTrendsTitle,
                style: text.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ContentTrendsSection(trend: detail.internal.trend),
            ],
          ),
        ),
        _SectionTitle(l10n.analyticsContentExternalTitle),
        Container(
          key: const Key('analytics-content-external-block'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.public, size: 18, color: colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.analyticsContentExternalNote,
                      style: text.labelSmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ExternalMetricsPanel(
                metrics: detail.external.metrics,
                onEdit: () => _editExternal(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: context.appColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: child,
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('analytics-content-detail-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const <Widget>[
        AppShimmerBox(height: 96),
        SizedBox(height: 16),
        AppShimmerBox(height: 160),
        SizedBox(height: 16),
        AppShimmerBox(height: 220),
        SizedBox(height: 16),
        AppShimmerBox(height: 140),
      ],
    );
  }
}
