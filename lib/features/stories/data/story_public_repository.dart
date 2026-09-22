import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_reporting.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/public_story_entity.dart';
import '../domain/story_public_repository.dart';
import 'dtos/story_public_response_dto.dart';

/// Part P-050 scope: [StoryPublicRepository] implementation. Follows
/// `PostPublicRepositoryImpl`/`ReelPublicRepositoryImpl`'s exact
/// conventions (Part P-045): depends only on `dioClientProvider`, and
/// [fetchBusinessStories] rethrows every [DioException] untouched so
/// `.error` stays a typed `ApiFailure` (`ErrorInterceptor`, P-004).
///
/// [recordView] is the one method with no P-045 precedent to mirror --
/// see its own doc below for why it deliberately does NOT rethrow.
class StoryPublicRepositoryImpl implements StoryPublicRepository {
  StoryPublicRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _publicListPath = '/api/v1/stories/public/';

  static String _viewPath(int id) => '/api/v1/stories/$id/view/';

  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _publicListPath,
      queryParameters: {'business_id': businessId},
    );
    return PaginatedResponse.fromJson<PublicStory>(
      response.data!,
      (json) => StoryPublicResponseDto.fromJson(json).toEntity(),
    );
  }

  @override
  Future<void> recordView(int storyId) async {
    // Fire-and-forget per the master plan's own P-050 spec ("don't
    // await/block the UI on this call's completion"). Because
    // StoryViewerScreen (a later step) deliberately never awaits this
    // call, an unswallowed exception here would surface as an
    // unhandled Future error in a detached async context rather than
    // anywhere a user or a widget test could sensibly react to it. So
    // -- unlike every other repository method in this app, which
    // rethrows so a typed ApiFailure reaches a FutureProvider an
    // ErrorStateWidget can render -- this one catches, funnels through
    // reportError (the app's single error-logging point,
    // core/error_reporting.dart, P-008), and returns normally. A
    // failed view-tracking call must never interrupt Story playback.
    try {
      await _dio.post<void>(_viewPath(storyId));
    } on DioException catch (e, stackTrace) {
      reportError(e, stackTrace);
    }
  }
}

/// Exposes [StoryPublicRepository] via Riverpod. Same pattern as
/// `postPublicRepositoryProvider`/`reelPublicRepositoryProvider`
/// (Part P-045).
final storyPublicRepositoryProvider = Provider<StoryPublicRepository>(
  (ref) => StoryPublicRepositoryImpl(dio: ref.watch(dioClientProvider)),
);