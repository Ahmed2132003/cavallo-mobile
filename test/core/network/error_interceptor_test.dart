import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());
  });

  test('400 with fields maps to ValidationFailure with those field errors', () async {
    adapter.onPost(
      '/register',
      (server) => server.reply(400, {
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Invalid input',
          'fields': {
            'email': ['already exists'],
          },
        },
      }),
    );

    try {
      await dio.post('/register');
      fail('Expected a DioException to be thrown');
    } on DioException catch (e) {
      final failure = e.error;
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).fields['email'], ['already exists']);
      expect(failure.message, 'Invalid input');
    }
  });

  test('401 maps to AuthFailure', () async {
    adapter.onGet(
      '/me',
      (server) => server.reply(401, {
        'error': {'code': 'UNAUTHENTICATED', 'message': 'Token expired'},
      }),
    );

    try {
      await dio.get('/me');
      fail('Expected a DioException to be thrown');
    } on DioException catch (e) {
      expect(e.error, isA<AuthFailure>());
    }
  });

  test('403 maps to AuthFailure', () async {
    adapter.onGet(
      '/admin',
      (server) => server.reply(403, {
        'error': {'code': 'FORBIDDEN', 'message': 'Not allowed'},
      }),
    );

    try {
      await dio.get('/admin');
      fail('Expected a DioException to be thrown');
    } on DioException catch (e) {
      expect(e.error, isA<AuthFailure>());
    }
  });

  test('5xx maps to ServerFailure', () async {
    adapter.onGet(
      '/boom',
      (server) => server.reply(500, {
        'error': {'code': 'SERVER_ERROR', 'message': 'Something broke'},
      }),
    );

    try {
      await dio.get('/boom');
      fail('Expected a DioException to be thrown');
    } on DioException catch (e) {
      expect(e.error, isA<ServerFailure>());
    }
  });

  test('connection timeout maps to NetworkFailure', () async {
    adapter.onGet(
      '/slow',
      (server) => server.throws(
        408,
        DioException.connectionTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: RequestOptions(path: '/slow'),
        ),
      ),
    );

    try {
      await dio.get('/slow');
      fail('Expected a DioException to be thrown');
    } on DioException catch (e) {
      expect(e.error, isA<NetworkFailure>());
    }
  });

  test('connection error maps to NetworkFailure', () async {
    adapter.onGet(
      '/unreachable',
      (server) => server.throws(
        0,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/unreachable'),
          reason: 'Failed host lookup',
        ),
      ),
    );

    try {
      await dio.get('/unreachable');
      fail('Expected a DioException to be thrown');
    } on DioException catch (e) {
      expect(e.error, isA<NetworkFailure>());
    }
  });

  test('unparseable/unexpected body maps to UnknownFailure', () async {
    adapter.onGet(
      '/weird',
      (server) => server.reply(418, 'not-the-expected-envelope-shape'),
    );

    try {
      await dio.get('/weird');
      fail('Expected a DioException to be thrown');
    } on DioException catch (e) {
      expect(e.error, isA<UnknownFailure>());
    }
  });

  test('400 with no parseable envelope still maps to ValidationFailure', () async {
    adapter.onPost(
      '/register-broken-body',
      (server) => server.reply(400, 'this is not json shaped as expected'),
    );

    try {
      await dio.post('/register-broken-body');
      fail('Expected a DioException to be thrown');
    } on DioException catch (e) {
      final failure = e.error;
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).fields, isEmpty);
    }
  });
}
