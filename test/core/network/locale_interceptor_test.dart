import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/interceptors/locale_interceptor.dart';

/// Part P-112 STEP 4: Accept-Language on every request.
void main() {
  Future<RequestOptions?> send(
    String Function() getLanguageCode, {
    Map<String, dynamic>? headers,
  }) async {
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final DioAdapter adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    adapter.onGet('/ping', (server) => server.reply(200, {'ok': true}));

    RequestOptions? seenByServer;
    dio.interceptors.add(LocaleInterceptor(getLanguageCode: getLanguageCode));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          seenByServer = options;
          handler.next(options);
        },
      ),
    );

    await dio.get('/ping', options: Options(headers: headers));
    return seenByServer;
  }

  test('adds Accept-Language: ar', () async {
    final RequestOptions? seen = await send(() => 'ar');
    expect(seen?.headers['Accept-Language'], 'ar');
  });

  test('adds Accept-Language: en', () async {
    final RequestOptions? seen = await send(() => 'en');
    expect(seen?.headers['Accept-Language'], 'en');
  });

  test('reads the language at request time, not at construction', () async {
    String current = 'ar';
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final DioAdapter adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    adapter.onGet('/ping', (server) => server.reply(200, {'ok': true}));

    final List<Object?> seen = <Object?>[];
    dio.interceptors.add(LocaleInterceptor(getLanguageCode: () => current));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          seen.add(options.headers['Accept-Language']);
          handler.next(options);
        },
      ),
    );

    await dio.get('/ping');
    current = 'en';
    await dio.get('/ping');

    expect(seen, <Object?>['ar', 'en']);
  });

  test('a header the caller set explicitly is not overwritten', () async {
    final RequestOptions? seen = await send(
      () => 'ar',
      headers: <String, dynamic>{'Accept-Language': 'en'},
    );
    expect(seen?.headers['Accept-Language'], 'en');
  });

  test('a failing getter never blocks the request', () async {
    final RequestOptions? seen = await send(() => throw StateError('boom'));
    expect(seen, isNotNull);
    expect(seen?.headers.containsKey('Accept-Language'), isFalse);
  });

  test('an empty language code adds no header', () async {
    final RequestOptions? seen = await send(() => '');
    expect(seen?.headers.containsKey('Accept-Language'), isFalse);
  });
}
