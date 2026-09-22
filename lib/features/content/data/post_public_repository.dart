import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/post_public_repository.dart';
import '../domain/public_post_entity.dart';
import 'dtos/post_public_response_dto.dart';

/// Part P-045 scope: [PostPublicRepository] implementation. Follows
/// `ProductPublicRepositoryImpl`'s exact conventions (Part P-034):
/// depends only on `dioClientProvider`, interprets "not visible to the
/// public" as a `null` return HERE (never in `core/network`, which
/// stays feature-agnostic), and rethrows every other [DioException]
/// untouched so `.error` stays a typed `ApiFailure` (`ErrorInterceptor`,
/// P-004).
class PostPublicRepositoryImpl implements PostPublicRepository {
  PostPublicRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _publicListPath = '/api/v1/posts/public/';

  static String _detailPath(int id) => '/api/v1/posts/$id/';

  @override
  Future<PublicPost?> fetchPublicPost(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_detailPath(id));
      final json = response.data!;

      // GET /api/v1/posts/{id}/ (PostDetailView) is a pre-existing,
      // AllowAny endpoint that serves the FULL owner-facing
      // PostSerializer shape regardless of moderation status — a
      // known, pre-existing gap flagged in PostPublicListView's own
      // docstring ("PostDetailView's own public GET is unaffected and
      // unchanged, and is a separate, pre-existing concern from
      // P-041"), not something this part introduces or must fix. This
      // repository must still never hand a pending/rejected Post to a
      // customer-facing caller, so `status` is read directly off the
      // raw map here — BEFORE it's dropped at PostPublicResponseDto's
      // boundary (see that file's docstring). Same "check the raw
      // field, then discard it" pattern ProductPublicRepositoryImpl
      // uses for `isActive` (Part P-034).
      if (json['status'] != 'published') {
        return null;
      }

      return PostPublicResponseDto.fromJson(json).toEntity();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Genuinely doesn't exist — a real, renderable state, never an
        // error. Same convention as ProductPublicRepositoryImpl.
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<PaginatedResponse<PublicPost>> fetchBusinessPosts(
    int businessId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _publicListPath,
      queryParameters: {'business_id': businessId},
    );
    return PaginatedResponse.fromJson<PublicPost>(
      response.data!,
      (json) => PostPublicResponseDto.fromJson(json).toEntity(),
    );
  }
}

/// Exposes [PostPublicRepository] via Riverpod — a plain `Provider`, so
/// tests/screens can override it. Same pattern as
/// `productPublicRepositoryProvider` (Part P-034).
final postPublicRepositoryProvider = Provider<PostPublicRepository>(
  (ref) => PostPublicRepositoryImpl(dio: ref.watch(dioClientProvider)),
);