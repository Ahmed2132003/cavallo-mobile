import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/push/fcm_service.dart';

import 'fake_push_messaging_client.dart';

/// Part P-112 STEP 4: device registration tells the backend the app language
/// (so push text can be rendered in it). The P-081 tests in
/// fcm_service_test.dart stay untouched: without a localeResolver the body is
/// exactly `{token, platform}`.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> requests;
  late FakePushMessagingClient client;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    requests = <RequestOptions>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.next(options);
        },
      ),
    );
    client = FakePushMessagingClient();
  });

  test('sends the active locale with the token and platform', () async {
    adapter.onPost(
      FcmService.registerPath,
      (server) => server.reply(201, {'id': 1, 'platform': 'android'}),
      data: {'token': 'tok-1', 'platform': 'android', 'locale': 'ar'},
    );

    final FcmService service = FcmService(
      client: client,
      dio: dio,
      platformResolver: () => 'android',
      localeResolver: () => 'ar',
    );
    final FcmInitResult result = await service.initialize();

    expect(result, FcmInitResult.registered);
    expect(requests.single.data, {
      'token': 'tok-1',
      'platform': 'android',
      'locale': 'ar',
    });
  });

  test('a failing locale resolver never blocks registration', () async {
    adapter.onPost(
      FcmService.registerPath,
      (server) => server.reply(201, {'id': 1, 'platform': 'android'}),
      data: {'token': 'tok-1', 'platform': 'android'},
    );

    final FcmService service = FcmService(
      client: client,
      dio: dio,
      platformResolver: () => 'android',
      localeResolver: () => throw StateError('no locale'),
    );
    final FcmInitResult result = await service.initialize();

    expect(result, FcmInitResult.registered);
    expect(requests.single.data, {'token': 'tok-1', 'platform': 'android'});
  });

  test('a null locale is left out of the body', () async {
    adapter.onPost(
      FcmService.registerPath,
      (server) => server.reply(201, {'id': 1, 'platform': 'android'}),
      data: {'token': 'tok-1', 'platform': 'android'},
    );

    final FcmService service = FcmService(
      client: client,
      dio: dio,
      platformResolver: () => 'android',
      localeResolver: () => null,
    );
    await service.initialize();

    expect(requests.single.data, {'token': 'tok-1', 'platform': 'android'});
  });
}
