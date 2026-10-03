import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/own_stories_repository.dart';
import '../domain/own_story_entity.dart';
import 'dtos/own_story_response_dto.dart';

/// Part P-083 scope: [OwnStoriesRepository] implementation. Depends only
/// on `dioClientProvider` and rethrows every [DioException] untouched, like
/// every other repository in this codebase.
///
/// The response is parsed as a `{results, next, previous}` envelope, NOT a
/// bare array: `StoryListCreateView` sets
/// `pagination_class = StandardCursorPagination` explicitly (confirmed in
/// `stories/views.py` and pinned by this part's test). This is the
/// opposite of the P-074 `ConversationListView` case, which had no
/// pagination class and returned a plain array.
class OwnStoriesRepositoryImpl implements OwnStoriesRepository {
  OwnStoriesRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _storiesPath = '/api/v1/stories/';

  @override
  Future<PaginatedResponse<OwnStory>> listOwnStories() async {
    final response = await _dio.get<Map<String, dynamic>>(_storiesPath);
    return PaginatedResponse.fromJson<OwnStory>(
      response.data!,
      (json) => OwnStoryResponseDto.fromJson(json).toEntity(),
    );
  }
}

/// Exposes [OwnStoriesRepository] via Riverpod. Same pattern as
/// `storyPublicRepositoryProvider`.
final ownStoriesRepositoryProvider = Provider<OwnStoriesRepository>(
  (ref) => OwnStoriesRepositoryImpl(dio: ref.watch(dioClientProvider)),
);
