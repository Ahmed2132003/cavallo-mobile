import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/chat/chat_connection_manager.dart';
import 'package:social_commerce_app/core/chat/chat_event.dart';

/// A [ChatSocket] fake — unchanged from STEP 2, plus
/// [simulateUnexpectedClose] (STEP 3): closes the incoming stream
/// *without* going through the manager's own [ChatSocket.close] call,
/// simulating a server/network-initiated drop rather than a deliberate
/// [ChatConnectionManager.disconnect].
class FakeChatSocket implements ChatSocket {
  final _incoming = StreamController<dynamic>.broadcast();
  final List<dynamic> sent = [];
  bool closed = false;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  void add(dynamic data) => sent.add(data);

  @override
  Future<void> close() async {
    closed = true;
    await _incoming.close();
  }

  void emit(String rawText) => _incoming.add(rawText);

  /// STEP 3 test helper: the server/network dropped the connection —
  /// distinct from [close], which is what the manager itself calls on a
  /// *deliberate* disconnect.
  void simulateUnexpectedClose() => _incoming.close();
}

/// STEP 3 test helper: records every scheduled reconnect delay and lets
/// the test fire the pending callback manually — avoids waiting real
/// seconds and avoids leaking a real pending [Timer] into the test
/// process. Returns a harmless, near-instant real [Timer] purely so
/// `ChatConnectionManager`'s `_reconnectTimer?.cancel()` calls have a
/// real object to call `.cancel()` on; firing is controlled entirely via
/// [fireNext], never by that dummy timer actually elapsing.
class FakeReconnectScheduler {
  final List<Duration> scheduledDelays = [];
  void Function()? _pendingCallback;

  Timer call(Duration delay, void Function() callback) {
    scheduledDelays.add(delay);
    _pendingCallback = callback;
    return Timer(Duration.zero, () {});
  }

  void fireNext() {
    final callback = _pendingCallback;
    _pendingCallback = null;
    callback?.call();
  }
}

/// STEP 3 test helper for the heartbeat timer — same shape as
/// [FakeReconnectScheduler] but matching [PeriodicTimerFactory]'s
/// signature. The dummy [Timer] it returns uses a long (10-minute)
/// duration specifically so the "disconnect() cancels the heartbeat
/// timer" test can check [Timer.isActive] and know a `false` result
/// came from an explicit `.cancel()` call, not from the dummy timer
/// having simply elapsed on its own.
class FakePeriodicScheduler {
  Duration? capturedPeriod;
  Timer? lastTimer;
  void Function(Timer)? _callback;

  Timer call(Duration period, void Function(Timer) callback) {
    capturedPeriod = period;
    _callback = callback;
    final timer = Timer(const Duration(minutes: 10), () {});
    lastTimer = timer;
    return timer;
  }

  void fire() {
    final callback = _callback;
    if (callback != null) callback(Timer(Duration.zero, () {}));
  }
}

/// STEP 3: the default `reconnectScheduler`/`periodicTimerFactory` used
/// by [buildManager] below when a test doesn't care about
/// reconnection/heartbeat behavior — every one of STEP 1/STEP 2's
/// original tests, plus most of this file's own new tests, falls into
/// that category. Both simply ignore the callback they're given and
/// return a near-instant, harmless dummy [Timer] — guaranteeing none of
/// those tests ever leaks a real, long-lived pending [Timer] (in
/// particular, the 30-second heartbeat timer that now starts on every
/// successful `connect()`) into the test process.
Timer _inertReconnectScheduler(Duration delay, void Function() callback) =>
    Timer(Duration.zero, () {});

Timer _inertPeriodicTimerFactory(
  Duration period,
  void Function(Timer) callback,
) =>
    Timer(Duration.zero, () {});

void main() {
  late List<FakeChatSocket> createdSockets;
  late List<Uri> capturedUris;
  late String? tokenToReturn;

  ChatConnectionManager buildManager({
    String apiBaseUrl = 'http://10.0.2.2:8095',
    ReconnectScheduler? reconnectScheduler,
    PeriodicTimerFactory? periodicTimerFactory,
  }) {
    return ChatConnectionManager(
      getAccessToken: () async => tokenToReturn,
      getApiBaseUrl: () => apiBaseUrl,
      socketFactory: (uri) {
        capturedUris.add(uri);
        final socket = FakeChatSocket();
        createdSockets.add(socket);
        return socket;
      },
      reconnectScheduler: reconnectScheduler ?? _inertReconnectScheduler,
      periodicTimerFactory: periodicTimerFactory ?? _inertPeriodicTimerFactory,
    );
  }

  setUp(() {
    createdSockets = [];
    capturedUris = [];
    tokenToReturn = 'test-access-token';
  });

  group('connect() — URL construction', () {
    test(
      'uses ws:// + the /ws/conversations/<id>/ path for an http apiBaseUrl',
      () async {
        final manager = buildManager(apiBaseUrl: 'http://10.0.2.2:8095');
        await manager.connect(7);

        expect(capturedUris, hasLength(1));
        final uri = capturedUris.single;
        expect(uri.scheme, 'ws');
        expect(uri.host, '10.0.2.2');
        expect(uri.port, 8095);
        expect(uri.path, '/ws/conversations/7/');
        expect(uri.queryParameters['token'], 'test-access-token');
      },
    );

    test('uses wss:// for an https apiBaseUrl', () async {
      final manager = buildManager(apiBaseUrl: 'https://api.example.com');
      await manager.connect(3);

      final uri = capturedUris.single;
      expect(uri.scheme, 'wss');
      expect(uri.host, 'api.example.com');
      expect(uri.path, '/ws/conversations/3/');
    });
  });

  group('connect()/disconnect() — state tracking', () {
    test('transitions disconnected -> connecting -> connected', () async {
      final manager = buildManager();
      expect(manager.currentState, ChatConnectionState.disconnected);

      final statesExpectation = expectLater(
        manager.connectionState,
        emitsInOrder([
          ChatConnectionState.connecting,
          ChatConnectionState.connected,
        ]),
      );

      await manager.connect(1);
      await statesExpectation;

      expect(manager.currentState, ChatConnectionState.connected);
      expect(manager.activeConversationId, 1);
    });

    test('disconnect() closes the socket and returns to disconnected', () async {
      final manager = buildManager();
      await manager.connect(1);
      final socket = createdSockets.single;

      await manager.disconnect();

      expect(socket.closed, isTrue);
      expect(manager.currentState, ChatConnectionState.disconnected);
      expect(manager.activeConversationId, isNull);
    });

    test('disconnect() when never connected is a no-op', () async {
      final manager = buildManager();
      await manager.disconnect();
      expect(manager.currentState, ChatConnectionState.disconnected);
    });

    test('connect() with the same conversationId while connected is a no-op', () async {
      final manager = buildManager();
      await manager.connect(1);
      await manager.connect(1);

      expect(createdSockets, hasLength(1));
    });

    test(
      'connect() with a different conversationId closes the old socket first',
      () async {
        final manager = buildManager();
        await manager.connect(1);
        final firstSocket = createdSockets.single;

        await manager.connect(2);

        expect(firstSocket.closed, isTrue);
        expect(createdSockets, hasLength(2));
        expect(manager.activeConversationId, 2);
        expect(manager.currentState, ChatConnectionState.connected);
      },
    );

    test('connect() throws StateError when no access token is available', () async {
      tokenToReturn = null;
      final manager = buildManager();

      await expectLater(() => manager.connect(1), throwsA(isA<StateError>()));
      expect(manager.currentState, ChatConnectionState.disconnected);
      expect(manager.activeConversationId, isNull);
      expect(createdSockets, isEmpty);
    });
  });

  group('incoming frame parsing -> eventStream', () {
    test('a chat_message frame is parsed and emitted as MessageReceived', () async {
      final manager = buildManager();
      await manager.connect(1);
      final socket = createdSockets.single;

      final future = expectLater(
        manager.eventStream,
        emits(isA<MessageReceived>()),
      );
      socket.emit(
        jsonEncode({
          'id': 42,
          'conversation': 1,
          'sender': 9,
          'text': 'hi',
          'status': 'sent',
          'created_at': '2026-01-15T10:30:00Z',
        }),
      );
      await future;
    });

    test('a status_update frame is parsed and emitted as StatusUpdate', () async {
      final manager = buildManager();
      await manager.connect(1);
      final socket = createdSockets.single;

      final future = expectLater(manager.eventStream, emits(isA<StatusUpdate>()));
      socket.emit(jsonEncode({'message_id': 5, 'status': 'read'}));
      await future;
    });

    test(
      'a typing_indicator frame is parsed and emitted as TypingIndicator',
      () async {
        final manager = buildManager();
        await manager.connect(1);
        final socket = createdSockets.single;

        final future = expectLater(
          manager.eventStream,
          emits(isA<TypingIndicator>()),
        );
        socket.emit(jsonEncode({'is_typing': true}));
        await future;
      },
    );

    test(
      'a malformed frame is dropped silently — a later well-formed frame '
      'still arrives',
      () async {
        final manager = buildManager();
        await manager.connect(1);
        final socket = createdSockets.single;

        final future = expectLater(
          manager.eventStream,
          emits(isA<TypingIndicator>()),
        );

        socket.emit('not even json {{{');
        socket.emit(jsonEncode({'unexpected': 'shape'}));
        socket.emit(jsonEncode({'is_typing': false}));

        await future;
      },
    );
  });

  group('reconnection — exponential backoff (STEP 3)', () {
    test('backoffDelayForAttempt follows the doubling pattern, capped at 30s', () {
      expect(
        ChatConnectionManager.backoffDelayForAttempt(1),
        const Duration(seconds: 1),
      );
      expect(
        ChatConnectionManager.backoffDelayForAttempt(2),
        const Duration(seconds: 2),
      );
      expect(
        ChatConnectionManager.backoffDelayForAttempt(3),
        const Duration(seconds: 4),
      );
      expect(
        ChatConnectionManager.backoffDelayForAttempt(4),
        const Duration(seconds: 8),
      );
      expect(
        ChatConnectionManager.backoffDelayForAttempt(5),
        const Duration(seconds: 16),
      );
      expect(
        ChatConnectionManager.backoffDelayForAttempt(6),
        const Duration(seconds: 30),
      );
      expect(
        ChatConnectionManager.backoffDelayForAttempt(50),
        const Duration(seconds: 30),
      );
    });

    test(
      'an unexpected close moves to reconnecting and schedules the first '
      'backoff attempt at 1s',
      () async {
        final scheduler = FakeReconnectScheduler();
        final manager = buildManager(reconnectScheduler: scheduler.call);
        await manager.connect(1);
        final socket = createdSockets.single;

        final stateExpectation = expectLater(
          manager.connectionState,
          emits(ChatConnectionState.reconnecting),
        );

        socket.simulateUnexpectedClose();
        await stateExpectation;

        expect(scheduler.scheduledDelays, [const Duration(seconds: 1)]);
        expect(manager.reconnectAttempt, 1);
      },
    );

    test(
      'deliberate disconnect() while waiting to reconnect prevents the '
      'pending reconnect attempt from doing anything',
      () async {
        final scheduler = FakeReconnectScheduler();
        final manager = buildManager(reconnectScheduler: scheduler.call);
        await manager.connect(1);
        final firstSocket = createdSockets.single;

        final reconnectingExpectation = expectLater(
          manager.connectionState,
          emits(ChatConnectionState.reconnecting),
        );
        firstSocket.simulateUnexpectedClose();
        await reconnectingExpectation;

        await manager.disconnect();
        expect(manager.currentState, ChatConnectionState.disconnected);

        // Even if the (already-cancelled) backoff timer's callback were
        // to fire now, the internal _deliberateDisconnect guard must
        // stop it from opening a new socket.
        scheduler.fireNext();
        await Future<void>.delayed(Duration.zero);

        expect(createdSockets, hasLength(1));
        expect(manager.currentState, ChatConnectionState.disconnected);
      },
    );

    test(
      'a successful automatic reconnect resets the backoff attempt '
      'counter for the next unexpected close',
      () async {
        final scheduler = FakeReconnectScheduler();
        final manager = buildManager(reconnectScheduler: scheduler.call);
        await manager.connect(1);
        final firstSocket = createdSockets.single;

        firstSocket.simulateUnexpectedClose();
        await Future<void>.delayed(Duration.zero);
        expect(scheduler.scheduledDelays, [const Duration(seconds: 1)]);

        final connectedExpectation = expectLater(
          manager.connectionState,
          emits(ChatConnectionState.connected),
        );
        scheduler.fireNext();
        await connectedExpectation;

        expect(createdSockets, hasLength(2));
        expect(manager.reconnectAttempt, 0);

        final secondSocket = createdSockets[1];
        secondSocket.simulateUnexpectedClose();
        await Future<void>.delayed(Duration.zero);

        expect(scheduler.scheduledDelays, [
          const Duration(seconds: 1),
          const Duration(seconds: 1),
        ]);
      },
    );

    test(
      'repeated failed reconnect attempts escalate the backoff delay '
      'without ever opening a new socket',
      () async {
        final scheduler = FakeReconnectScheduler();
        final manager = buildManager(reconnectScheduler: scheduler.call);
        await manager.connect(1);
        final firstSocket = createdSockets.single;

        tokenToReturn = null; // every retry from here on fails

        firstSocket.simulateUnexpectedClose();
        await Future<void>.delayed(Duration.zero);
        expect(scheduler.scheduledDelays, [const Duration(seconds: 1)]);

        scheduler.fireNext();
        await Future<void>.delayed(Duration.zero);
        expect(scheduler.scheduledDelays, [
          const Duration(seconds: 1),
          const Duration(seconds: 2),
        ]);

        scheduler.fireNext();
        await Future<void>.delayed(Duration.zero);
        expect(scheduler.scheduledDelays, [
          const Duration(seconds: 1),
          const Duration(seconds: 2),
          const Duration(seconds: 4),
        ]);

        expect(createdSockets, hasLength(1));
        expect(manager.currentState, ChatConnectionState.reconnecting);
      },
    );
  });

  group('heartbeat (STEP 3)', () {
    test(
      'a periodic heartbeat timer is started on connect() at the 30s '
      'interval and sends the exact backend-expected frame',
      () async {
        final periodicScheduler = FakePeriodicScheduler();
        final manager =
            buildManager(periodicTimerFactory: periodicScheduler.call);
        await manager.connect(1);
        final socket = createdSockets.single;

        expect(periodicScheduler.capturedPeriod, const Duration(seconds: 30));

        periodicScheduler.fire();

        expect(socket.sent, [jsonEncode({'type': 'heartbeat'})]);
      },
    );

    test('disconnect() cancels the pending heartbeat timer', () async {
      final periodicScheduler = FakePeriodicScheduler();
      final manager =
          buildManager(periodicTimerFactory: periodicScheduler.call);
      await manager.connect(1);

      await manager.disconnect();

      expect(periodicScheduler.lastTimer?.isActive, isFalse);
    });
  });

  group('outbound WS-only events — sendTyping/sendMarkDelivered/sendMarkRead/sendHeartbeat', () {
    test('sendTyping sends the exact backend-expected frame', () async {
      final manager = buildManager();
      await manager.connect(1);
      final socket = createdSockets.single;

      manager.sendTyping(true);

      expect(socket.sent, [jsonEncode({'type': 'typing', 'is_typing': true})]);
    });

    test('sendMarkDelivered sends the exact backend-expected frame', () async {
      final manager = buildManager();
      await manager.connect(1);
      final socket = createdSockets.single;

      manager.sendMarkDelivered(42);

      expect(
        socket.sent,
        [jsonEncode({'type': 'mark_delivered', 'message_id': 42})],
      );
    });

    test('sendMarkRead sends the exact backend-expected frame', () async {
      final manager = buildManager();
      await manager.connect(1);
      final socket = createdSockets.single;

      manager.sendMarkRead(7);

      expect(
        socket.sent,
        [jsonEncode({'type': 'mark_read', 'message_id': 7})],
      );
    });

    test('sendHeartbeat sends the exact backend-expected frame', () async {
      final manager = buildManager();
      await manager.connect(1);
      final socket = createdSockets.single;

      manager.sendHeartbeat();

      expect(socket.sent, [jsonEncode({'type': 'heartbeat'})]);
    });

    test('all four send methods are silent no-ops when not connected', () async {
      final manager = buildManager();

      manager.sendTyping(true);
      manager.sendHeartbeat();
      manager.sendMarkDelivered(1);
      manager.sendMarkRead(1);

      expect(createdSockets, isEmpty);
    });
  });
}