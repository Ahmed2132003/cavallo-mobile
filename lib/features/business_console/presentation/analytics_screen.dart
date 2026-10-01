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
/// Shows ONLY what the backend's daily-rollup endpoint (P-084) actually
/// tracks — new followers, likes received, comments received and story
/// views. Product/profile views are deliberately absent: nothing in this
/// system records them, so showing them would be fabricated data.
///
/// ### Honesty rules (decision E3)
/// * Rows only. A day the backend returned no row for is never shown as
///   0 — the nightly rollup may not have run for it. The screen says
///   "Days with data: X of N" so a gap is visible instead of hidden.
/// * An empty response is an *empty state* ("nothing recorded"), not a
///   screen full of zeros.
/// * The backend counts days in UTC; the screen says so.
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
                value: totals.newFollowers,
                icon: Icons.person_add_alt_1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TotalCard(
                key: const ValueKey('analytics-total-likes-received'),
                label: 'Likes received',
                value: totals.likesReceived,
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
                value: totals.commentsReceived,
                icon: Icons.chat_bubble_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TotalCard(
                key: const ValueKey('analytics-total-story-views'),
                label: 'Story views',
                value: totals.storyViews,
                icon: Icons.visibility_outlined,
              ),
            ),
          ],
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
  final int value;
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
            Text('$value', style: theme.textTheme.headlineSmall),
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
