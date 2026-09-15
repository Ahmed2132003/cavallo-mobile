import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/refresh_interceptor.dart';
import 'package:social_commerce_app/core/storage/secure_token_storage.dart';

/// A tiny hand-rolled [HttpClientAdapter] that returns one fixed
/// [ResponseBody] per call, in order — used for the main client in Test A
/// so the *same* route (`/some/protected/endpoint`) can answer 401 on the
/// first call and 200 on the retry. `http_mock_adapter`'s [DioAdapter] (used
/// everywhere else in this project, e.g. `error_interceptor_test.dart`) only
/// stubs a single fixed reply per route, so it can't express this
/// same-route-different-replies sequence — this project has no other
/// mocking dependency (no mockito/mocktail, confirmed via
/// `PROJECT_PROGRESS.md`), so a minimal adapter is used instead of adding
/// one.
class _SequencedAdapter implements HttpClientAdapter {
  _SequencedAdapter(this._responses);

  final List<ResponseBody> _responses;
  int _callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = _responses[_callCount];
    _callCount++;
    return response;
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> data) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Same mocking mechanism as `secure_token_storage_test.dart` /
    // `session_provider_test.dart` — a real SecureTokenStorage backed by
    // FlutterSecureStorage's in-memory test platform.
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('expired access token → silent refresh → retried request succeeds, '
      'caller never sees the intermediate 401 (Test A)', () async {
    final storage = SecureTokenStorage();
    await storage.saveTokens(access: 'old-access', refresh: 'old-refresh');

    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.httpClientAdapter = _SequencedAdapter([
      _jsonResponse(401, {
        'error': {'code': 'UNAUTHENTICATED', 'message': 'Token expired'},
      }),
      _jsonResponse(200, {'ok': true}),
    ]);

    final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final refreshAdapter = DioAdapter(dio: refreshDio);
    refreshDio.httpClientAdapter = refreshAdapter;
    refreshAdapter.onPost(
      '/api/v1/auth/refresh/',
      (server) =>
          server.reply(200, {'access': 'new-access', 'refresh': 'new-refresh'}),
      data: {'refresh': 'old-refresh'},
    );

    dio.interceptors.add(
      RefreshInterceptor(
        dio: dio,
        tokenStorage: storage,
        refreshDio: refreshDio,
      ),
    );

    final response = await dio.get<Map<String, dynamic>>(
      '/some/protected/endpoint',
    );

    // The caller only ever sees the final, successful result — no
    // exception, and no trace of the intermediate 401.
    expect(response.statusCode, 200);
    expect(response.data, {'ok': true});

    // The new token pair from the refresh call was persisted.
    expect(await storage.getAccessToken(), 'new-access');
    expect(await storage.getRefreshToken(), 'new-refresh');
  });

  test('a request to the refresh path itself that 401s does not recurse into '
      'another refresh attempt (Test C)', () async {
    final storage = SecureTokenStorage();
    await storage.saveTokens(access: 'old-access', refresh: 'old-refresh');

    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    adapter.onPost(
      '/api/v1/auth/refresh/',
      (server) => server.reply(401, {
        'error': {
          'code': 'UNAUTHENTICATED',
          'message': 'Refresh token invalid',
        },
      }),
      // The `data` matcher must mirror the body actually sent below —
      // without it DioAdapter can't match the route at all and throws an
      // "unmocked route" error (response == null) instead of the 401 this
      // test is asserting on.
      data: {'refresh': 'old-refresh'},
    );

    final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final refreshAdapter = DioAdapter(dio: refreshDio);
    refreshDio.httpClientAdapter = refreshAdapter;
    // Deliberately no route registered here: if RefreshInterceptor ever
    // attempted a second refresh call for this excluded path, this
    // adapter would throw an "unmocked route" error instead of the
    // plain 401 asserted below — that's how this test tells "correctly
    // skipped" apart from "recursed."

    dio.interceptors.add(
      RefreshInterceptor(
        dio: dio,
        tokenStorage: storage,
        refreshDio: refreshDio,
      ),
    );

    try {
      await dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh/',
        data: {'refresh': 'old-refresh'},
      );
      fail('Expected a DioException to be thrown');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 401);
    }

    // Tokens are untouched — no refresh attempt was made at all.
    expect(await storage.getAccessToken(), 'old-access');
    expect(await storage.getRefreshToken(), 'old-refresh');
  });

  test(
    'refresh call itself returns 401 → SecureTokenStorage is cleared, the '
    'session is invalidated, and the original caller receives an '
    'AuthFailure (Test B — Part P-022B)',
    () async {
      final storage = SecureTokenStorage();
      await storage.saveTokens(access: 'old-access', refresh: 'old-refresh');

      var invalidateSessionCallCount = 0;

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;
      adapter.onGet(
        '/some/protected/endpoint',
        (server) => server.reply(401, {
          'error': {'code': 'UNAUTHENTICATED', 'message': 'Token expired'},
        }),
      );

      final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final refreshAdapter = DioAdapter(dio: refreshDio);
      refreshDio.httpClientAdapter = refreshAdapter;
      refreshAdapter.onPost(
        '/api/v1/auth/refresh/',
        (server) => server.reply(401, {
          'error': {
            'code': 'UNAUTHENTICATED',
            'message': 'Refresh token invalid',
          },
        }),
        data: {'refresh': 'old-refresh'},
      );

      dio.interceptors.add(
        RefreshInterceptor(
          dio: dio,
          tokenStorage: storage,
          refreshDio: refreshDio,
          invalidateSession: () async {
            invalidateSessionCallCount++;
          },
        ),
      );

      try {
        await dio.get<Map<String, dynamic>>('/some/protected/endpoint');
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<AuthFailure>());
        expect(
          (e.error as AuthFailure).message,
          'Your session has expired. Please log in again.',
        );
      }

      // (a) SecureTokenStorage is cleared.
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);

      // (b) the session was invalidated exactly once.
      expect(invalidateSessionCallCount, 1);
    },
  );

  test(
    'no refresh token stored → treated the same as a failed refresh: '
    'storage cleared, session invalidated, AuthFailure propagated',
    () async {
      final storage = SecureTokenStorage(); // never saved any tokens
      var invalidateSessionCallCount = 0;

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;
      adapter.onGet(
        '/some/protected/endpoint',
        (server) => server.reply(401, {
          'error': {'code': 'UNAUTHENTICATED', 'message': 'Token expired'},
        }),
      );

      final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final refreshAdapter = DioAdapter(dio: refreshDio);
      refreshDio.httpClientAdapter = refreshAdapter;
      // No route registered: if the interceptor ever tried to call the
      // refresh endpoint without a refresh token, this would throw an
      // "unmocked route" error instead of the AuthFailure asserted below.

      dio.interceptors.add(
        RefreshInterceptor(
          dio: dio,
          tokenStorage: storage,
          refreshDio: refreshDio,
          invalidateSession: () async {
            invalidateSessionCallCount++;
          },
        ),
      );

      try {
        await dio.get<Map<String, dynamic>>('/some/protected/endpoint');
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<AuthFailure>());
      }

      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(invalidateSessionCallCount, 1);
    },
  );
}
