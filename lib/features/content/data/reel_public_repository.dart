import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/reel_public_repository.dart';
import '../domain/public_reel_entity.dart';
import 'dtos/reel_public_response_dto.dart';

/// Part P-045 scope: [ReelPublicRepository] implementation. Same
/// conventions as `PostPublicRepositoryImpl` above — the one
/// difference is the extra `processing_status == "ready"` check,
/// mirroring `Reel.published_objects` (`ReelPublishedManager`)'s own
/// server-side requirement for the list endpoint.
class ReelPublicRepositoryImpl implements ReelPublicRepository {
  ReelPublicRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _publicListPath = '/api/v1/reels/public/';

  static String _detailPath(int id) => '/api/v1/reels/$id/';

  @override
  Future<PublicReel?> fetchPublicReel(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_detailPath(id));
      final json = response.data!;

      // Same reasoning as PostPublicRepositoryImpl.fetchPublicPost —
      // GET /api/v1/reels/{id}/ (ReelDetailView) is a pre-existing,
      // AllowAny endpoint serving the full owner-facing ReelSerializer
      // shape. A Reel additionally needs processing_status == "ready"
      // (not just status == "published") before it's public-safe —
      // ReelPublicListView's own docstring: "Every row ...  already
      // has processing_status='ready' by construction (via
      // Reel.published_objects / ReelPublishedManager)".
      final isPublished = json['status'] == 'published';
      final isReady = json['processing_status'] == 'ready';
      if (!isPublished || !isReady) {
        return null;
      }

      return ReelPublicResponseDto.fromJson(json).toEntity();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<PaginatedResponse<PublicReel>> fetchBusinessReels(
    int businessId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _publicListPath,
      queryParameters: {'business_id': businessId},
    );
    return PaginatedResponse.fromJson<PublicReel>(
      response.data!,
      (json) => ReelPublicResponseDto.fromJson(json).toEntity(),
    );
  }
}

/// Exposes [ReelPublicRepository] via Riverpod. Same pattern as
/// `postPublicRepositoryProvider` above.
final reelPublicRepositoryProvider = Provider<ReelPublicRepository>(
  (ref) => ReelPublicRepositoryImpl(dio: ref.watch(dioClientProvider)),
);