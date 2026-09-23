import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// Part P-051 scope: uploads a Story's media file to P-047's
/// `POST /api/v1/stories/` endpoint.
///
/// SCOPE DECISION: unlike every other repository in this codebase
/// (`ProductRepository`, `ReelRepository`, `StoryPublicRepository`...),
/// this file has NO separate `domain/story_creation_repository.dart`
/// abstract interface. P-051's own "Files Expected" list names exactly
/// one repository file, not an interface+impl pair. The only consumer
/// is `StoryUploadQueueNotifier` (STEP 2), which lives in this same
/// feature module. Promoting this to a domain interface later is a
/// small, contained follow-up if a second consumer ever needs it.
///
/// `StorySerializer` (P-046, confirmed by reading `stories/serializers.py`
/// directly) has exactly ONE writable field: `media`. No caption,
/// text-overlay, or product-link field exists on the backend today —
/// see `stories/models.py`'s own "SCOPE FINDING" docstring for that
/// already-flagged, unresolved gap between the presentation deck and
/// P-046's real scope. Not re-decided here.
class StoryCreationRepository {
  StoryCreationRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _storiesPath = '/api/v1/stories/';

  /// Uploads [mediaFile] (image or video — `StorySerializer.validate_media`
  /// accepts both) as a new Story. `media` is Story's only writable
  /// field and is required, so — unlike `ProductRepositoryImpl`'s
  /// optional-image branch — this always sends a multipart body. Same
  /// reasoning as `ReelRepositoryImpl.createReel`, whose `video` is also
  /// required.
  ///
  /// [cancelToken] lets `StoryUploadQueueNotifier` (STEP 2) cancel an
  /// in-flight attempt if the user cancels mid-retry-cycle.
  ///
  /// Every [DioException] — network failure, timeout, 400 validation,
  /// anything else — is rethrown untouched, never caught here, so
  /// `.error` stays a typed [ApiFailure] (`ErrorInterceptor`, P-004).
  /// Classifying which failures are retry-worthy is STEP 2's job, not
  /// this file's — this repository only knows how to make the call.
  Future<void> uploadStoryMedia({
    required File mediaFile,
    CancelToken? cancelToken,
  }) async {
    final data = FormData.fromMap({
      'media': await MultipartFile.fromFile(
        mediaFile.path,
        filename: mediaFile.uri.pathSegments.last,
      ),
    });

    await _dio.post<Map<String, dynamic>>(
      _storiesPath,
      data: data,
      cancelToken: cancelToken,
    );
  }
}

/// Exposes [StoryCreationRepository] via Riverpod. Same pattern as
/// `productRepositoryProvider`/`storyPublicRepositoryProvider` —
/// depends only on `dioClientProvider`, never constructs its own [Dio].
final storyCreationRepositoryProvider = Provider<StoryCreationRepository>(
  (ref) => StoryCreationRepository(dio: ref.watch(dioClientProvider)),
);