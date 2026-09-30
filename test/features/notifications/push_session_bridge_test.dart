import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/push/fcm_service.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/notifications/presentation/push_session_bridge.dart';

import '../../core/push/fake_push_messaging_client.dart';

/// Part P-081 (STEP 4): the session -> FcmService bridge. The real
/// FcmService is replaced by a spy, so nothing here touches Firebase.
class _SpyFcmService extends FcmService {
  _SpyFcmService() : super(client: FakePushMessagingClient(), dio: Dio());

  int initializeCalls = 0;
  int stopCalls = 0;

  @override
  Future<FcmInitResult> initialize() async {
    initializeCalls++;
    return FcmInitResult.registered;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

/// A [SessionNotifier] that starts at a fixed value and lets a test move
/// the session around, exactly like the real notifier does on
/// login/logout (bare loading first, then data).
class _FakeSession extends SessionNotifier {
  _FakeSession(this._initial);

  final User? _initial;

  @override
  Future<User?> build() async => _initial;

  void setUser(User? user) => state = AsyncValue<User?>.data(user);

  void setLoading() => state = const AsyncValue<User?>.loading();
}

const _user = User(
  id: 1,
  email: 'test@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

Future<void> flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _SpyFcmService spy;

  ProviderContainer buildContainer(User? initialUser) {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _FakeSession(initialUser)),
        fcmServiceProvider.overrideWithValue(spy),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    spy = _SpyFcmService();
  });

  test('a session restored at cold start initializes push once', () async {
    final container = buildContainer(_user);

    container.read(pushSessionBridgeProvider);
    await container.read(sessionProvider.future);
    await flush();

    expect(spy.initializeCalls, 1);
    expect(spy.stopCalls, 0);
  });

  test('a signed-out start stops push and never initializes it', () async {
    final container = buildContainer(null);

    container.read(pushSessionBridgeProvider);
    await container.read(sessionProvider.future);
    await flush();

    expect(spy.initializeCalls, 0);
    expect(spy.stopCalls, 1);
  });

  test('logging in initializes push; the loading state does nothing', () async {
    final container = buildContainer(null);
    container.read(pushSessionBridgeProvider);
    await container.read(sessionProvider.future);
    await flush();
    final baselineStops = spy.stopCalls;

    final session = container.read(sessionProvider.notifier) as _FakeSession;
    session.setLoading();
    await flush();
    expect(spy.initializeCalls, 0);

    session.setUser(_user);
    await flush();

    expect(spy.initializeCalls, 1);
    expect(spy.stopCalls, baselineStops);
  });

  test('logging out stops push', () async {
    final container = buildContainer(_user);
    container.read(pushSessionBridgeProvider);
    await container.read(sessionProvider.future);
    await flush();
    expect(spy.initializeCalls, 1);

    final session = container.read(sessionProvider.notifier) as _FakeSession;
    session.setLoading();
    await flush();
    expect(spy.stopCalls, 0);

    session.setUser(null);
    await flush();

    expect(spy.stopCalls, 1);
    expect(spy.initializeCalls, 1);
  });

  testWidgets('PushSessionBridge activates the bridge and renders its child', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _FakeSession(_user)),
          fcmServiceProvider.overrideWithValue(spy),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: PushSessionBridge(child: Text('app child')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('app child'), findsOneWidget);
    expect(spy.initializeCalls, 1);
  });
}
