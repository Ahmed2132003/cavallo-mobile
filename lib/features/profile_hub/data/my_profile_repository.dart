import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// What `PATCH /api/v1/auth/me/profile/` answered, when the answer carries
/// the profile (`display_name` and `avatar`).
class MyProfileUpdate {
  const MyProfileUpdate({required this.displayName, required this.avatarUrl});

  final String displayName;
  final String? avatarUrl;
}

/// Part P-116B: edits the signed-in user's own name and photo.
///
/// Kept apart from `AuthRepository` on purpose (same reason as
/// `BusinessAvatarRepository`): that contract is implemented by many test
/// fakes. Multipart is used ONLY when a photo is sent; every other call is
/// JSON. A failed call rethrows the [DioException] untouched, so `.error` is
/// the typed `ApiFailure` (read it through `localizedApiError`).
class MyProfileRepository {
  MyProfileRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String _path = '/api/v1/auth/me/profile/';

  /// Sends only what is given. [avatarBytes] and [removeAvatar] are
  /// mutually exclusive.
  ///
  /// Returns the new name and photo when the response contains both
  /// `display_name` and `avatar`; otherwise `null` (the caller then
  /// re-fetches `/auth/me/`).
  Future<MyProfileUpdate?> update({
    String? displayName,
    List<int>? avatarBytes,
    String? avatarFilename,
    bool removeAvatar = false,
  }) async {
    assert(
      !(avatarBytes != null && removeAvatar),
      'avatarBytes and removeAvatar are mutually exclusive',
    );

    final Response<Map<String, dynamic>> response;
    if (avatarBytes != null) {
      final FormData form = FormData.fromMap(<String, dynamic>{
        if (displayName != null) 'display_name': displayName,
        'avatar': MultipartFile.fromBytes(
          avatarBytes,
          filename: avatarFilename ?? 'avatar.jpg',
        ),
      });
      response = await _dio.patch<Map<String, dynamic>>(
        _path,
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
    } else {
      response = await _dio.patch<Map<String, dynamic>>(
        _path,
        data: <String, dynamic>{
          if (displayName != null) 'display_name': displayName,
          if (removeAvatar) 'remove_avatar': true,
        },
      );
    }
    return _parse(response.data);
  }

  static MyProfileUpdate? _parse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final Object? name = json['display_name'];
    if (name is! String || !json.containsKey('avatar')) return null;
    final Object? avatar = json['avatar'];
    return MyProfileUpdate(
      displayName: name,
      avatarUrl: avatar is String && avatar.isNotEmpty ? avatar : null,
    );
  }
}

final myProfileRepositoryProvider = Provider<MyProfileRepository>(
  (ref) => MyProfileRepository(dio: ref.watch(dioClientProvider)),
);
