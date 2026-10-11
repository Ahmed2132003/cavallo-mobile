import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// Business profile photo upload / removal
/// (`/api/v1/businesses/me/avatar/`, multipart field `avatar`).
///
/// Kept apart from `BusinessProfileRepository` on purpose: that contract is
/// implemented by test fakes, and the photo has its own endpoint (the JSON
/// `/me/` POST/PATCH never carries it). Both calls answer with the owner's
/// full profile; only its `avatar` URL is read here (`null` after a removal).
///
/// A failed call rethrows the [DioException] untouched, so `.error` stays the
/// typed `ApiFailure` (same convention as the other repositories).
class BusinessAvatarRepository {
  BusinessAvatarRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _avatarPath = '/api/v1/businesses/me/avatar/';

  /// Uploads [bytes] as the new photo and returns its URL.
  Future<String?> upload({
    required List<int> bytes,
    required String filename,
  }) async {
    final data = FormData.fromMap(<String, dynamic>{
      'avatar': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      _avatarPath,
      data: data,
    );
    return _avatarOf(response.data);
  }

  /// Removes the photo. Always resolves to `null` on success.
  Future<String?> remove() async {
    final response = await _dio.delete<Map<String, dynamic>>(_avatarPath);
    return _avatarOf(response.data);
  }

  static String? _avatarOf(Map<String, dynamic>? json) {
    final value = json?['avatar'];
    return value is String && value.isNotEmpty ? value : null;
  }
}

final businessAvatarRepositoryProvider = Provider<BusinessAvatarRepository>(
  (ref) => BusinessAvatarRepository(dio: ref.watch(dioClientProvider)),
);
