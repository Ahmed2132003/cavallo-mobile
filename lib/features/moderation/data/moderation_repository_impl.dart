import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/moderation_repository.dart';
import '../domain/queue_item_entity.dart';
import 'dtos/queue_item_response_dto.dart';

/// Part P-040 scope: `lib/features/moderation/data/` — the
/// [ModerationRepository] implementation. Follows
/// `ProductRepositoryImpl`'s exact conventions: depends only on
/// `dioClientProvider` (never builds its own `Dio`), maps DTO → domain
/// entity itself, and does NOT catch/re-wrap [DioException] — every
/// failure surfaces as-is with `.error` already a typed `ApiFailure`
/// (Part P-004's `ErrorInterceptor`).
///
/// Status-code mapping, confirmed against `moderation/views.py` (P-038)
/// and `ErrorInterceptor._mapStatusCode`:
///   * 400 → `ValidationFailure` (blank `reason`, invalid `priority`)
///   * 401/403 → `AuthFailure` (403 = the caller lacks the
///     `can_moderate_content` permission — see the P-040 gap note)
///   * 404 and 409 → `UnknownFailure` (no dedicated subtype exists);
///     read `DioException.response?.statusCode` to tell them apart.
class ModerationRepositoryImpl implements ModerationRepository {
  ModerationRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _queuePath = '/api/v1/moderation/queue/';

  /// The backend's `StandardCursorPagination.max_page_size`. Asking for
  /// the maximum keeps the client-side "fast_path first" sort meaningful
  /// over as many pending items as a single request can carry.
  static const _pageSize = 100;

  static String _approvePath(int queueItemId) =>
      '/api/v1/moderation/queue/$queueItemId/approve/';

  static String _rejectPath(int queueItemId) =>
      '/api/v1/moderation/queue/$queueItemId/reject/';

  @override
  Future<PaginatedResponse<QueueItem>> fetchQueue({
    QueuePriority? priority,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _queuePath,
      queryParameters: {
        'page_size': _pageSize,
        if (priority != null) 'priority': priority.toWire(),
      },
    );
    return PaginatedResponse.fromJson<QueueItem>(
      response.data!,
      (json) => QueueItemResponseDto.fromJson(json).toEntity(),
    );
  }

  @override
  Future<QueueItem> approve(int queueItemId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _approvePath(queueItemId),
    );
    return QueueItemResponseDto.fromJson(response.data!).toEntity();
  }

  @override
  Future<QueueItem> reject({
    required int queueItemId,
    required String reason,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _rejectPath(queueItemId),
      data: {'reason': reason},
    );
    return QueueItemResponseDto.fromJson(response.data!).toEntity();
  }
}

/// Exposes [ModerationRepository] via Riverpod, per this project's
/// established pattern — a `Provider`, not a singleton/global, so it is
/// overridable in tests and in this part's own screens.
final moderationRepositoryProvider = Provider<ModerationRepository>(
  (ref) => ModerationRepositoryImpl(dio: ref.watch(dioClientProvider)),
);