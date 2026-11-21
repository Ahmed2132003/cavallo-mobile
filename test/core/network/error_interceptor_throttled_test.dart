import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/config/app_config.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/core/network/interceptors/logging_interceptor.dart';

/// HTTP 429 handling: it stays an [UnknownFailure] with code THROTTLED (the
/// contract pinned by error_interceptor_code_test.dart) and now also carries
/// the server's `Retry-After`. Plus: the password-reset request bodies are
/// never printed by the dev logging interceptor.
void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());
  });

  Future<UnknownFailure> throttledFailureOf(String path) async {
    try {
      await dio.get<dynamic>(path);
    } on DioException catch (e) {
      return e.error as UnknownFailure;
    }
    fail('Expected a DioException to be thrown');
  }

  const envelope = <String, dynamic>{
    'error': {'code': 'THROTTLED', 'message': 'Request was throttled.'},
  };

  test('Retry-After in whole seconds becomes retryAfter', () async {
    adapter.onGet(
      '/a',
      (s) => s.reply(
        429,
        envelope,
        headers: {
          'content-type': ['application/json'],
          'retry-after': ['45'],
        },
      ),
    );
    final f = await throttledFailureOf('/a');
    expect(f.code, 'THROTTLED');
    expect(f.retryAfter, const Duration(seconds: 45));
  });

  test('no Retry-After header means retryAfter is null', () async {
    adapter.onGet('/b', (s) => s.reply(429, envelope));
    final f = await throttledFailureOf('/b');
    expect(f.code, 'THROTTLED');
    expect(f.retryAfter, isNull);
  });

  test('an HTTP-date or garbage Retry-After is ignored, not guessed', () async {
    adapter.onGet(
      '/c',
      (s) => s.reply(
        429,
        envelope,
        headers: {
          'content-type': ['application/json'],
          'retry-after': ['Wed, 21 Oct 2026 07:28:00 GMT'],
        },
      ),
    );
    expect((await throttledFailureOf('/c')).retryAfter, isNull);

    adapter.onGet(
      '/d',
      (s) => s.reply(
        429,
        envelope,
        headers: {
          'content-type': ['application/json'],
          'retry-after': ['-5'],
        },
      ),
    );
    expect((await throttledFailureOf('/d')).retryAfter, isNull);
  });

  test('a 429 without any envelope still gets the THROTTLED code', () async {
    adapter.onGet('/e', (s) => s.reply(429, <String, dynamic>{}));
    final f = await throttledFailureOf('/e');
    expect(f.code, ApiErrorCodes.throttled);
  });

  test(
    'other unknown statuses are unchanged (no code, no retryAfter)',
    () async {
      adapter.onGet('/f', (s) => s.reply(418, <String, dynamic>{}));
      try {
        await dio.get<dynamic>('/f');
        fail('Expected a DioException');
      } on DioException catch (e) {
        final f = e.error as UnknownFailure;
        expect(f.code, isNull);
        expect(f.retryAfter, isNull);
      }
    },
  );

  test(
    'LoggingInterceptor never prints a password-reset request body',
    () {
      final printed = <String>[];
      runZoned(
        () {
          final interceptor = LoggingInterceptor();
          interceptor.onRequest(
            RequestOptions(
              path: '/api/v1/auth/password-reset/confirm/',
              method: 'POST',
              data: {'new_password': 'Str0ng!Passw0rd'},
            ),
            RequestInterceptorHandler(),
          );
          interceptor.onRequest(
            RequestOptions(
              path: '/api/v1/auth/login/',
              method: 'POST',
              data: {'password': 'LoginPassw0rd!'},
            ),
            RequestInterceptorHandler(),
          );
          interceptor.onRequest(
            RequestOptions(
              path: '/api/v1/posts/',
              method: 'POST',
              data: {'marker': 'visible'},
            ),
            RequestInterceptorHandler(),
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );

      expect(printed.join('\n'), isNot(contains('Str0ng!Passw0rd')));
      expect(printed.join('\n'), contains('<redacted>'));
      // Every /auth/ body is redacted, login included.
      expect(printed.join('\n'), isNot(contains('LoginPassw0rd!')));
      // Other endpoints keep their existing dev logging.
      expect(printed.join('\n'), contains('visible'));
    },
    skip:
        AppConfig.environment != AppEnvironment.dev
            ? 'LoggingInterceptor only prints in dev builds'
            : false,
  );
}
