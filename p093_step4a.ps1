# p093_step4a.ps1  --  run from D:\Cavallo\social_commerce_app  (branch part-083)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path .\pubspec.yaml) -or -not (Test-Path .\lib\features\business_console\domain\daily_stats_entity.dart)) {
    throw 'Run this script from D:\Cavallo\social_commerce_app (pubspec.yaml / business_console not found).'
}
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'part-083') {
    throw "Current branch is '$branch' but the P-085 analytics code lives on 'part-083'. Run: git checkout part-083"
}
$entText = [IO.File]::ReadAllText((Join-Path (Get-Location).Path 'lib\features\business_console\domain\daily_stats_entity.dart'))
if (-not $entText.Contains('required this.newRatingsCount')) {
    throw 'STEP 3 is not applied (the entity has no P-093 fields). Apply p093_step3a.ps1 first.'
}

$utf8 = New-Object System.Text.UTF8Encoding($false)

function ConvertTo-Eol([string]$s, [string]$eol) {
    $lf = $s -replace "`r?`n", "`n"
    if ($eol -eq 'CRLF') { return $lf -replace "`n", "`r`n" }
    return $lf
}

# Replaces a WHOLE file with the content below. Refuses to run if the file
# has local uncommitted changes (so nothing of yours is overwritten).
function Write-WholeFile {
    param([string]$Path, [string]$Content)
    git diff --quiet -- $Path
    if ($LASTEXITCODE -ne 0) {
        throw "$Path has uncommitted local changes. Commit or stash them first."
    }
    $full = Join-Path (Get-Location).Path $Path
    [IO.File]::WriteAllText($full, (ConvertTo-Eol $Content 'CRLF'), $utf8)
    Write-Host "WROTE: $Path"
}

Write-WholeFile -Path 'lib\features\business_console\presentation\analytics_line_chart.dart' -Content @'
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../domain/daily_stats_entity.dart';

/// Part P-085 scope: one single-metric line chart over the rows the
/// backend returned. P-093 generalises it so the same widget also draws the
/// average-rating trend.
///
/// * **No zero-fill (E3).** One point per returned row. The X position is
///   the real calendar offset from the first row, so a missing day shows
///   up as a visible gap in the line, not as a fabricated 0.
/// * **Y starts at 0.** By default the top follows the data and ticks are
///   whole numbers (counts). A caller can pin the top with [fixedMaxY] and
///   the tick spacing with [yInterval] (the rating trend uses 5 and 1).
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
    this.fixedMaxY,
    this.yInterval,
  });

  /// Heading shown above the chart.
  final String title;

  /// Text summary read by screen readers instead of the drawing, e.g.
  /// "New followers: 14 total over 7 days".
  final String semanticsLabel;

  final List<DailyStats> rows;

  /// Picks the single metric this chart plots from a row (a count or a
  /// decimal such as a rating).
  final num Function(DailyStats row) valueOf;

  final Color? color;

  /// Pins the top of the Y axis (e.g. 5 for a 1-5 star rating). When null
  /// the top is derived from the data.
  final double? fixedMaxY;

  /// Pins the Y tick spacing. Only used together with [fixedMaxY]; when
  /// null it defaults to 1.
  final double? yInterval;

  /// Whole days between the calendar dates of [a] and [b], DST-safe.
  static int dayOffset(DateTime a, DateTime b) {
    final first = DateTime.utc(a.year, a.month, a.day);
    final second = DateTime.utc(b.year, b.month, b.day);
    return second.difference(first).inDays;
  }

  /// The plotted points: X = day offset from the first row, Y = metric.
  static List<FlSpot> spotsFor(
    List<DailyStats> rows,
    num Function(DailyStats row) valueOf,
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

    final pinnedMax = fixedMaxY;
    final maxValue = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);
    final double yStep;
    final double maxY;
    if (pinnedMax != null) {
      yStep = yInterval ?? 1.0;
      maxY = pinnedMax;
    } else {
      yStep = maxValue <= 4 ? 1.0 : (maxValue / 4).ceilToDouble();
      maxY = yStep * 4;
    }

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
                        horizontalInterval: yStep,
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            interval: yStep,
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
'@

Write-WholeFile -Path 'lib\features\business_console\presentation\analytics_summary.dart' -Content @'
import '../domain/daily_stats_entity.dart';

/// Part P-085 scope: pure (Flutter-free) helpers that turn the rows the
/// backend returned into the numbers the Analytics screen shows.
///
/// Decision E3: these helpers only ever look at the rows they are given.
/// A day the backend returned no row for is NOT counted as a zero here -
/// the rollup may simply not have run for it, so a zero would be an
/// unconfirmed claim.
class AnalyticsTotals {
  const AnalyticsTotals({
    required this.newFollowers,
    required this.likesReceived,
    required this.commentsReceived,
    required this.storyViews,
  });

  /// Sum of `new_followers` over the returned rows.
  final int newFollowers;

  /// Sum of `total_likes_received` over the returned rows.
  final int likesReceived;

  /// Sum of `total_comments_received` over the returned rows.
  final int commentsReceived;

  /// Sum of `total_story_views` over the returned rows.
  final int storyViews;

  @override
  bool operator ==(Object other) =>
      other is AnalyticsTotals &&
      other.newFollowers == newFollowers &&
      other.likesReceived == likesReceived &&
      other.commentsReceived == commentsReceived &&
      other.storyViews == storyViews;

  @override
  int get hashCode =>
      Object.hash(newFollowers, likesReceived, commentsReceived, storyViews);

  @override
  String toString() =>
      'AnalyticsTotals(newFollowers: $newFollowers, likesReceived: '
      '$likesReceived, commentsReceived: $commentsReceived, '
      'storyViews: $storyViews)';
}

/// Sums the four tracked metrics across [rows]. An empty list sums to
/// all zeros (the screen shows its empty state instead of these).
AnalyticsTotals sumDailyStats(List<DailyStats> rows) {
  var newFollowers = 0;
  var likes = 0;
  var comments = 0;
  var storyViews = 0;
  for (final row in rows) {
    newFollowers += row.newFollowers;
    likes += row.totalLikesReceived;
    comments += row.totalCommentsReceived;
    storyViews += row.totalStoryViews;
  }
  return AnalyticsTotals(
    newFollowers: newFollowers,
    likesReceived: likes,
    commentsReceived: comments,
    storyViews: storyViews,
  );
}

/// How many distinct calendar days [rows] covers - the "X" in
/// "Days with data: X of N". Duplicated dates count once.
int daysWithData(List<DailyStats> rows) {
  final days = <(int, int, int)>{
    for (final row in rows) (row.date.year, row.date.month, row.date.day),
  };
  return days.length;
}

/// Part P-093: the rating numbers the Analytics screen shows.
///
/// * [newRatings] is the sum of `new_ratings_count` over the returned rows
///   (rows only, like every other total here).
/// * [latestAverage] is the most recent row's rating snapshot that is above
///   zero, or null when no returned row has one. The backend stores 0 for
///   "not rated yet" (a real average is never below 1), so 0 is never shown
///   as a rating.
class RatingSummary {
  const RatingSummary({
    required this.newRatings,
    required this.latestAverage,
    required this.latestAverageDate,
  });

  final int newRatings;
  final double? latestAverage;
  final DateTime? latestAverageDate;
}

/// Sums new ratings and finds the latest real rating snapshot in [rows].
/// Does not rely on [rows] being sorted.
RatingSummary summarizeRatings(List<DailyStats> rows) {
  var newRatings = 0;
  DailyStats? latestRated;
  for (final row in rows) {
    newRatings += row.newRatingsCount;
    if (row.averageRatingSnapshot > 0 &&
        (latestRated == null || row.date.isAfter(latestRated.date))) {
      latestRated = row;
    }
  }
  return RatingSummary(
    newRatings: newRatings,
    latestAverage: latestRated?.averageRatingSnapshot,
    latestAverageDate: latestRated?.date,
  );
}

/// The rows that carry a real rating snapshot (above zero), in their
/// original order. These are the only rows the rating trend plots: a 0
/// snapshot means "not rated yet", never a rating of zero.
List<DailyStats> ratedRows(List<DailyStats> rows) => [
  for (final row in rows)
    if (row.averageRatingSnapshot > 0) row,
];

/// Part P-093: the three catalog-size snapshots of one row, with the date
/// they were recorded for.
class CatalogSnapshot {
  const CatalogSnapshot({
    required this.asOf,
    required this.activeProducts,
    required this.publishedPosts,
    required this.publishedReels,
  });

  final DateTime asOf;
  final int activeProducts;
  final int publishedPosts;
  final int publishedReels;
}

/// The catalog snapshot of the most recent row in [rows], or null for an
/// empty list. These are totals as of the rollup run, so they are read from
/// ONE row (the latest) and never summed across days. Does not rely on
/// [rows] being sorted.
CatalogSnapshot? latestCatalogSnapshot(List<DailyStats> rows) {
  if (rows.isEmpty) return null;
  var latest = rows.first;
  for (final row in rows) {
    if (row.date.isAfter(latest.date)) latest = row;
  }
  return CatalogSnapshot(
    asOf: latest.date,
    activeProducts: latest.activeProductsCount,
    publishedPosts: latest.publishedPostsCount,
    publishedReels: latest.publishedReelsCount,
  );
}
'@

Write-WholeFile -Path 'lib\features\business_console\presentation\analytics_screen.dart' -Content @'
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
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
      appBar: AppBar(title: const Text('Analytics')),
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
          message: _loadErrorMessage(statsAsync.error),
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
            message:
                'No activity has been recorded for the last $days days yet.',
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
        'Days with data: $withData of $days',
        key: const ValueKey('analytics-days-with-data'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      Text(
        'Days are counted in UTC. Days without a recorded row are not '
        'drawn as zero.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      AnalyticsLineChart(
        key: const ValueKey('analytics-chart-new-followers'),
        title: 'New followers by day',
        semanticsLabel:
            'New followers: ${totals.newFollowers} total over $days days',
        rows: rows,
        valueOf: (row) => row.newFollowers,
      ),
      const SizedBox(height: 16),
      AnalyticsLineChart(
        key: const ValueKey('analytics-chart-total-likes'),
        title: 'Likes received by day',
        semanticsLabel:
            'Likes received: ${totals.likesReceived} total over $days days',
        rows: rows,
        valueOf: (row) => row.totalLikesReceived,
        color: Theme.of(context).colorScheme.tertiary,
      ),
      const SizedBox(height: 24),
      const _SectionHeading('Ratings'),
      const SizedBox(height: 8),
      _RatingCards(summary: ratings),
      const SizedBox(height: 12),
      if (rated.isEmpty)
        Text(
          'No rating has been recorded yet, so there is no rating trend '
          'to draw.',
          key: const ValueKey('analytics-rating-empty'),
          style: Theme.of(context).textTheme.bodySmall,
        )
      else ...[
        AnalyticsLineChart(
          key: const ValueKey('analytics-chart-rating-trend'),
          title: 'Average rating by day',
          semanticsLabel:
              'Average rating: latest '
              '${ratings.latestAverage?.toStringAsFixed(2)} over $days days',
          rows: rated,
          valueOf: (row) => row.averageRatingSnapshot,
          fixedMaxY: 5,
          yInterval: 1,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 4),
        Text(
          'Each point is the average rating stored when that day was rolled '
          'up. Days before the first rating are not drawn.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      if (catalog != null) ...[
        const SizedBox(height: 24),
        const _SectionHeading('Catalog size'),
        const SizedBox(height: 4),
        Text(
          'As of ${catalog.asOf.day}/${catalog.asOf.month} (UTC). These are '
          'totals recorded by the daily rollup, not daily changes.',
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
String _loadErrorMessage(Object? error) {
  return switch (error) {
    DioException(error: final ApiFailure failure) => failure.message,
    _ => 'Could not load your analytics.',
  };
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: 7,
          label: Text('7 days', key: ValueKey('analytics-range-7')),
        ),
        ButtonSegment(
          value: 14,
          label: Text('14 days', key: ValueKey('analytics-range-14')),
        ),
        ButtonSegment(
          value: 30,
          label: Text('30 days', key: ValueKey('analytics-range-30')),
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TotalCard(
                key: const ValueKey('analytics-total-new-followers'),
                label: 'New followers',
                value: '${totals.newFollowers}',
                icon: Icons.person_add_alt_1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TotalCard(
                key: const ValueKey('analytics-total-likes-received'),
                label: 'Likes received',
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
                label: 'Comments received',
                value: '${totals.commentsReceived}',
                icon: Icons.chat_bubble_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TotalCard(
                key: const ValueKey('analytics-total-story-views'),
                label: 'Story views',
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
    return Row(
      children: [
        Expanded(
          child: _TotalCard(
            key: const ValueKey('analytics-total-new-ratings'),
            label: 'New ratings',
            value: '${summary.newRatings}',
            icon: Icons.star_border,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TotalCard(
            key: const ValueKey('analytics-rating-latest'),
            label: 'Average rating',
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
    return Row(
      children: [
        Expanded(
          child: _TotalCard(
            key: const ValueKey('analytics-catalog-active-products'),
            label: 'Active products',
            value: '${catalog.activeProducts}',
            icon: Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TotalCard(
            key: const ValueKey('analytics-catalog-published-posts'),
            label: 'Published posts',
            value: '${catalog.publishedPosts}',
            icon: Icons.article_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TotalCard(
            key: const ValueKey('analytics-catalog-published-reels'),
            label: 'Published reels',
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
            Icon(icon, size: 20, color: theme.colorScheme.primary),
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
            label: 'Retry',
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
'@

Write-Host ''
Write-Host 'P-093 STEP4A script finished.'