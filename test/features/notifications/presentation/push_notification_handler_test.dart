import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/push/fcm_service.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/notifications/data/notification_repository_impl.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_navigator.dart';
import 'package:social_commerce_app/features/notifications/presentation/push_notification_handler.dart';

import '../../../core/push/fake_push_messaging_client.dart';
import '../fake_notification_repository.dart';

/// Part P-082 (STEP 6): foreground banner + tap handling. The
/// FcmService streams and the navigator are replaced, so nothing here
/// touches Firebase or a real router.
class _FakeFcm extends FcmService {
  _FakeFcm() : super(client: FakePushMessagingClient(), dio: Dio());

  final foreground = StreamController<PushMessage>.broadcast();
  final tapController = StreamController<PushDeepLink>.broadcast();
  final pending = <PushDeepLink>[];

  @override
  Stream<PushMessage> get foregroundMessages => foreground.stream;

  @override
  Stream<PushDeepLink> get taps => tapController.stream;

  @override
  List<PushDeepLink> takePendingTaps() {
    final taps = List<PushDeepLink>.of(pending);
    pending.clear();
    return taps;
  }
}

class _SpyNavigator extends NotificationNavigator {
  _SpyNavigator()
    : super(
        router: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const SizedBox()),
          ],
        ),
        conversationRepository: ConversationRepository(Dio()),
      );

  final opened = <PushDeepLink>[];

  @override
  Future<void> openPush(PushDeepLink link) async {
    opened.add(link);
  }
}

const _chatMessage = PushMessage(
  title: 'New message',
  body: 'Hello there',
  data: {
    'deep_link_type': 'chat_thread',
    'target_id': '101',
    'notification_id': '7',
  },
);

Future<void> _pump(
  WidgetTester tester, {
  required _FakeFcm fcm,
  required _SpyNavigator navigator,
  required FakeNotificationRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fcmServiceProvider.overrideWithValue(fcm),
        notificationNavigatorProvider.overrideWithValue(navigator),
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
      child: PushNotificationHandler(
        child: Consumer(
          builder:
              (context, ref, _) => MaterialApp(
                scaffoldMessengerKey: ref.watch(
                  rootScaffoldMessengerKeyProvider,
                ),
                home: const Scaffold(body: Text('home')),
              ),
        ),
      ),
    ),
  );
}

/// Lets stream events, the first-frame wait and the navigation finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Shows the banner for [message] and lets its slide-in animation finish.
Future<void> _showBanner(
  WidgetTester tester,
  _FakeFcm fcm,
  PushMessage message,
) async {
  fcm.foreground.add(message);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late _FakeFcm fcm;
  late _SpyNavigator navigator;
  late FakeNotificationRepository repository;

  setUp(() {
    fcm = _FakeFcm();
    navigator = _SpyNavigator();
    repository = FakeNotificationRepository();
  });

  testWidgets('a foreground push shows a banner with its title and body', (
    tester,
  ) async {
    await _pump(tester, fcm: fcm, navigator: navigator, repository: repository);

    await _showBanner(tester, fcm, _chatMessage);

    expect(find.text('New message'), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);
    expect(navigator.opened, isEmpty);
  });

  testWidgets('tapping the banner opens the deep link and marks it read', (
    tester,
  ) async {
    await _pump(tester, fcm: fcm, navigator: navigator, repository: repository);
    await _showBanner(tester, fcm, _chatMessage);

    await tester.tap(find.byKey(const ValueKey('push-banner')));
    await _settle(tester);

    expect(navigator.opened, hasLength(1));
    expect(navigator.opened.single.type, 'chat_thread');
    expect(navigator.opened.single.targetId, 101);
    expect(repository.markReadCalls, [7]);
  });

  testWidgets('a background tap opens the deep link through the navigator', (
    tester,
  ) async {
    await _pump(tester, fcm: fcm, navigator: navigator, repository: repository);

    fcm.tapController.add(
      const PushDeepLink(
        type: 'business_profile',
        targetId: 5,
        notificationId: 9,
      ),
    );
    await _settle(tester);

    expect(navigator.opened, hasLength(1));
    expect(navigator.opened.single.type, 'business_profile');
    expect(navigator.opened.single.targetId, 5);
    expect(repository.markReadCalls, [9]);
  });

  testWidgets('a tap that launched the app is opened once on start', (
    tester,
  ) async {
    fcm.pending.add(const PushDeepLink(type: 'post', targetId: 3));

    await _pump(tester, fcm: fcm, navigator: navigator, repository: repository);
    await _settle(tester);

    expect(navigator.opened, hasLength(1));
    expect(navigator.opened.single.type, 'post');
    expect(navigator.opened.single.targetId, 3);
    expect(repository.markReadCalls, isEmpty);
    expect(fcm.pending, isEmpty);
  });

  testWidgets('a banner without a deep link has no action and opens nothing', (
    tester,
  ) async {
    await _pump(tester, fcm: fcm, navigator: navigator, repository: repository);

    await _showBanner(
      tester,
      fcm,
      const PushMessage(title: 'Announcement', body: 'Maintenance tonight'),
    );

    expect(find.text('Announcement'), findsOneWidget);
    expect(find.text('View'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('push-banner')));
    await _settle(tester);

    expect(navigator.opened, isEmpty);
  });

  testWidgets('a message with no title and no body shows no banner', (
    tester,
  ) async {
    await _pump(tester, fcm: fcm, navigator: navigator, repository: repository);

    await _showBanner(
      tester,
      fcm,
      const PushMessage(data: {'deep_link_type': 'post', 'target_id': '1'}),
    );

    expect(find.byType(SnackBar), findsNothing);
  });
}
