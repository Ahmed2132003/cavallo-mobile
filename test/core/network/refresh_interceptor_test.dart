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

/// Part P-022C (Tests D and E) — main-client adapter for the concurrency
/// cases.
///
/// Answers **401 to anything that is not carrying the post-refresh access
/// token**, and 200 once it is. That is what lets a single adapter serve N
/// concurrent requests that must each 401 first and then succeed on their
/// own retry — [_SequencedAdapter] above can't, because it hands out one
/// fixed reply per call *in order*, which says nothing about which request
/// is being answered.
class _TokenAwareAdapter implements HttpClientAdapter {
  /// Every call that reached the "server", initial 401s and retries alike.
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    final authHeader =
        options.headers['Authorization'] ?? options.headers['authorization'];

    if (authHeader == 'Bearer new-access') {
      return _jsonResponse(200, {'ok': true, 'path': options.path});
    }

    return _jsonResponse(401, {
      'error': {'code': 'UNAUTHENTICATED', 'message': 'Token expired'},
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Part P-022C (Tests D and E) — refresh-client adapter that **counts** how
/// many times `/api/v1/auth/refresh/` was actually called.
///
/// That call count is the whole point of Test D: the single-flight lock is
/// only proven by asserting it stayed at 1 while five requests 401'd at
/// once. [delay] holds the refresh call open long enough that the other
/// four 401s are guaranteed to land while it is still in flight.
class _CountingRefreshAdapter implements HttpClientAdapter {
  _CountingRefreshAdapter({this.delay = Duration.zero});

  final Duration delay;

  /// Number of calls made to [RefreshInterceptor.refreshPath].
  int refreshCallCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path != RefreshInterceptor.refreshPath) {
      // Same spirit as the deliberately-unregistered routes in Tests B/C:
      // anything other than the refresh endpoint arriving on the refresh
      // client is a bug, and should be loudly wrong rather than silently OK.
      return _jsonResponse(404, {
        'error': {
          'code': 'NOT_FOUND',
          'message': 'unexpected route on refresh client: ${options.path}',
        },
      });
    }

    refreshCallCount++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return _jsonResponse(200, {
      'access': 'new-access',
      'refresh': 'new-refresh',
    });
  }

  @override
  void close({bool force = false}) {}
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

  test(
    '5 concurrent requests against an expired token trigger exactly ONE '
    'refresh call, and all 5 original requests succeed after that single '
    'refresh (Test D — Part P-022C)',
    () async {
      final storage = SecureTokenStorage();
      await storage.saveTokens(access: 'old-access', refresh: 'old-refresh');

      var invalidateSessionCallCount = 0;

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final mainAdapter = _TokenAwareAdapter();
      dio.httpClientAdapter = mainAdapter;

      final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      // The 50ms hold guarantees the other four 401s arrive while this one
      // refresh is still in flight — i.e. the exact stampede window.
      final refreshAdapter = _CountingRefreshAdapter(
        delay: const Duration(milliseconds: 50),
      );
      refreshDio.httpClientAdapter = refreshAdapter;

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

      final responses = await Future.wait(
        List.generate(
          5,
          (index) => dio.get<Map<String, dynamic>>(
            '/some/protected/endpoint/$index',
            options: Options(
              headers: {'Authorization': 'Bearer old-access'},
            ),
          ),
        ),
      );

      // THE assertion this part exists for: no refresh stampede.
      expect(
        refreshAdapter.refreshCallCount,
        1,
        reason: 'concurrent 401s must share a single refresh call',
      );

      // All five original requests still succeed, each with its own result.
      expect(responses.length, 5);
      for (var index = 0; index < responses.length; index++) {
        expect(responses[index].statusCode, 200);
        expect(responses[index].data?['ok'], true);
        expect(
          responses[index].data?['path'],
          '/some/protected/endpoint/$index',
        );
      }

      // 5 initial 401s + 5 retries — every waiter really did retry, rather
      // than being resolved with someone else's response.
      expect(mainAdapter.requestCount, 10);

      // The single refresh's token pair is what got persisted.
      expect(await storage.getAccessToken(), 'new-access');
      expect(await storage.getRefreshToken(), 'new-refresh');

      // Nothing failed, so the session was never invalidated.
      expect(invalidateSessionCallCount, 0);
    },
  );

  test(
    'a later, independent 401 starts a FRESH single-flight cycle instead of '
    'reusing the already-completed one (Test E — Part P-022C lock reset)',
    () async {
      final storage = SecureTokenStorage();
      await storage.saveTokens(access: 'old-access', refresh: 'old-refresh');

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final mainAdapter = _TokenAwareAdapter();
      dio.httpClientAdapter = mainAdapter;

      final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final refreshAdapter = _CountingRefreshAdapter();
      refreshDio.httpClientAdapter = refreshAdapter;

      dio.interceptors.add(
        RefreshInterceptor(
          dio: dio,
          tokenStorage: storage,
          refreshDio: refreshDio,
        ),
      );

      // Cycle 1.
      final first = await dio.get<Map<String, dynamic>>(
        '/some/protected/endpoint/first',
        options: Options(headers: {'Authorization': 'Bearer old-access'}),
      );
      expect(first.statusCode, 200);
      expect(refreshAdapter.refreshCallCount, 1);

      // Cycle 2 — a completely separate request, later in time, carrying a
      // token the server rejects again. If the completed completer from
      // cycle 1 were still held, this request would either hang forever or
      // retry without refreshing at all; instead it must start its own
      // refresh.
      final second = await dio.get<Map<String, dynamic>>(
        '/some/protected/endpoint/second',
        options: Options(headers: {'Authorization': 'Bearer stale-again'}),
      );
      expect(second.statusCode, 200);
      expect(
        refreshAdapter.refreshCallCount,
        2,
        reason: 'the lock must reset once a refresh cycle ends',
      );
    },
  );
}