import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../domain/daily_stats_entity.dart';
import 'analytics_line_chart.dart';
import 'analytics_provider.dart';
import 'analytics_summary.dart';

/// Part P-085 scope: the Business Console's Analytics tab.
///
/// Shows ONLY what the backend's daily-rollup endpoint (P-084, extended by
/// P-093) actually tracks: new followers, likes received, comments received,
/// story views, new ratings, the average-rating snapshot and three catalog
/// size snapshots (active products, published posts, published reels).
/// Product/profile VIEWS are deliberately absent: nothing in this system
/// records them, so showing them would be fabricated data.
///
/// ### Honesty rules (decision E3)
/// * Rows only. A day the backend returned no row for is never shown as
///   0 - the nightly rollup may not have run for it. The screen says
///   "Days with data: X of N" so a gap is visible instead of hidden.
/// * An empty response is an *empty state* ("nothing recorded"), not a
///   screen full of zeros.
/// * The backend counts days in UTC; the screen says so.
/// * (P-093) A rating snapshot of 0 means "not rated yet", so it is never
///   plotted or shown as a rating. Catalog counts are snapshots taken when
///   the rollup ran: the screen shows the LATEST row's values, never a sum.
///
/// Owns its own `AppBar` (decision D1 from P-083: the console shell has
/// none). Pull-to-refresh invalidates [analyticsStatsProvider]; retry
/// does the same.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(analyticsRangeDaysProvider);
    final statsAsync = ref.watch(analyticsStatsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.consoleNavAnalytics)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsStatsProvider);
          try {
            await ref.read(analyticsStatsProvider.future);
          } catch (_) {
            // The error state renders the failure; the pull gesture just
            // needs to finish.
          }
        },
        child: ListView(
          // Always scrollable so pull-to-refresh works on short content
          // and on the loading / error / empty states too.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _RangeSelector(
              selected: days,
              onSelected:
                  (value) => ref
                      .read(analyticsRangeDaysProvider.notifier)
                      .select(value),
            ),
            const SizedBox(height: 16),
            ..._body(context, ref, statsAsync, days),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<DailyStats>> statsAsync,
    int days,
  ) {
    final l10n = context.l10n;
    // A finished failure wins over any stale value; while a retry or a
    // range change is in flight, show loading so the action visibly does
    // something and N never disagrees with the rows shown.
    if (statsAsync.isLoading) {
      return const [
        SizedBox(
          height: 240,
          child: LoadingIndicator(key: ValueKey('analytics-loading')),
        ),
      ];
    }
    if (statsAsync.hasError) {
      return [
        _ErrorView(
          message: _loadErrorMessage(context, statsAsync.error),
          onRetry: () => ref.invalidate(analyticsStatsProvider),
        ),
      ];
    }

    final rows = statsAsync.value ?? const <DailyStats>[];
    if (rows.isEmpty) {
      return [
        SizedBox(
          height: 240,
          child: EmptyStateWidget(
            key: const ValueKey('analytics-empty'),
            message: l10n.analyticsEmpty(days),
            icon: Icons.bar_chart,
          ),
        ),
      ];
    }

    final totals = sumDailyStats(rows);
    final withData = daysWithData(rows);
    final ratings = summarizeRatings(rows);
    final rated = ratedRows(rows);
    final catalog = latestCatalogSnapshot(rows);

    return [
      _TotalsGrid(totals: totals),
      const SizedBox(height: 8),
      Text(
        l10n.analyticsDaysWithData(withData, days),
        key: const ValueKey('analytics-days-with-data'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      Text(l10n.analyticsUtcNote, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      AnalyticsLineChart(
        key: const ValueKey('analytics-chart-new-followers'),
        title: l10n.analyticsChartFollowersTitle,
        semanticsLabel: l10n.analyticsChartFollowersSemantics(
          days,
          totals.newFollowers,
        ),
        rows: rows,
        valueOf: (row) => row.newFollowers,
      ),
      const SizedBox(height: 16),
      AnalyticsLineChart(
        key: const ValueKey('analytics-chart-total-likes'),
        title: l10n.analyticsChartLikesTitle,
        semanticsLabel: l10n.analyticsChartLikesSemantics(
          days,
          totals.likesReceived,
        ),
        rows: rows,
        valueOf: (row) => row.totalLikesReceived,
        color: context.appColors.warningText,
        dashArray: const [8, 4],
      ),
      const SizedBox(height: 24),
      _SectionHeading(l10n.analyticsRatingsHeading),
      const SizedBox(height: 8),
      _RatingCards(summary: ratings),
      const SizedBox(height: 12),
      if (rated.isEmpty)
        Text(
          l10n.analyticsRatingEmpty,
          key: const ValueKey('analytics-rating-empty'),
          style: Theme.of(context).textTheme.bodySmall,
        )
      else ...[
        AnalyticsLineChart(
          key: const ValueKey('analytics-chart-rating-trend'),
          title: l10n.analyticsChartRatingTitle,
          semanticsLabel: l10n.analyticsChartRatingSemantics(
            days,
            ratings.latestAverage?.toStringAsFixed(2) ?? '',
          ),
          rows: rated,
          valueOf: (row) => row.averageRatingSnapshot,
          fixedMaxY: 5,
          yInterval: 1,
          color: context.appColors.successText,
          dashArray: const [2, 4],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.analyticsRatingNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      if (catalog != null) ...[
        const SizedBox(height: 24),
        _SectionHeading(l10n.analyticsCatalogHeading),
        const SizedBox(height: 4),
        Text(
          l10n.analyticsCatalogAsOf(catalog.asOf.day, catalog.asOf.month),
          key: const ValueKey('analytics-catalog-as-of'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _CatalogRow(catalog: catalog),
      ],
    ];
  }
}

/// Maps a load failure to what the business owner should read.
String _loadErrorMessage(BuildContext context, Object? error) {
  return switch (error) {
    DioException(error: final ApiFailure failure) => failure.message,
    _ => context.l10n.analyticsLoadFailed,
  };
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<int>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: 7,
          label: Text(
            l10n.analyticsRangeDays(7),
            key: const ValueKey('analytics-range-7'),
          ),
        ),
        ButtonSegment(
          value: 14,
          label: Text(
            l10n.analyticsRangeDays(14),
            key: const ValueKey('analytics-range-14'),
          ),
        ),
        ButtonSegment(
          value: 30,
          label: Text(
            l10n.analyticsRangeDays(30),
            key: const ValueKey('analytics-range-30'),
          ),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onSelected(values.first),
    );
  }
}

class _TotalsGrid extends StatelessWidget {
  const _TotalsGrid({required this.totals});

  final AnalyticsTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TotalCard(
                key: const ValueKey('analytics-total-new-followers'),
                label: l10n.analyticsNewFollowers,
                value: '${totals.newFollowers}',
                icon: Icons.person_add_alt_1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TotalCard(
                key: const ValueKey('analytics-total-likes-received'),
                label: l10n.analyticsLikesReceived,
                value: '${totals.likesReceived}',
                icon: Icons.favorite_border,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TotalCard(
                key: const ValueKey('analytics-total-comments-received'),
                label: l10n.analyticsCommentsReceived,
                value: '${totals.commentsReceived}',
                icon: Icons.chat_bubble_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TotalCard(
                key: const ValueKey('analytics-total-story-views'),
                label: l10n.analyticsStoryViews,
                value: '${totals.storyViews}',
                icon: Icons.visibility_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

/// P-093: new ratings (sum of the returned rows) beside the latest real
/// average-rating snapshot ("\u2014" when no returned row has one).
class _RatingCards extends StatelessWidget {
  const _RatingCards({required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final latest = summary.latestAverage;
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _TotalCard(
            key: const ValueKey('analytics-total-new-ratings'),
            label: l10n.analyticsNewRatings,
            value: '${summary.newRatings}',
            icon: Icons.star_border,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TotalCard(
            key: const ValueKey('analytics-rating-latest'),
            label: l10n.analyticsAverageRating,
            value: latest == null ? '\u2014' : latest.toStringAsFixed(2),
            icon: Icons.star,
          ),
        ),
      ],
    );
  }
}

/// P-093: the three catalog-size snapshots of the latest row.
class _CatalogRow extends StatelessWidget {
  const _CatalogRow({required this.catalog});

  final CatalogSnapshot catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _TotalCard(
            key: const ValueKey('analytics-catalog-active-products'),
            label: l10n.analyticsActiveProducts,
            value: '${catalog.activeProducts}',
            icon: Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TotalCard(
            key: const ValueKey('analytics-catalog-published-posts'),
            label: l10n.analyticsPublishedPosts,
            value: '${catalog.publishedPosts}',
            icon: Icons.article_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TotalCard(
            key: const ValueKey('analytics-catalog-published-reels'),
            label: l10n.analyticsPublishedReels,
            value: '${catalog.publishedReels}',
            icon: Icons.movie_outlined,
          ),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: context.appColors.brandText),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('analytics-error'),
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          AppButton(
            key: const ValueKey('analytics-retry-button'),
            label: context.l10n.commonRetry,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
