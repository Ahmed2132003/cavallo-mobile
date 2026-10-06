import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// Part P-113 (STEP 3A): tells the backend which language the signed-in user
/// chose in Settings.
///
/// Why a separate small repository (and not a new method on
/// `AuthRepository`): `AuthRepository` is implemented by several test fakes,
/// so adding an abstract method there would break them for no benefit. This
/// one call has nothing to do with login or tokens.
///
/// Backend contract (P-112, `accounts.views.MeView.patch`):
/// `PATCH /api/v1/auth/me/` with `{"preferred_language": "ar" | "en"}`. Any
/// other field in the body is ignored by the server. The response has the
/// same shape as `GET /api/v1/auth/me/`; nothing in it is needed here.
///
/// Failures surface as a `DioException` whose `.error` is an `ApiFailure`
/// (Part P-004), like every other repository in the app.
abstract class LanguagePreferenceRepository {
  Future<void> savePreferredLanguage(String languageCode);
}

class LanguagePreferenceRepositoryImpl implements LanguagePreferenceRepository {
  LanguagePreferenceRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String _mePath = '/api/v1/auth/me/';

  @override
  Future<void> savePreferredLanguage(String languageCode) async {
    await _dio.patch<Map<String, dynamic>>(
      _mePath,
      data: <String, String>{'preferred_language': languageCode},
    );
  }
}

final Provider<LanguagePreferenceRepository>
languagePreferenceRepositoryProvider = Provider<LanguagePreferenceRepository>((
  Ref ref,
) {
  return LanguagePreferenceRepositoryImpl(dio: ref.watch(dioClientProvider));
});
