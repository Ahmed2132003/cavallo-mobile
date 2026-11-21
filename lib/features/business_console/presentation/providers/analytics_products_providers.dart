/// Part BI-04 (Products tab): state for the product analytics list, its
/// ordering, the product detail and the product image/price lookup.
///
/// * The list is PAGE based (`page` / `page_size` / `total_pages`).
/// * Ordering keys are exactly the ones in api_contract_BI02.md.
/// * [productsListProvider] is NOT autoDispose, so switching dashboard tabs
///   does not trigger a new request. It rebuilds only when the shared period,
///   the ordering or the business changes, or when it is invalidated.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../business_profile/presentation/business_profile_provider.dart';
import '../../../products/domain/product_entity.dart';
import '../../../products/presentation/product_public_providers.dart';
import '../../data/business_analytics_repository.dart';
import '../../domain/analytics_common.dart';
import '../../domain/analytics_products.dart';
import '../analytics_provider.dart' show AnalyticsBusinessUnavailableException;
import 'analytics_period_provider.dart';

/// Ordering choices. [wire] is the `ordering` query value; a leading `-`
/// means descending. There is no "lowest conversion" key: it is simply
/// `conversion` (ascending). Rows with a null value are always last.
enum ProductsOrdering {
  mostViewed('-views'),
  mostInterested('-interests'),
  mostOrdered('-orders'),
  bestSelling('-sales'),
  highestConversion('-conversion'),
  lowestConversion('conversion');

  const ProductsOrdering(this.wire);

  final String wire;
}

ProductSort _productSortFor(ProductsOrdering ordering) {
  return switch (ordering) {
    ProductsOrdering.mostViewed => ProductSort.mostViewed,
    ProductsOrdering.mostInterested => ProductSort.mostInterested,
    ProductsOrdering.mostOrdered => ProductSort.mostOrdered,
    ProductsOrdering.bestSelling => ProductSort.highestSales,
    ProductsOrdering.highestConversion => ProductSort.highestConversion,
    ProductsOrdering.lowestConversion => ProductSort.lowestConversion,
  };
}

class ProductsOrderingNotifier extends Notifier<ProductsOrdering> {
  @override
  ProductsOrdering build() => ProductsOrdering.mostViewed;

  void select(ProductsOrdering value) {
    if (state != value) {
      state = value;
    }
  }
}

final productsOrderingProvider =
    NotifierProvider<ProductsOrderingNotifier, ProductsOrdering>(
      ProductsOrderingNotifier.new,
    );

class ProductsListState {
  const ProductsListState({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.count,
    required this.coverage,
    required this.dataUpdatedAt,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  factory ProductsListState.fromPage(ProductsPage page) {
    return ProductsListState(
      items: List<ProductAnalyticsRow>.unmodifiable(page.results),
      page: page.meta.page,
      totalPages: page.meta.totalPages,
      count: page.meta.count,
      coverage: page.coverage,
      dataUpdatedAt: page.dataUpdatedAt,
    );
  }

  final List<ProductAnalyticsRow> items;
  final int page;
  final int totalPages;
  final int count;
  final AnalyticsCoverage coverage;
  final DateTime? dataUpdatedAt;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  bool get hasMore => page < totalPages;

  ProductsListState copyWith({
    List<ProductAnalyticsRow>? items,
    int? page,
    int? totalPages,
    int? count,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return ProductsListState(
      items: items ?? this.items,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      count: count ?? this.count,
      coverage: coverage,
      dataUpdatedAt: dataUpdatedAt,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

class ProductsListNotifier extends AsyncNotifier<ProductsListState> {
  static const int pageSize = 20;

  @override
  Future<ProductsListState> build() async {
    final period = ref.watch(analyticsPeriodProvider);
    final ordering = ref.watch(productsOrderingProvider);
    final profile = await ref.watch(businessProfileProvider.future);
    if (profile == null) {
      throw const AnalyticsBusinessUnavailableException();
    }
    final page = await ref
        .watch(businessAnalyticsRepositoryProvider)
        .fetchProducts(
          businessId: profile.id,
          period: period,
          page: 1,
          pageSize: pageSize,
          sort: _productSortFor(ordering),
        );
    return ProductsListState.fromPage(page);
  }

  /// Loads the next page and appends it. A failure keeps the rows already on
  /// screen and only flags [ProductsListState.loadMoreFailed].
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }
    final profile = await ref.read(businessProfileProvider.future);
    if (profile == null) {
      return;
    }

    final loading = current.copyWith(
      isLoadingMore: true,
      loadMoreFailed: false,
    );
    state = AsyncData<ProductsListState>(loading);

    final ProductsPage next;
    try {
      next = await ref
          .read(businessAnalyticsRepositoryProvider)
          .fetchProducts(
            businessId: profile.id,
            period: ref.read(analyticsPeriodProvider),
            page: current.page + 1,
            pageSize: pageSize,
            sort: _productSortFor(ref.read(productsOrderingProvider)),
          );
    } on Object {
      // The list was rebuilt (period or ordering changed) while loading:
      // this result belongs to an older query and is dropped.
      if (identical(state.value, loading)) {
        state = AsyncData<ProductsListState>(
          loading.copyWith(isLoadingMore: false, loadMoreFailed: true),
        );
      }
      return;
    }

    if (!identical(state.value, loading)) {
      return;
    }
    final seen = <int>{for (final row in loading.items) row.productId};
    final merged = <ProductAnalyticsRow>[
      ...loading.items,
      for (final row in next.results)
        if (seen.add(row.productId)) row,
    ];
    state = AsyncData<ProductsListState>(
      loading.copyWith(
        items: List<ProductAnalyticsRow>.unmodifiable(merged),
        page: next.meta.page,
        totalPages: next.meta.totalPages,
        count: next.meta.count,
        isLoadingMore: false,
        loadMoreFailed: false,
      ),
    );
  }
}

/// `retry: null` — same reason as `analyticsStatsProvider`: failures must
/// reach the error state with its Retry button instead of looping silently.
final productsListProvider =
    AsyncNotifierProvider<ProductsListNotifier, ProductsListState>(
      ProductsListNotifier.new,
      retry: (retryCount, error) => null,
    );

/// One product's analytics for the shared period.
final productAnalyticsDetailProvider = FutureProvider.autoDispose
    .family<ProductAnalyticsDetail, int>((ref, productId) async {
      final period = ref.watch(analyticsPeriodProvider);
      final profile = await ref.watch(businessProfileProvider.future);
      if (profile == null) {
        throw const AnalyticsBusinessUnavailableException();
      }
      return ref
          .watch(businessAnalyticsRepositoryProvider)
          .fetchProductDetail(
            businessId: profile.id,
            productId: productId,
            period: period,
          );
    }, retry: (retryCount, error) => null);

/// The merchant's products from the existing products feature, keyed by id.
/// The analytics row has no image and no price, so they come from here. The
/// Products tab watches this provider so it stays alive while the tab lives
/// (one request, not one per card).
///
/// `businessProductsProvider` returns the first page of the catalog only;
/// products missing from it are resolved one by one in
/// [analyticsProductMetaProvider].
final analyticsProductCatalogProvider =
    FutureProvider.autoDispose<Map<int, Product>>((ref) async {
      final profile = await ref.watch(businessProfileProvider.future);
      if (profile == null) {
        return const <int, Product>{};
      }
      final products = await ref.watch(
        businessProductsProvider(profile.id).future,
      );
      return <int, Product>{for (final p in products) p.id: p};
    }, retry: (retryCount, error) => null);

/// Image / name / price of one product, or null when it cannot be resolved
/// (the card then shows a placeholder and "—"; nothing is invented).
final analyticsProductMetaProvider = FutureProvider.autoDispose
    .family<Product?, int>((ref, productId) async {
      try {
        final catalog = await ref.watch(analyticsProductCatalogProvider.future);
        final hit = catalog[productId];
        if (hit != null) {
          return hit;
        }
      } on Object {
        // Catalog failed: fall through to the single-product lookup.
      }
      try {
        return await ref.watch(productPublicDetailProvider(productId).future);
      } on Object {
        return null;
      }
    }, retry: (retryCount, error) => null);
