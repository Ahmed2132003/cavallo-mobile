/// Part BI-04: Riverpod wiring of the dashboard sections.
///
/// ### What every provider here guarantees
/// * The business id comes from `businessProfileProvider` (never guessed). No
///   profile is an ERROR (`AnalyticsBusinessUnavailableException`), not an
///   empty dashboard.
/// * It watches [analyticsPeriodProvider] and [analyticsRefreshEpochProvider]
///   and nothing else that changes: a Tab switch triggers NO request.
/// * Lists and overview/orders-summary are NOT autoDispose: they live as long
///   as the session, so coming back to a Tab shows the cached data. Detail
///   screens are autoDispose (they are opened and closed).
/// * `retry: null` (same reason as `analyticsStatsProvider`): Riverpod 3
///   would otherwise retry a failed provider silently and keep the screen
///   loading instead of showing the error with a Retry button.
///
/// ### Pagination
/// The lists are PAGE based. [analyticsProductsPageProvider] and
/// [analyticsContentPageProvider] load ONE page per key; a screen shows pages
/// 1..N by watching each. A sort / filter / period change makes the screen
/// start again from page 1.
///
/// ### Refresh from the UI
/// ```dart
/// ref.read(analyticsPeriodProvider.notifier).reresolve();
/// ref.read(analyticsRefreshEpochProvider.notifier).bump();
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../business_profile/presentation/business_profile_provider.dart';
import '../../data/business_analytics_repository.dart';
import '../../domain/analytics_content.dart';
import '../../domain/analytics_orders_summary.dart';
import '../../domain/analytics_overview.dart';
import '../../domain/analytics_products.dart';
import '../analytics_provider.dart' show AnalyticsBusinessUnavailableException;
import 'analytics_period_provider.dart';

/// A tiny settable value (sort order, content-type filter).
class AnalyticsValueNotifier<T> extends Notifier<T> {
  AnalyticsValueNotifier(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

final analyticsProductsSortProvider =
    NotifierProvider<AnalyticsValueNotifier<ProductSort>, ProductSort>(
      () => AnalyticsValueNotifier<ProductSort>(ProductSort.mostViewed),
    );

final analyticsContentTypeProvider = NotifierProvider<
  AnalyticsValueNotifier<ContentTypeFilter>,
  ContentTypeFilter
>(() => AnalyticsValueNotifier<ContentTypeFilter>(ContentTypeFilter.all));

final analyticsContentSortProvider =
    NotifierProvider<AnalyticsValueNotifier<ContentSort>, ContentSort>(
      () => AnalyticsValueNotifier<ContentSort>(ContentSort.mostViewed),
    );

/// The signed-in Business account's own id.
final analyticsBusinessIdProvider = FutureProvider<int>((ref) async {
  final profile = await ref.watch(businessProfileProvider.future);
  if (profile == null) {
    throw const AnalyticsBusinessUnavailableException();
  }
  return profile.id;
}, retry: (retryCount, error) => null);

final analyticsOverviewProvider = FutureProvider<AnalyticsOverview>((
  ref,
) async {
  ref.watch(analyticsRefreshEpochProvider);
  final period = ref.watch(analyticsPeriodProvider);
  final repository = ref.watch(businessAnalyticsRepositoryProvider);
  final businessId = await ref.watch(analyticsBusinessIdProvider.future);
  return repository.fetchOverview(businessId: businessId, period: period);
}, retry: (retryCount, error) => null);

final analyticsOrdersSummaryProvider = FutureProvider<OrdersSummary>((
  ref,
) async {
  ref.watch(analyticsRefreshEpochProvider);
  final period = ref.watch(analyticsPeriodProvider);
  final repository = ref.watch(businessAnalyticsRepositoryProvider);
  final businessId = await ref.watch(analyticsBusinessIdProvider.future);
  return repository.fetchOrdersSummary(businessId: businessId, period: period);
}, retry: (retryCount, error) => null);

/// Key of one products page.
typedef ProductsQuery = ({ProductSort sort, int page});

final analyticsProductsPageProvider =
    FutureProvider.family<ProductsPage, ProductsQuery>((ref, query) async {
      ref.watch(analyticsRefreshEpochProvider);
      final period = ref.watch(analyticsPeriodProvider);
      final repository = ref.watch(businessAnalyticsRepositoryProvider);
      final businessId = await ref.watch(analyticsBusinessIdProvider.future);
      return repository.fetchProducts(
        businessId: businessId,
        period: period,
        sort: query.sort,
        page: query.page,
      );
    }, retry: (retryCount, error) => null);

/// Key of one content page.
typedef ContentQuery = ({ContentTypeFilter type, ContentSort sort, int page});

final analyticsContentPageProvider =
    FutureProvider.family<ContentPage, ContentQuery>((ref, query) async {
      ref.watch(analyticsRefreshEpochProvider);
      final period = ref.watch(analyticsPeriodProvider);
      final repository = ref.watch(businessAnalyticsRepositoryProvider);
      final businessId = await ref.watch(analyticsBusinessIdProvider.future);
      return repository.fetchContent(
        businessId: businessId,
        period: period,
        type: query.type,
        sort: query.sort,
        page: query.page,
      );
    }, retry: (retryCount, error) => null);

final analyticsProductDetailProvider = FutureProvider.autoDispose
    .family<ProductAnalyticsDetail, int>((ref, productId) async {
      ref.watch(analyticsRefreshEpochProvider);
      final period = ref.watch(analyticsPeriodProvider);
      final repository = ref.watch(businessAnalyticsRepositoryProvider);
      final businessId = await ref.watch(analyticsBusinessIdProvider.future);
      return repository.fetchProductDetail(
        businessId: businessId,
        productId: productId,
        period: period,
      );
    }, retry: (retryCount, error) => null);

/// Key of one content item: `type` is "post" or "reel".
typedef ContentTarget = ({String type, int id});

final analyticsContentDetailProvider = FutureProvider.autoDispose
    .family<ContentDetail, ContentTarget>((ref, target) async {
      ref.watch(analyticsRefreshEpochProvider);
      final period = ref.watch(analyticsPeriodProvider);
      final repository = ref.watch(businessAnalyticsRepositoryProvider);
      final businessId = await ref.watch(analyticsBusinessIdProvider.future);
      return repository.fetchContentDetail(
        businessId: businessId,
        period: period,
        contentType: target.type,
        contentId: target.id,
      );
    }, retry: (retryCount, error) => null);

/// The latest manual/synced external numbers of one content item (used by the
/// manual-entry form to show what is stored after a save).
final analyticsExternalMetricsProvider = FutureProvider.autoDispose
    .family<ExternalMetricsResponse, ContentTarget>((ref, target) async {
      ref.watch(analyticsRefreshEpochProvider);
      final repository = ref.watch(businessAnalyticsRepositoryProvider);
      final businessId = await ref.watch(analyticsBusinessIdProvider.future);
      return repository.fetchExternalMetrics(
        businessId: businessId,
        contentType: target.type,
        contentId: target.id,
      );
    }, retry: (retryCount, error) => null);
