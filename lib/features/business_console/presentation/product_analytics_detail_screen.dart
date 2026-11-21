/// Part BI-04: analytics of ONE product for the dashboard's shared period.
///
/// Shows totals, sales per currency (never summed), the funnel exactly as the
/// backend returned it, the daily trends and a link to the orders list. The
/// link opens ALL orders: neither the router nor api_contract_BI01.md has a
/// per-product orders filter (it is marked UNVERIFIED there), so the screen
/// says so instead of pretending to filter.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/cavallo_app_bar.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';
import '../../business_profile/presentation/own_business_id_provider.dart';
import '../../products/domain/product_entity.dart';
import '../domain/analytics_products.dart';
import '../domain/analytics_common.dart';
import 'analytics_provider.dart' show AnalyticsBusinessUnavailableException;
import 'providers/analytics_products_providers.dart';
import 'widgets/analytics_funnel_view.dart';
import 'widgets/products/product_analytics_card.dart';
import 'widgets/products/product_analytics_format.dart';
import 'widgets/products/product_coverage_notice.dart';
import 'widgets/products/product_metric_grid.dart';
import 'widgets/products/product_trends_section.dart';

class ProductAnalyticsDetailScreen extends ConsumerWidget {
  const ProductAnalyticsDetailScreen({super.key, required this.productId});

  final int productId;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(productAnalyticsDetailProvider(productId));
    try {
      await ref.read(productAnalyticsDetailProvider(productId).future);
    } on Object {
      // The error state of the provider is what the user sees.
    }
  }

  String _errorText(AppLocalizations l10n, Object error) {
    return error is AnalyticsBusinessUnavailableException
        ? l10n.analyticsProdNoBusiness
        : l10n.analyticsProdLoadError;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<ProductAnalyticsDetail> async = ref.watch(
      productAnalyticsDetailProvider(productId),
    );
    final Product? meta = switch (ref.watch(
      analyticsProductMetaProvider(productId),
    )) {
      AsyncData<Product?>(:final value) => value,
      _ => null,
    };
    final String title = switch (async) {
      AsyncData<ProductAnalyticsDetail>(:final value) => value.name,
      _ => meta?.name ?? l10n.ordersProductFallback(productId),
    };

    return Scaffold(
      appBar: CavalloAppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: async.when(
        loading: () => const _DetailSkeleton(),
        error:
            (Object error, StackTrace stackTrace) => ErrorStateWidget(
              message: _errorText(l10n, error),
              onRetry:
                  () =>
                      ref.invalidate(productAnalyticsDetailProvider(productId)),
            ),
        data:
            (ProductAnalyticsDetail detail) => RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: _DetailBody(detail: detail, meta: meta),
            ),
      ),
    );
  }
}

List<String> _currenciesOf(ProductAnalyticsDetail detail) {
  final Set<String> codes = <String>{
    for (final SalesEntry s in detail.totals.sales) s.currency,
  };
  for (final ProductTrendPoint point in detail.trend) {
    codes.addAll(point.sales.keys);
  }
  return codes.toList()..sort();
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.meta});

  final ProductAnalyticsDetail detail;
  final Product? meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormatters formatters = AppFormatters.of(context);
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final ProductTotals totals = detail.totals;
    final bool isOwner = ref.watch(ownBusinessIdProvider) != null;

    final DateTime? updatedAt = detail.dataUpdatedAt;
    final DateTime? ordersUpdatedAt = detail.ordersDataUpdatedAt;
    final String price =
        meta == null
            ? kProductMissing
            : formatters.price(meta!.price, meta!.currency.toWire());

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
        l10n.analyticsProdMetricInterests,
        productCountText(formatters, totals.interests),
      ),
      ProductMetric(
        l10n.analyticsProdMetricSaves,
        productCountText(formatters, totals.saves),
      ),
      ProductMetric(
        l10n.analyticsProdMetricOrders,
        productCountText(formatters, totals.orders),
      ),
      ProductMetric(
        l10n.analyticsProdMetricSoldOrders,
        productCountText(formatters, totals.soldOrders),
      ),
      ProductMetric(
        l10n.analyticsProdMetricUnits,
        productCountText(formatters, totals.units),
      ),
      ProductMetric(
        l10n.analyticsProdMetricConversion,
        productRateText(l10n, totals.conversion),
      ),
    ];

    return ListView(
      key: const Key('analytics-product-detail-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        _SurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ProductThumb(imageUrl: meta?.imageUrl, size: 80),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      detail.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: text.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    if (!detail.isActive)
                      Text(
                        l10n.analyticsProdInactive,
                        style: text.labelMedium?.copyWith(
                          color: colors.warningText,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.analyticsProdUpdatedAt(
                        updatedAt == null
                            ? kProductMissing
                            : formatters.absoluteDateTime(updatedAt),
                      ),
                      key: const Key('analytics-product-updated-at'),
                      style: text.labelSmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      l10n.analyticsProdOrdersUpdatedAt(
                        ordersUpdatedAt == null
                            ? kProductMissing
                            : formatters.absoluteDateTime(ordersUpdatedAt),
                      ),
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
        _SectionTitle(l10n.analyticsProdTotalsTitle),
        _SurfaceCard(child: ProductMetricGrid(metrics: metrics)),
        _SectionTitle(l10n.analyticsProdSalesTitle),
        if (totals.sales.isEmpty)
          _SurfaceCard(
            child: Text(
              l10n.analyticsProdNoSales,
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          )
        else
          for (final SalesEntry sales in totals.sales)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      formatters.price(sales.salesValue, sales.currency),
                      style: text.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.analyticsProdSalesLine(
                        productCountText(formatters, sales.soldOrders),
                        productCountText(formatters, sales.units),
                      ),
                      style: text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      l10n.analyticsProdLabelValue(
                        l10n.analyticsProdMetricAverageOrderValue,
                        sales.aov == null
                            ? kProductMissing
                            : formatters.price(sales.aov!, sales.currency),
                      ),
                      style: text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 20),
        _SurfaceCard(child: AnalyticsFunnelView(funnel: detail.funnel)),
        _SectionTitle(l10n.analyticsProdTrendsTitle),
        _SurfaceCard(
          child: ProductTrendsSection(
            trend: detail.trend,
            currencies: _currenciesOf(detail),
          ),
        ),
        if (isOwner) ...<Widget>[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('analytics-product-orders-link'),
            onPressed: () => context.goNamed(RouteNames.ordersList),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(l10n.analyticsProdOpenOrders),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.analyticsProdOrdersLinkNote,
            style: text.labelSmall?.copyWith(color: colors.textSecondary),
          ),
        ],
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
  const _SurfaceCard({required this.child});

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
      key: const Key('analytics-product-detail-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const <Widget>[
        AppShimmerBox(height: 96),
        SizedBox(height: 16),
        AppShimmerBox(height: 120),
        SizedBox(height: 16),
        AppShimmerBox(height: 160),
        SizedBox(height: 16),
        AppShimmerBox(height: 220),
      ],
    );
  }
}
