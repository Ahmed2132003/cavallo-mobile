/// Part BI-04: the "Products" section of the analytics dashboard.
///
/// * `AutomaticKeepAliveClientMixin` + a non-autoDispose provider: switching
///   tabs neither rebuilds the tab nor re-requests the data.
/// * Pull-to-refresh invalidates the list (and the image/price catalog).
/// * Page-based pagination: the next page loads near the end of the list and
///   through a visible "Load more" button.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/l10n/formatters.dart';
import '../../../../../core/l10n/l10n_context.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_shimmer_box.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/error_state_widget.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../routing/route_names.dart';
import '../../../../products/presentation/product_public_providers.dart';
import '../../analytics_provider.dart'
    show AnalyticsBusinessUnavailableException;
import '../../providers/analytics_products_providers.dart';
import 'product_analytics_card.dart';
import 'product_analytics_format.dart';
import 'product_coverage_notice.dart';
import 'products_ordering_bar.dart';

class AnalyticsProductsTab extends ConsumerStatefulWidget {
  const AnalyticsProductsTab({super.key, this.onOpenProduct});

  /// Test seam. By default a tap pushes the product analytics route.
  final void Function(int productId)? onOpenProduct;

  @override
  ConsumerState<AnalyticsProductsTab> createState() =>
      _AnalyticsProductsTabState();
}

class _AnalyticsProductsTabState extends ConsumerState<AnalyticsProductsTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    final ScrollPosition position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(ref.read(productsListProvider.notifier).loadMore());
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(businessProductsProvider);
    ref.invalidate(analyticsProductCatalogProvider);
    ref.invalidate(productsListProvider);
    try {
      await ref.read(productsListProvider.future);
    } on Object {
      // The error state of the provider is what the user sees.
    }
  }

  void _open(int productId) {
    final void Function(int productId)? override = widget.onOpenProduct;
    if (override != null) {
      override(productId);
      return;
    }
    context.pushNamed(
      RouteNames.businessAnalyticsProduct,
      pathParameters: <String, String>{RouteNames.idParam: '$productId'},
    );
  }

  String _errorText(AppLocalizations l10n, Object error) {
    return error is AnalyticsBusinessUnavailableException
        ? l10n.analyticsProdNoBusiness
        : l10n.analyticsProdLoadError;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    // Keeps the image/price catalog alive while this tab is alive.
    ref.watch(analyticsProductCatalogProvider);
    final AsyncValue<ProductsListState> async = ref.watch(productsListProvider);
    return async.when(
      loading: () => const ProductsListSkeleton(),
      error:
          (Object error, StackTrace stackTrace) => ErrorStateWidget(
            message: _errorText(l10n, error),
            onRetry: () => ref.invalidate(productsListProvider),
          ),
      data: (ProductsListState state) => _buildData(context, state),
    );
  }

  Widget _buildData(BuildContext context, ProductsListState state) {
    final l10n = context.l10n;
    final AppFormatters formatters = AppFormatters.of(context);
    final AppColors colors = context.appColors;
    final DateTime? updatedAt = state.dataUpdatedAt;
    final String updated =
        updatedAt == null
            ? kProductMissing
            : formatters.absoluteDateTime(updatedAt);

    return Column(
      children: <Widget>[
        const ProductsOrderingBar(),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.analyticsProdUpdatedAt(updated),
              key: const Key('analytics-products-updated-at'),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
        ProductCoverageNotice(coverage: state.coverage),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child:
                state.items.isEmpty
                    ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: <Widget>[
                        SizedBox(
                          height: 320,
                          child: EmptyStateWidget(
                            message: l10n.analyticsProdEmpty,
                            icon: Icons.inventory_2_outlined,
                          ),
                        ),
                      ],
                    )
                    : ListView.builder(
                      key: const Key('analytics-products-list'),
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: state.items.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        if (index == state.items.length) {
                          return _buildFooter(context, state);
                        }
                        final row = state.items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ProductAnalyticsCard(
                            row: row,
                            onTap: () => _open(row.productId),
                          ),
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, ProductsListState state) {
    final l10n = context.l10n;
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.loadMoreFailed) {
      return Center(
        child: TextButton(
          key: const Key('analytics-products-load-more-retry'),
          onPressed:
              () =>
                  unawaited(ref.read(productsListProvider.notifier).loadMore()),
          child: Text(l10n.commonRetry),
        ),
      );
    }
    if (state.hasMore) {
      return Center(
        child: TextButton(
          key: const Key('analytics-products-load-more'),
          onPressed:
              () =>
                  unawaited(ref.read(productsListProvider.notifier).loadMore()),
          child: Text(l10n.analyticsProdLoadMore),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

/// Skeleton shown while the first page loads.
class ProductsListSkeleton extends StatelessWidget {
  const ProductsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return ListView.separated(
      key: const Key('analytics-products-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 4,
      separatorBuilder:
          (BuildContext context, int index) => const SizedBox(height: 12),
      itemBuilder:
          (BuildContext context, int index) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outline),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AppShimmerBox(width: 72, height: 72, borderRadius: 8),
                    SizedBox(width: 12),
                    Expanded(child: AppShimmerBox(height: 48)),
                  ],
                ),
                SizedBox(height: 12),
                AppShimmerBox(height: 56),
              ],
            ),
          ),
    );
  }
}
