import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../routing/route_names.dart';
import '../../content/presentation/own_content_provider.dart';
import '../../products/presentation/own_products_provider.dart';
import '../../stories/domain/own_story_entity.dart';
import '../../stories/presentation/own_stories_provider.dart';
import '../../stories/presentation/story_list_screen.dart'
    show storyListClockProvider;
import 'analytics_provider.dart';
import 'analytics_summary.dart';

/// Part P-115 (STEP 5): the Business Console dashboard - one compact card per
/// console area (products, posts/reels, stories, analytics) with a clear count.
///
/// READ-ONLY: it only watches the providers the four tabs already use and never
/// calls a notifier method. Each card shows a skeleton while loading and a dash
/// when its own data failed, so one failing area never hides the others.
/// Tapping a card jumps to that tab (named routes of the P-083 shell contract;
/// nothing happens when there is no router, e.g. in a plain widget test).
class ConsoleDashboardCards extends ConsumerWidget {
  const ConsoleDashboardCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    final AsyncValue<int> products = ref
        .watch(ownProductsProvider)
        .whenData((items) => items.length);
    final AsyncValue<int> content = ref
        .watch(ownContentProvider)
        .whenData((items) => items.length);
    final DateTime now = ref.watch(storyListClockProvider)();
    final AsyncValue<int> stories = ref
        .watch(ownStoriesProvider)
        .whenData(
          (items) =>
              items.where((story) {
                final status = story.displayStatus(now);
                return status == OwnStoryDisplayStatus.published ||
                    status == OwnStoryDisplayStatus.pending;
              }).length,
        );
    final int days = ref.watch(analyticsRangeDaysProvider);
    final AsyncValue<int> followers = ref
        .watch(analyticsStatsProvider)
        .whenData((rows) => sumDailyStats(rows).newFollowers);

    final List<Widget> cards = <Widget>[
      _DashboardCard(
        key: const Key('console-dash-products'),
        icon: Icons.inventory_2_outlined,
        label: l10n.consoleNavProducts,
        value: products,
        routeName: RouteNames.productList,
      ),
      _DashboardCard(
        key: const Key('console-dash-content'),
        icon: Icons.dynamic_feed_outlined,
        label: l10n.consoleNavContent,
        value: content,
        routeName: RouteNames.contentList,
      ),
      _DashboardCard(
        key: const Key('console-dash-stories'),
        icon: Icons.auto_stories_outlined,
        label: l10n.consoleDashStories,
        value: stories,
        routeName: RouteNames.storyList,
      ),
      _DashboardCard(
        key: const Key('console-dash-analytics'),
        icon: Icons.insights_outlined,
        label: l10n.consoleDashFollowers,
        caption: l10n.consoleDashRange(days),
        value: followers,
        routeName: RouteNames.businessAnalytics,
      ),
    ];

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: cards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => cards[index],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.routeName,
    this.caption,
  });

  final IconData icon;
  final String label;
  final AsyncValue<int> value;
  final String routeName;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final AppFormatters formatters = AppFormatters(l10n);
    final String? captionText = caption;

    final TextStyle? valueStyle = text.titleLarge?.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w700,
    );
    final Widget valueWidget = switch (value) {
      AsyncData(value: final int count) => Text(
        formatters.compactCount(count),
        style: valueStyle,
      ),
      AsyncError() => Text(l10n.consoleDashValueUnavailable, style: valueStyle),
      _ => const AppShimmerBox(width: 40, height: 22),
    };

    return SizedBox(
      width: 148,
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outline),
        ),
        child: InkWell(
          onTap: () => GoRouter.maybeOf(context)?.goNamed(routeName),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(icon, size: 18, color: colors.brandText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                valueWidget,
                if (captionText != null)
                  Text(
                    captionText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: colors.textSecondary,
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
