/// Part P-062 scope: [DiscoverRepository] implementation.
///
/// Follows `FeedRepositoryImpl`'s (Part P-061) exact conventions:
/// depends only on `dioClientProvider`, never constructs its own
/// [Dio]. [fetchDiscoverFeed] parses each raw item through the SAME
/// existing `PostPublicResponseDto`/`ReelPublicResponseDto` Home Feed
/// already uses -- `GET /api/v1/feed/discover/` (STEP 1) returns the
/// identical `feed.serializers.FeedItemSerializer` shape `/feed/home/`
/// does, so no new per-item parsing was written.
///
/// [fetchActiveStoryGroups] calls the SAME public Stories endpoint
/// `StoryPublicRepositoryImpl.fetchBusinessStories` (Part P-050) calls,
/// just without the `business_id` filter, parses each row through the
/// existing `StoryPublicResponseDto` (Part P-050), and groups the
/// results by `businessId` client-side -- see
/// `DiscoverRepository.fetchActiveStoryGroups`'s own docstring for why
/// the grouping isn't a backend concern. Only the first page is
/// consumed (same scope decision `fetchBusinessStories` itself already
/// made for one business's stories, applied here across all
/// businesses) -- Phase 10's Definition of Done doesn't call for
/// infinite-scrolling the stories bar itself, only the Recommended
/// section below it.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../content/data/dtos/post_public_response_dto.dart';
import '../../content/data/dtos/reel_public_response_dto.dart';
import '../../feed/domain/feed_item_entity.dart';
import '../../feed/domain/feed_page_entity.dart';
import '../../stories/data/dtos/story_public_response_dto.dart';
import '../../stories/domain/public_story_entity.dart';
import '../domain/active_story_group_entity.dart';
import '../domain/discover_repository.dart';

class DiscoverRepositoryImpl implements DiscoverRepository {
  DiscoverRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _activeStoriesPath = '/api/v1/stories/public/';
  static const _discoverFeedPath = '/api/v1/feed/discover/';

  @override
  Future<List<ActiveStoryGroup>> fetchActiveStoryGroups() async {
    final response = await _dio.get<Map<String, dynamic>>(_activeStoriesPath);
    final data = response.data!;
    final rawResults = data['results'] as List<dynamic>;

    final stories = rawResults
        .map(
          (raw) => StoryPublicResponseDto.fromJson(
            raw as Map<String, dynamic>,
          ).toEntity(),
        )
        .toList();

    return _groupByBusiness(stories);
  }

  /// `stories` arrives newest-first overall (P-048's
  /// `StoryPublicListView` orders by `-created_at` via
  /// `StandardCursorPagination`); grouping preserves each story's
  /// relative position, so within one group stories stay in that same
  /// newest-first order. Group order follows first-appearance order in
  /// the flat list -- i.e. the business whose most recent Story is the
  /// overall-newest appears first -- `StoriesBarWidget` (a later step)
  /// is free to re-sort if a different bar ordering is wanted later.
  static List<ActiveStoryGroup> _groupByBusiness(List<PublicStory> stories) {
    final order = <int>[];
    final byBusiness = <int, List<PublicStory>>{};
    for (final story in stories) {
      final list = byBusiness.putIfAbsent(story.businessId, () {
        order.add(story.businessId);
        return [];
      });
      list.add(story);
    }
    return order
        .map(
          (businessId) => ActiveStoryGroup(
            businessId: businessId,
            stories: byBusiness[businessId]!,
          ),
        )
        .toList();
  }

  @override
  Future<FeedPage> fetchDiscoverFeed({String? cursor}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _discoverFeedPath,
      queryParameters: cursor == null ? null : {'cursor': cursor},
    );
    final data = response.data!;
    final rawItems = data['items'] as List<dynamic>;

    final items = rawItems.map((raw) {
      final json = raw as Map<String, dynamic>;
      final contentType = json['content_type'] as String;
      return switch (contentType) {
        'post' => PostFeedItem(
          PostPublicResponseDto.fromJson(json).toEntity(),
        ),
        'reel' => ReelFeedItem(
          ReelPublicResponseDto.fromJson(json).toEntity(),
        ),
        _ => throw FormatException(
          'Unknown feed content_type: "$contentType"',
        ),
      };
    }).toList();

    return FeedPage(items: items, nextCursor: data['next_cursor'] as String?);
  }
}

/// Exposes [DiscoverRepository] via Riverpod -- a plain `Provider`,
/// same pattern as `feedRepositoryProvider`/`storyPublicRepositoryProvider`.
final discoverRepositoryProvider = Provider<DiscoverRepository>(
  (ref) => DiscoverRepositoryImpl(dio: ref.watch(dioClientProvider)),
);