/// Part BI-04: the Overview tab. ONE overview request feeds the KPI cards,
/// their comparison with the previous period, and the funnel.
///
/// * Missing numbers (views not available) show a dash, never 0.
/// * Comparisons come from the backend's `previous_period.deltas`; with no
///   `previous_period` every card says "no previous data".
/// * Sales and AOV are listed per currency and have no comparison (the
///   backend sends no delta for them): a dash.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/formatters.dart';
import '../../../../../core/l10n/l10n_context.dart';
import '../../../domain/analytics_overview.dart';
import '../../providers/analytics_dashboard_providers.dart';
import '../../providers/analytics_refresh.dart';
import '../analytics_common_widgets.dart';
import '../analytics_format.dart';
import '../analytics_freshness.dart';
import '../analytics_funnel_card.dart';
import '../analytics_kpi_card.dart';

class AnalyticsOverviewSection extends ConsumerWidget {
  const AnalyticsOverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AnalyticsOverview> value = ref.watch(
      analyticsOverviewProvider,
    );
    return AnalyticsAsyncSection<AnalyticsOverview>(
      value: value,
      onRefresh:
          () => refreshAnalytics(
            ref,
            waitFor: () => ref.read(analyticsOverviewProvider.future),
          ),
      onRetry:
          () => retryAnalytics(
            ref,
            () => ref.invalidate(analyticsOverviewProvider),
          ),
      builder: _children,
    );
  }

  static List<Widget> _children(
    BuildContext context,
    AnalyticsOverview overview,
  ) {
    final l10n = context.l10n;
    final AppFormatters fmt = AppFormatters.of(context);
    final OverviewMetrics m = overview.metrics;

    Widget kpi(
      String keySuffix,
      String label,
      IconData icon,
      int? value,
      String deltaKey,
    ) {
      return AnalyticsKpiCard(
        key: ValueKey<String>('bi-kpi-$keySuffix'),
        label: label,
        icon: icon,
        values: <String>[analyticsCount(fmt, value)],
        footer: AnalyticsComparisonLine(
          MetricComparison.forMetric(overview, deltaKey),
        ),
      );
    }

    return <Widget>[
      AnalyticsFreshness(
        dataUpdatedAt: overview.dataUpdatedAt,
        ordersDataUpdatedAt: overview.ordersDataUpdatedAt,
        coverage: overview.coverage,
      ),
      Text(
        l10n.biComparedWithPrevious,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      AnalyticsSectionHeading(l10n.biGroupProducts),
      AnalyticsKpiGrid(
        children: <Widget>[
          kpi(
            'product-views',
            l10n.biKpiProductViews,
            Icons.visibility_outlined,
            m.productViews,
            OverviewMetricKeys.productViews,
          ),
          kpi(
            'product-unique-views',
            l10n.biKpiProductUniqueViews,
            Icons.people_outline,
            m.productUniqueViews,
            OverviewMetricKeys.productUniqueViews,
          ),
          kpi(
            'interests',
            l10n.biKpiInterests,
            Icons.touch_app_outlined,
            m.interests,
            OverviewMetricKeys.interests,
          ),
        ],
      ),
      AnalyticsSectionHeading(l10n.biGroupOrders),
      AnalyticsKpiGrid(
        children: <Widget>[
          kpi(
            'orders',
            l10n.biKpiOrders,
            Icons.receipt_long_outlined,
            m.orders,
            OverviewMetricKeys.orders,
          ),
          kpi(
            'confirmed',
            l10n.biKpiConfirmed,
            Icons.check_circle_outline,
            m.confirmedOrders,
            OverviewMetricKeys.confirmedOrders,
          ),
          kpi(
            'completed',
            l10n.biKpiCompleted,
            Icons.task_alt,
            m.completedOrders,
            OverviewMetricKeys.completedOrders,
          ),
          AnalyticsKpiCard(
            key: const ValueKey<String>('bi-kpi-sales'),
            label: l10n.biKpiSales,
            icon: Icons.payments_outlined,
            values: analyticsMoneyLines(fmt, m.sales),
            footer: const AnalyticsComparisonLine.unavailable(),
          ),
          AnalyticsKpiCard(
            key: const ValueKey<String>('bi-kpi-aov'),
            label: l10n.biKpiAov,
            icon: Icons.shopping_basket_outlined,
            values: analyticsMoneyLines(fmt, m.sales, aov: true),
            footer: const AnalyticsComparisonLine.unavailable(),
          ),
        ],
      ),
      AnalyticsSectionHeading(l10n.biGroupContent),
      AnalyticsKpiGrid(
        children: <Widget>[
          kpi(
            'content-views',
            l10n.biKpiContentViews,
            Icons.play_circle_outline,
            m.contentViews,
            OverviewMetricKeys.contentViews,
          ),
          kpi(
            'likes',
            l10n.biKpiLikes,
            Icons.favorite_border,
            m.likes,
            OverviewMetricKeys.likes,
          ),
          kpi(
            'comments',
            l10n.biKpiComments,
            Icons.chat_bubble_outline,
            m.comments,
            OverviewMetricKeys.comments,
          ),
          kpi(
            'saves',
            l10n.biKpiSaves,
            Icons.bookmark_border,
            m.saves,
            OverviewMetricKeys.saves,
          ),
          kpi(
            'shares',
            l10n.biKpiShares,
            Icons.share_outlined,
            m.inAppShares,
            OverviewMetricKeys.inAppShares,
          ),
        ],
      ),
      const SizedBox(height: 24),
      AnalyticsFunnelCard(
        key: const ValueKey<String>('bi-funnel'),
        funnel: overview.funnel,
      ),
    ];
  }
}
