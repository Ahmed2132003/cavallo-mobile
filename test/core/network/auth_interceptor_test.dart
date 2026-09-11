import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/interceptors/auth_interceptor.dart';

void main() {
  test('attaches Authorization: Bearer <token> when a token is available', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    RequestOptions? seenByServer;
    adapter.onGet('/secure', (server) => server.reply(200, {'ok': true}));

    dio.interceptors.add(AuthInterceptor(getToken: () async => 'abc123'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          seenByServer = options;
          handler.next(options);
        },
      ),
    );

    await dio.get('/secure');

    expect(seenByServer?.headers['Authorization'], 'Bearer abc123');
  });

  test('does not attach an Authorization header when the token is null', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    RequestOptions? seenByServer;
    adapter.onGet('/public', (server) => server.reply(200, {'ok': true}));

    dio.interceptors.add(AuthInterceptor(getToken: () async => null));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          seenByServer = options;
          handler.next(options);
        },
      ),
    );

    await dio.get('/public');

    expect(seenByServer?.headers.containsKey('Authorization'), isFalse);
  });

  test('does not attach an Authorization header when the token is empty', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    RequestOptions? seenByServer;
    adapter.onGet('/public2', (server) => server.reply(200, {'ok': true}));

    dio.interceptors.add(AuthInterceptor(getToken: () async => ''));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          seenByServer = options;
          handler.next(options);
        },
      ),
    );

    await dio.get('/public2');

    expect(seenByServer?.headers.containsKey('Authorization'), isFalse);
  });
}
