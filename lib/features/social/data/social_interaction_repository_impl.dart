import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/comment_entity.dart';
import '../domain/report_reason.dart';
import '../domain/social_interaction_repository.dart';
import 'dtos/comment_response_dto.dart';

/// Part P-058 scope: [SocialInteractionRepository] implementation.
/// Depends only on `dioClientProvider` (same convention as every
/// other repository in this project — `PostPublicRepositoryImpl`,
/// `ProductPublicRepositoryImpl`, ...). Every [DioException] is left
/// to propagate untouched (rethrown implicitly by not catching it) so
/// `.error` on it stays a typed `ApiFailure` set by `ErrorInterceptor`
/// (Part P-004) — Step 3's provider is where 404/429/400 get turned
/// into optimistic-update reverts and user-facing messages, not here.
class SocialInteractionRepositoryImpl implements SocialInteractionRepository {
  SocialInteractionRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static String _followPath(int businessId) =>
      '/api/v1/businesses/$businessId/follow/';
  static const _likesPath = '/api/v1/likes/';
  static const _savesPath = '/api/v1/saves/';
  static const _commentsPath = '/api/v1/comments/';
  static const _sharesPath = '/api/v1/shares/';
  static const _reportsPath = '/api/v1/reports/';

  // ---- Follow ----

  @override
  Future<bool> followBusiness(int businessId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _followPath(businessId),
    );
    return response.data!['following'] as bool;
  }

  @override
  Future<bool> unfollowBusiness(int businessId) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      _followPath(businessId),
    );
    return response.data!['following'] as bool;
  }

  // ---- Like ----

  @override
  Future<bool> likeContent({
    required String contentType,
    required int objectId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _likesPath,
      data: {'content_type': contentType, 'object_id': objectId},
    );
    return response.data!['liked'] as bool;
  }

  @override
  Future<bool> unlikeContent({
    required String contentType,
    required int objectId,
  }) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      _likesPath,
      data: {'content_type': contentType, 'object_id': objectId},
    );
    return response.data!['liked'] as bool;
  }

  // ---- Save ----

  @override
  Future<bool> saveContent({
    required String contentType,
    required int objectId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _savesPath,
      data: {'content_type': contentType, 'object_id': objectId},
    );
    return response.data!['saved'] as bool;
  }

  @override
  Future<bool> unsaveContent({
    required String contentType,
    required int objectId,
  }) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      _savesPath,
      data: {'content_type': contentType, 'object_id': objectId},
    );
    return response.data!['saved'] as bool;
  }

  // ---- Comment ----

  @override
  Future<CommentEntity> createComment({
    required String contentType,
    required int objectId,
    required String text,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _commentsPath,
      data: {
        'content_type': contentType,
        'object_id': objectId,
        'text': text,
      },
    );
    return CommentResponseDto.fromJson(response.data!).toEntity();
  }

  @override
  Future<PaginatedResponse<CommentEntity>> listComments({
    required String contentType,
    required int objectId,
    String? pageUrl,
  }) async {
    final response = pageUrl != null
        ? await _dio.get<Map<String, dynamic>>(pageUrl)
        : await _dio.get<Map<String, dynamic>>(
            _commentsPath,
            queryParameters: {
              'content_type': contentType,
              'object_id': objectId,
            },
          );
    return PaginatedResponse.fromJson<CommentEntity>(
      response.data!,
      (json) => CommentResponseDto.fromJson(json).toEntity(),
    );
  }

  // ---- Share ----

  @override
  Future<void> shareContent({
    required String contentType,
    required int objectId,
  }) async {
    // Deliberately no get_or_create-equivalent guard, no local
    // debounce/dedupe — Share is non-idempotent by design (P-056).
    // Every call here is a genuine new event on the server.
    await _dio.post<Map<String, dynamic>>(
      _sharesPath,
      data: {'content_type': contentType, 'object_id': objectId},
    );
  }

  // ---- Report ----

  @override
  Future<void> reportTarget({
    required String contentType,
    required int objectId,
    required ReportReason reason,
    String? details,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      _reportsPath,
      data: {
        'content_type': contentType,
        'object_id': objectId,
        'reason': reason.wireValue,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
    // Both 201 (new report) and 200 (repeat report, already reported)
    // are success here — Dio only throws on a genuinely non-2xx
    // status, so no explicit status-code branching is needed.
  }
}

/// Exposes [SocialInteractionRepository] via Riverpod — a plain
/// `Provider`, same pattern as `postPublicRepositoryProvider` /
/// `productPublicRepositoryProvider`, so Step 3's provider (and
/// widget tests) can override it.
final socialInteractionRepositoryProvider =
    Provider<SocialInteractionRepository>(
      (ref) =>
          SocialInteractionRepositoryImpl(dio: ref.watch(dioClientProvider)),
    );