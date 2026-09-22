/// Part P-044 scope: `lib/features/content/data/` — the
/// [PostRepository] implementation. Mirrors `ProductRepositoryImpl`'s
/// exact conventions (Part P-033): depends only on `dioClientProvider`
/// (never constructs its own `Dio`), maps DTO → domain entity itself,
/// and does NOT catch/re-wrap [DioException] anywhere — every failure
/// surfaces to the caller as-is, with `.error` already a typed
/// `ApiFailure` (Part P-004's `ErrorInterceptor`).
///
/// ### Multipart testing note (flagged by P-033's own handoff)
/// `http_mock_adapter`'s route matcher cannot match a [FormData]
/// request body by structural equality — this part's own repository
/// test (STEP 9) follows P-033's documented workaround: a hand-rolled
/// fake JSON adapter draining the request stream, instead of
/// `DioAdapter.onPost(..., data: {...})`.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/post_entity.dart';
import '../domain/post_repository.dart';
import 'dtos/post_response_dto.dart';

class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _postsPath = '/api/v1/posts/';

  @override
  Future<PaginatedResponse<Post>> fetchOwnPosts() async {
    final response = await _dio.get<Map<String, dynamic>>(_postsPath);
    return PaginatedResponse.fromJson<Post>(
      response.data!,
      (json) => PostResponseDto.fromJson(json).toEntity(),
    );
  }

  @override
  Future<Post> createPost({required String caption, File? imageFile}) async {
    final fields = <String, dynamic>{'caption': caption};

    final data = imageFile == null
        ? fields
        : await _toFormData(fields, imageFile);

    final response = await _dio.post<Map<String, dynamic>>(
      _postsPath,
      data: data,
    );

    return PostResponseDto.fromJson(response.data!).toEntity();
  }

  /// Builds a [FormData] carrying every field in [fields] plus the
  /// image under the `image` key — matching
  /// `content.serializers.PostSerializer`'s field name exactly. Same
  /// shape as `ProductRepositoryImpl._toFormData` (Part P-033).
  Future<FormData> _toFormData(
    Map<String, dynamic> fields,
    File imageFile,
  ) async {
    final stringFields = fields.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    return FormData.fromMap({
      ...stringFields,
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.uri.pathSegments.last,
      ),
    });
  }
}

/// Exposes [PostRepository] to the rest of the app via Riverpod, same
/// pattern as `productRepositoryProvider`.
final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepositoryImpl(dio: ref.watch(dioClientProvider)),
);