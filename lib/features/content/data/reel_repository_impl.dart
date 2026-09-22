/// Part P-044 scope: the [ReelRepository] implementation. Same
/// conventions as `PostRepositoryImpl` above — the one difference is
/// `video` is REQUIRED (not optional like Post's `image`), so every
/// create call is a multipart request; there is no plain-JSON path
/// here (`content.serializers.ReelSerializer.validate_video` always
/// runs, unlike `PostSerializer.validate_image`'s `if value:` guard).
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/reel_entity.dart';
import '../domain/reel_repository.dart';
import 'dtos/reel_response_dto.dart';

class ReelRepositoryImpl implements ReelRepository {
  ReelRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _reelsPath = '/api/v1/reels/';

  @override
  Future<PaginatedResponse<Reel>> fetchOwnReels() async {
    final response = await _dio.get<Map<String, dynamic>>(_reelsPath);
    return PaginatedResponse.fromJson<Reel>(
      response.data!,
      (json) => ReelResponseDto.fromJson(json).toEntity(),
    );
  }

  @override
  Future<Reel> createReel({
    required String caption,
    required File videoFile,
  }) async {
    final data = FormData.fromMap({
      'caption': caption,
      'video': await MultipartFile.fromFile(
        videoFile.path,
        filename: videoFile.uri.pathSegments.last,
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      _reelsPath,
      data: data,
    );

    return ReelResponseDto.fromJson(response.data!).toEntity();
  }
}

/// Exposes [ReelRepository] to the rest of the app via Riverpod, same
/// pattern as `postRepositoryProvider`.
final reelRepositoryProvider = Provider<ReelRepository>(
  (ref) => ReelRepositoryImpl(dio: ref.watch(dioClientProvider)),
);