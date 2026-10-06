import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';

/// Part P-112 STEP 4: every ApiFailure carries the stable error code.
void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());
  });

  Future<ApiFailure> failureOf(String path) async {
    try {
      await dio.get<dynamic>(path);
    } on DioException catch (e) {
      return e.error as ApiFailure;
    }
    fail('Expected a DioException to be thrown');
  }

  Map<String, dynamic> envelope(String code) => <String, dynamic>{
    'error': <String, dynamic>{'code': code, 'message': 'raw english'},
  };

  test('400 keeps the backend code', () async {
    adapter.onGet('/a', (s) => s.reply(400, envelope('VALIDATION_ERROR')));
    final ApiFailure f = await failureOf('/a');
    expect(f, isA<ValidationFailure>());
    expect(f.code, 'VALIDATION_ERROR');
  });

  test('403 keeps the backend code', () async {
    adapter.onGet('/b', (s) => s.reply(403, envelope('PERMISSION_DENIED')));
    final ApiFailure f = await failureOf('/b');
    expect(f, isA<AuthFailure>());
    expect(f.code, 'PERMISSION_DENIED');
  });

  test('429 keeps THROTTLED even though it is an UnknownFailure', () async {
    adapter.onGet('/c', (s) => s.reply(429, envelope('THROTTLED')));
    final ApiFailure f = await failureOf('/c');
    expect(f, isA<UnknownFailure>());
    expect(f.code, 'THROTTLED');
  });

  test('503 keeps SERVICE_UNAVAILABLE', () async {
    adapter.onGet('/d', (s) => s.reply(503, envelope('SERVICE_UNAVAILABLE')));
    final ApiFailure f = await failureOf('/d');
    expect(f, isA<ServerFailure>());
    expect(f.code, 'SERVICE_UNAVAILABLE');
  });

  test('a response without an envelope has no code', () async {
    adapter.onGet('/e', (s) => s.reply(500, <String, dynamic>{}));
    final ApiFailure f = await failureOf('/e');
    expect(f, isA<ServerFailure>());
    expect(f.code, isNull);
  });

  test('a connection error gets the client-side NETWORK_ERROR code', () async {
    adapter.onGet(
      '/f',
      (s) => s.throws(
        0,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/f'),
          reason: 'Failed host lookup',
        ),
      ),
    );
    final ApiFailure f = await failureOf('/f');
    expect(f, isA<NetworkFailure>());
    expect(f.code, ApiErrorCodes.networkError);
  });
}
