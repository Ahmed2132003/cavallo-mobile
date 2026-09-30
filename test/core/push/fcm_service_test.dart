import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/deep_link_resolver.dart';
import 'package:social_commerce_app/core/network/dio_client.dart';
import 'package:social_commerce_app/core/push/fcm_service.dart';

import 'fake_push_messaging_client.dart';

/// Part P-081 (STEP 3 + STEP 4). Uses a plain fake [PushMessagingClient]
/// and a mocked Dio adapter — no real Firebase project, no network.

/// The data payload the backend really sends for a chat notification
/// (`notifications.services.send_push_notification`, all strings).
const _chatData = <String, String>{
  'type': 'chat_message',
  'notification_id': '5',
  'deep_link_type': 'chat_thread',
  'target_id': '9',
};

Future<void> flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> requests;
  late FakePushMessagingClient client;

  void stubRegister(String token, String platform, {int status = 201}) {
    adapter.onPost(
      FcmService.registerPath,
      (server) => server.reply(status, {'id': 1, 'platform': platform}),
      data: {'token': token, 'platform': platform},
    );
  }

  FcmService buildService({String? Function()? platform}) => FcmService(
    client: client,
    dio: dio,
    platformResolver: platform ?? () => 'android',
  );

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    requests = [];
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

  group('initialize', () {
    test('registers the token with the backend', () async {
      stubRegister('tok-1', 'android');

      final result = await buildService().initialize();

      expect(result, FcmInitResult.registered);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/api/v1/devices/register/');
      expect(requests.single.data, {'token': 'tok-1', 'platform': 'android'});
      expect(client.permissionCalls, 1);
    });

    test('sends platform "ios" when running on iOS', () async {
      stubRegister('tok-1', 'ios');

      final result = await buildService(platform: () => 'ios').initialize();

      expect(result, FcmInitResult.registered);
      expect(requests.single.data, {'token': 'tok-1', 'platform': 'ios'});
    });

    test('unsupported platform never touches Firebase', () async {
      final result = await buildService(platform: () => null).initialize();

      expect(result, FcmInitResult.unsupportedPlatform);
      expect(client.ensureInitializedCalls, 0);
      expect(requests, isEmpty);
    });

    test('Firebase not configured is a safe no-op', () async {
      client.configured = false;

      final result = await buildService().initialize();

      expect(result, FcmInitResult.notConfigured);
      expect(client.permissionCalls, 0);
      expect(requests, isEmpty);
    });

    test('denied permission registers nothing', () async {
      client.permissionGranted = false;

      final result = await buildService().initialize();

      expect(result, FcmInitResult.permissionDenied);
      expect(client.getTokenCalls, 0);
      expect(requests, isEmpty);
    });

    test('a null token registers nothing', () async {
      client.token = null;

      final result = await buildService().initialize();

      expect(result, FcmInitResult.noToken);
      expect(requests, isEmpty);
    });

    test('a backend failure is reported, not thrown', () async {
      stubRegister('tok-1', 'android', status: 500);

      final result = await buildService().initialize();

      expect(result, FcmInitResult.registrationFailed);
    });

    test('stop() during the permission prompt abandons initialize', () async {
      client.permissionGate = Completer<bool>();
      final service = buildService();

      final pending = service.initialize();
      await flush();
      await service.stop();
      client.permissionGate!.complete(true);

      expect(await pending, FcmInitResult.stopped);
      expect(requests, isEmpty);
      expect(client.refresh.hasListener, isFalse);
      expect(client.foreground.hasListener, isFalse);
      expect(client.openedApp.hasListener, isFalse);
    });
  });

  group('token refresh', () {
    test('re-registers every rotated token', () async {
      stubRegister('tok-1', 'android');
      stubRegister('tok-2', 'android');
      stubRegister('tok-3', 'android');
      await buildService().initialize();

      client.refresh.add('tok-2');
      await flush();
      client.refresh.add('tok-3');
      await flush();

      expect(requests.map((r) => (r.data as Map)['token']), [
        'tok-1',
        'tok-2',
        'tok-3',
      ]);
    });

    test('a failing refresh registration does not crash', () async {
      stubRegister('tok-1', 'android');
      stubRegister('tok-2', 'android', status: 500);
      stubRegister('tok-3', 'android');
      await buildService().initialize();

      client.refresh.add('tok-2');
      await flush();
      client.refresh.add('tok-3');
      await flush();

      expect(requests, hasLength(3));
    });

    test('a backend failure at launch still listens for refresh', () async {
      stubRegister('tok-1', 'android', status: 500);
      stubRegister('tok-2', 'android');
      await buildService().initialize();

      client.refresh.add('tok-2');
      await flush();

      expect(requests, hasLength(2));
    });

    test('calling initialize twice never stacks refresh listeners', () async {
      stubRegister('tok-1', 'android');
      stubRegister('tok-2', 'android');
      final service = buildService();
      await service.initialize();
      await service.initialize();
      expect(requests, hasLength(2));

      client.refresh.add('tok-2');
      await flush();

      // One extra request (3 total), not two (4).
      expect(requests, hasLength(3));
    });

    test('stop() cancels the refresh listener', () async {
      stubRegister('tok-1', 'android');
      stubRegister('tok-2', 'android');
      final service = buildService();
      await service.initialize();
      expect(client.refresh.hasListener, isTrue);

      await service.stop();
      client.refresh.add('tok-2');
      await flush();

      expect(client.refresh.hasListener, isFalse);
      expect(requests, hasLength(1));
    });
  });

  group('foreground messages', () {
    test('a foreground message reaches foregroundMessages', () async {
      stubRegister('tok-1', 'android');
      final service = buildService();
      await service.initialize();
      final received = <PushMessage>[];
      service.foregroundMessages.listen(received.add);

      client.foreground.add(
        const PushMessage(title: 'New message', body: 'hello', data: _chatData),
      );
      await flush();

      expect(received, hasLength(1));
      expect(received.single.title, 'New message');
      expect(received.single.body, 'hello');
      expect(received.single.data['deep_link_type'], 'chat_thread');
    });

    test('calling initialize twice does not duplicate messages', () async {
      stubRegister('tok-1', 'android');
      final service = buildService();
      await service.initialize();
      await service.initialize();
      final received = <PushMessage>[];
      service.foregroundMessages.listen(received.add);

      client.foreground.add(const PushMessage(title: 'Once'));
      await flush();

      expect(received, hasLength(1));
    });

    test('stop() stops foreground messages', () async {
      stubRegister('tok-1', 'android');
      final service = buildService();
      await service.initialize();
      final received = <PushMessage>[];
      service.foregroundMessages.listen(received.add);

      await service.stop();
      client.foreground.add(const PushMessage(title: 'Late'));
      await flush();

      expect(client.foreground.hasListener, isFalse);
      expect(received, isEmpty);
    });

    test('denied permission never subscribes to messages', () async {
      client.permissionGranted = false;

      await buildService().initialize();

      expect(client.foreground.hasListener, isFalse);
      expect(client.openedApp.hasListener, isFalse);
    });
  });

  group('notification taps', () {
    test(
      'a background tap is emitted live with the parsed deep link',
      () async {
        stubRegister('tok-1', 'android');
        final service = buildService();
        await service.initialize();
        final taps = <PushDeepLink>[];
        service.taps.listen(taps.add);

        client.openedApp.add(const PushMessage(data: _chatData));
        await flush();

        expect(taps, hasLength(1));
        expect(taps.single.type, 'chat_thread');
        expect(taps.single.targetId, 9);
        expect(taps.single.notificationId, 5);
        expect(taps.single.route, resolveDeepLink('chat_thread', 9));
        expect(service.takePendingTaps(), isEmpty);
      },
    );

    test('a tap with no listener is queued, then drained once', () async {
      stubRegister('tok-1', 'android');
      final service = buildService();
      await service.initialize();

      client.openedApp.add(const PushMessage(data: _chatData));
      await flush();

      final pending = service.takePendingTaps();
      expect(pending, hasLength(1));
      expect(pending.single.type, 'chat_thread');
      expect(pending.single.targetId, 9);
      expect(service.takePendingTaps(), isEmpty);
    });

    test('a tap without a deep link is ignored', () async {
      stubRegister('tok-1', 'android');
      final service = buildService();
      await service.initialize();
      final taps = <PushDeepLink>[];
      service.taps.listen(taps.add);

      client.openedApp.add(
        const PushMessage(
          data: {
            'type': 'system',
            'deep_link_type': '',
            'notification_id': '8',
          },
        ),
      );
      await flush();

      expect(taps, isEmpty);
      expect(service.takePendingTaps(), isEmpty);
    });

    test('a non-numeric target_id resolves to the fallback route', () async {
      stubRegister('tok-1', 'android');
      final service = buildService();
      await service.initialize();
      final taps = <PushDeepLink>[];
      service.taps.listen(taps.add);

      client.openedApp.add(
        const PushMessage(
          data: {'deep_link_type': 'chat_thread', 'target_id': 'abc'},
        ),
      );
      await flush();

      expect(taps.single.targetId, isNull);
      expect(taps.single.route, deepLinkFallbackRoute);
    });

    test(
      'the notification that launched the app is queued once per launch',
      () async {
        client.initialMessage = const PushMessage(data: _chatData);
        stubRegister('tok-1', 'android');
        final service = buildService();

        await service.initialize();
        await service.initialize();

        expect(client.initialMessageCalls, 1);
        final pending = service.takePendingTaps();
        expect(pending, hasLength(1));
        expect(pending.single.type, 'chat_thread');
        expect(pending.single.targetId, 9);
        expect(service.takePendingTaps(), isEmpty);
      },
    );

    test('a launch message without a deep link queues nothing', () async {
      client.initialMessage = const PushMessage(data: {'type': 'system'});
      stubRegister('tok-1', 'android');
      final service = buildService();

      await service.initialize();

      expect(service.takePendingTaps(), isEmpty);
    });

    test('stop() drops queued taps', () async {
      client.initialMessage = const PushMessage(data: _chatData);
      stubRegister('tok-1', 'android');
      final service = buildService();
      await service.initialize();

      await service.stop();

      expect(service.takePendingTaps(), isEmpty);
    });
  });

  group('PushDeepLink.fromData', () {
    test('parses type, target_id and notification_id', () {
      final link = PushDeepLink.fromData(_chatData)!;

      expect(link.type, 'chat_thread');
      expect(link.targetId, 9);
      expect(link.notificationId, 5);
    });

    test('a missing deep_link_type means no deep link', () {
      expect(PushDeepLink.fromData(const {'type': 'system'}), isNull);
    });

    test('a blank deep_link_type means no deep link', () {
      expect(PushDeepLink.fromData(const {'deep_link_type': '   '}), isNull);
    });

    test('a missing target_id keeps the link but resolves to fallback', () {
      final link =
          PushDeepLink.fromData(const {'deep_link_type': 'business_profile'})!;

      expect(link.targetId, isNull);
      expect(link.route, deepLinkFallbackRoute);
    });
  });

  group('pushMessageFromRemote', () {
    test('maps the notification and stringifies the data', () {
      final message = pushMessageFromRemote(
        const RemoteMessage(
          notification: RemoteNotification(title: 'New message', body: 'hello'),
          data: {'target_id': 9, 'deep_link_type': 'chat_thread'},
        ),
      );

      expect(message.title, 'New message');
      expect(message.body, 'hello');
      expect(message.data, {'target_id': '9', 'deep_link_type': 'chat_thread'});
    });
  });

  group('fcmServiceProvider', () {
    test('builds an FcmService and disposes it with the container', () async {
      stubRegister('tok-1', 'android');
      final container = ProviderContainer(
        overrides: [
          pushMessagingClientProvider.overrideWithValue(client),
          dioClientProvider.overrideWithValue(dio),
        ],
      );

      final service = container.read(fcmServiceProvider);
      expect(service, isA<FcmService>());

      // Real platform resolver: in flutter test the default target
      // platform is android, so this registers.
      await service.initialize();
      expect(client.refresh.hasListener, isTrue);

      container.dispose();
      await flush();

      expect(client.refresh.hasListener, isFalse);
      expect(client.foreground.hasListener, isFalse);
      expect(client.openedApp.hasListener, isFalse);
    });
  });
}
