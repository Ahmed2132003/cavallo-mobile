import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/profile_hub/data/language_preference_repository.dart';

/// Part P-113 (STEP 3A): the one call the Language selector makes to the
/// backend: `PATCH /api/v1/auth/me/` with `{"preferred_language": code}`.

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter({this.statusCode = 200});

  final int statusCode;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_CaptureAdapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  test('sends a PATCH to /api/v1/auth/me/ with only preferred_language', () async {
    final _CaptureAdapter adapter = _CaptureAdapter();
    final LanguagePreferenceRepositoryImpl repository =
        LanguagePreferenceRepositoryImpl(dio: _dio(adapter));

    await repository.savePreferredLanguage('en');

    expect(adapter.last, isNotNull);
    expect(adapter.last!.method, 'PATCH');
    expect(adapter.last!.path, '/api/v1/auth/me/');
    expect(adapter.last!.data, <String, String>{'preferred_language': 'en'});
  });

  test('sends Arabic as "ar"', () async {
    final _CaptureAdapter adapter = _CaptureAdapter();
    final LanguagePreferenceRepositoryImpl repository =
        LanguagePreferenceRepositoryImpl(dio: _dio(adapter));

    await repository.savePreferredLanguage('ar');

    expect(adapter.last!.data, <String, String>{'preferred_language': 'ar'});
  });

  test('a rejected request throws a DioException to the caller', () async {
    final LanguagePreferenceRepositoryImpl repository =
        LanguagePreferenceRepositoryImpl(
          dio: _dio(_CaptureAdapter(statusCode: 400)),
        );

    expect(
      repository.savePreferredLanguage('en'),
      throwsA(isA<DioException>()),
    );
  });
}
