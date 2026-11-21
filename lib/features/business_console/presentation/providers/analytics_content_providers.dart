/// Part BI-04 (Content + External): state for the content analytics list,
/// the content detail, the external metrics and the thumbnail lookup.
///
/// Both lists (Content tab, External tab) are NOT autoDispose, so switching
/// dashboard tabs does not trigger a new request. They rebuild only when the
/// shared period or their own filter changes, or when invalidated.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../business_profile/presentation/business_profile_provider.dart';
import '../../../content/domain/content_item_entity.dart';
import '../../../content/presentation/own_content_provider.dart';
import '../../data/business_analytics_repository.dart';
import '../../domain/analytics_common.dart';
import '../../domain/analytics_content.dart' as analytics_domain;
import '../analytics_provider.dart' show AnalyticsBusinessUnavailableException;
import 'analytics_period_provider.dart';

/// `type` query value of the content list.
enum ContentTypeFilter {
  all('all'),
  post('post'),
  reel('reel');

  const ContentTypeFilter(this.wire);

  final String wire;
}

/// Ordering keys from api_contract_BI02.md (leading `-` = descending).
/// [newest] is used by the External tab only.
enum ContentOrdering {
  mostViewed('-views'),
  mostLiked('-likes'),
  mostSaved('-saves'),
  mostShared('-in_app_shares'),
  highestEngagement('-engagement_rate'),
  newest('-created_at');

  const ContentOrdering(this.wire);

  final String wire;

  /// The five choices the Content tab offers.
  static const List<ContentOrdering> tabChoices = <ContentOrdering>[
    mostViewed,
    mostLiked,
    mostSaved,
    mostShared,
    highestEngagement,
  ];
}

analytics_domain.ContentTypeFilter _domainContentType(String wire) {
  return switch (wire) {
    'all' => analytics_domain.ContentTypeFilter.all,
    'post' => analytics_domain.ContentTypeFilter.post,
    'reel' => analytics_domain.ContentTypeFilter.reel,
    _ => throw ArgumentError.value(wire, 'wire', 'Unknown content type.'),
  };
}

analytics_domain.ContentSort _domainContentSort(String ordering) {
  return switch (ordering) {
    '-views' => analytics_domain.ContentSort.mostViewed,
    '-likes' => analytics_domain.ContentSort.mostLiked,
    '-saves' => analytics_domain.ContentSort.mostSaved,
    '-in_app_shares' => analytics_domain.ContentSort.mostShared,
    '-engagement_rate' => analytics_domain.ContentSort.highestEngagement,
    '-created_at' => analytics_domain.ContentSort.newest,
    _ => throw ArgumentError.value(ordering, 'ordering', 'Unknown content ordering.'),
  };
}

class ContentTypeFilterNotifier extends Notifier<ContentTypeFilter> {
  @override
  ContentTypeFilter build() => ContentTypeFilter.all;

  void select(ContentTypeFilter value) {
    if (state != value) {
      state = value;
    }
  }
}

final contentTypeFilterProvider =
    NotifierProvider<ContentTypeFilterNotifier, ContentTypeFilter>(
      ContentTypeFilterNotifier.new,
    );

class ContentOrderingNotifier extends Notifier<ContentOrdering> {
  @override
  ContentOrdering build() => ContentOrdering.mostViewed;

  void select(ContentOrdering value) {
    if (state != value) {
      state = value;
    }
  }
}

final contentOrderingProvider =
    NotifierProvider<ContentOrderingNotifier, ContentOrdering>(
      ContentOrderingNotifier.new,
    );

class ContentListState {
  const ContentListState({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.count,
    required this.coverage,
    required this.dataUpdatedAt,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  factory ContentListState.fromPage(analytics_domain.ContentPage page) {
    return ContentListState(
      items: List<analytics_domain.ContentAnalyticsRow>.unmodifiable(page.results),
      page: page.meta.page,
      totalPages: page.meta.totalPages,
      count: page.meta.count,
      coverage: page.coverage,
      dataUpdatedAt: page.dataUpdatedAt,
    );
  }

  final List<analytics_domain.ContentAnalyticsRow> items;
  final int page;
  final int totalPages;
  final int count;
  final AnalyticsCoverage coverage;
  final DateTime? dataUpdatedAt;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  bool get hasMore => page < totalPages;

  ContentListState copyWith({
    List<analytics_domain.ContentAnalyticsRow>? items,
    int? page,
    int? totalPages,
    int? count,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return ContentListState(
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

/// Shared paging logic. A subclass only says which `type` / `ordering` it
/// shows: `watch: true` inside build (so a filter change rebuilds the list),
/// `watch: false` inside [loadMore].
abstract class ContentListNotifierBase extends AsyncNotifier<ContentListState> {
  static const int pageSize = 20;

  ({String type, String ordering}) queryOf({required bool watch});

  @override
  Future<ContentListState> build() async {
    final period = ref.watch(analyticsPeriodProvider);
    final query = queryOf(watch: true);
    final profile = await ref.watch(businessProfileProvider.future);
    if (profile == null) {
      throw const AnalyticsBusinessUnavailableException();
    }
    final page = await ref
        .watch(businessAnalyticsRepositoryProvider)
        .fetchContent(
          businessId: profile.id,
          period: period,
          type: _domainContentType(query.type),
          page: 1,
          pageSize: pageSize,
          sort: _domainContentSort(query.ordering),
        );
    return ContentListState.fromPage(page);
  }

  /// Appends the next page. A failure keeps the rows on screen and only sets
  /// [ContentListState.loadMoreFailed].
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }
    final profile = await ref.read(businessProfileProvider.future);
    if (profile == null) {
      return;
    }
    final query = queryOf(watch: false);

    final loading = current.copyWith(
      isLoadingMore: true,
      loadMoreFailed: false,
    );
    state = AsyncData<ContentListState>(loading);

    final analytics_domain.ContentPage next;
    try {
      next = await ref
          .read(businessAnalyticsRepositoryProvider)
          .fetchContent(
            businessId: profile.id,
            period: ref.read(analyticsPeriodProvider),
            type: _domainContentType(query.type),
            page: current.page + 1,
            pageSize: pageSize,
            sort: _domainContentSort(query.ordering),
          );
    } on Object {
      // Rebuilt meanwhile (filter/period changed): drop the stale result.
      if (identical(state.value, loading)) {
        state = AsyncData<ContentListState>(
          loading.copyWith(isLoadingMore: false, loadMoreFailed: true),
        );
      }
      return;
    }

    if (!identical(state.value, loading)) {
      return;
    }
    final seen = <(String, int)>{
      for (final row in loading.items) (row.contentType, row.contentId),
    };
    final merged = <analytics_domain.ContentAnalyticsRow>[
      ...loading.items,
      for (final row in next.results)
        if (seen.add((row.contentType, row.contentId))) row,
    ];
    state = AsyncData<ContentListState>(
      loading.copyWith(
        items: List<analytics_domain.ContentAnalyticsRow>.unmodifiable(merged),
        page: next.meta.page,
        totalPages: next.meta.totalPages,
        count: next.meta.count,
        isLoadingMore: false,
        loadMoreFailed: false,
      ),
    );
  }
}

class ContentTabListNotifier extends ContentListNotifierBase {
  @override
  ({String type, String ordering}) queryOf({required bool watch}) {
    final ContentTypeFilter type =
        watch
            ? ref.watch(contentTypeFilterProvider)
            : ref.read(contentTypeFilterProvider);
    final ContentOrdering ordering =
        watch
            ? ref.watch(contentOrderingProvider)
            : ref.read(contentOrderingProvider);
    return (type: type.wire, ordering: ordering.wire);
  }
}

/// `retry: null`: failures must reach the error state with its Retry button.
final contentTabListProvider =
    AsyncNotifierProvider<ContentTabListNotifier, ContentListState>(
      ContentTabListNotifier.new,
      retry: (retryCount, error) => null,
    );

/// The External tab lists ALL content, newest first (the list rows carry no
/// external numbers; those are loaded per opened item).
class ExternalContentListNotifier extends ContentListNotifierBase {
  @override
  ({String type, String ordering}) queryOf({required bool watch}) {
    return (
      type: ContentTypeFilter.all.wire,
      ordering: ContentOrdering.newest.wire,
    );
  }
}

final externalContentListProvider =
    AsyncNotifierProvider<ExternalContentListNotifier, ContentListState>(
      ExternalContentListNotifier.new,
      retry: (retryCount, error) => null,
    );

/// One content item's analytics. Key = (contentType 'post'|'reel', id).
final contentAnalyticsDetailProvider = FutureProvider.autoDispose
    .family<analytics_domain.ContentDetail, (String, int)>((ref, key) async {
      final period = ref.watch(analyticsPeriodProvider);
      final profile = await ref.watch(businessProfileProvider.future);
      if (profile == null) {
        throw const AnalyticsBusinessUnavailableException();
      }
      return ref
          .watch(businessAnalyticsRepositoryProvider)
          .fetchContentDetail(
            businessId: profile.id,
            contentType: key.$1,
            contentId: key.$2,
            period: period,
          );
    }, retry: (retryCount, error) => null);

/// Latest external snapshot per (platform, metric) of one content item.
final contentExternalMetricsProvider = FutureProvider.autoDispose
    .family<analytics_domain.ExternalMetricsResponse, (String, int)>((ref, key) async {
      final profile = await ref.watch(businessProfileProvider.future);
      if (profile == null) {
        throw const AnalyticsBusinessUnavailableException();
      }
      return ref
          .watch(businessAnalyticsRepositoryProvider)
          .fetchExternalMetrics(
            businessId: profile.id,
            contentType: key.$1,
            contentId: key.$2,
          );
    }, retry: (retryCount, error) => null);

/// Thumbnail of a content item from the existing content feature (the
/// analytics row has none). Null while loading or when the item is not in the
/// first page of the merchant's own content; the card shows a placeholder.
final analyticsContentThumbProvider = Provider.autoDispose
    .family<String?, (String, int)>((ref, key) {
      final AsyncValue<List<ContentItem>> own = ref.watch(ownContentProvider);
      return switch (own) {
        AsyncData<List<ContentItem>>(:final value) => _thumbFor(value, key),
        _ => null,
      };
    });

String? _thumbFor(List<ContentItem> items, (String, int) key) {
  for (final ContentItem item in items) {
    if (item.type == key.$1 && item.id == key.$2) {
      return item.thumbnailUrl;
    }
  }
  return null;
}
