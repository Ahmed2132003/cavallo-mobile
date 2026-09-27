import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/chat/chat_connection_manager.dart';
import 'package:social_commerce_app/core/chat/chat_event.dart';

/// A [ChatSocket] fake. [close] is the DELIBERATE path (what
/// [ChatConnectionManager.disconnect] calls) — it flips [closed] and
/// closes the stream. [simulateUnexpectedClose] is the *other* path: the
/// server/network drops the connection out from under the manager, with
/// nobody having called [close] first — this is what should trigger
/// STEP 3's reconnection logic.
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

  /// Test helper: simulate the server pushing one raw text frame.
  void emit(String rawText) => _incoming.add(rawText);

  /// Test helper: simulate an unexpected disconnect (server/network
  /// dropped the connection) — deliberately NOT the same code path as
  /// [close], since the manager must react differently to the two.
  Future<void> simulateUnexpectedClose() => _incoming.close();
}

/// A fake [Timer] the reconnect/heartbeat fakes below hand back to the
/// manager, so [ChatConnectionManager]'s own `.cancel()` calls (e.g. a
/// deliberate disconnect mid-backoff) are observable in tests instead of
/// needing a real, time-based [Timer].
class FakeTimer implements Timer {
  bool _active = true;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// Flushes pending microtasks a few times over. Needed because
/// `StreamController.close()` on a broadcast controller, and the
/// `unawaited(_tryReconnectOnce(...))` call inside
/// `_performReconnectAttempt`, both resolve via microtasks rather than
/// synchronously — a single `await` isn't reliably enough hops for every
/// callback in the chain to have run.
Future<void> flushMicrotasks() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>(() {});
  }
}

void main() {
  late List<FakeChatSocket> createdSockets;
  late List<Uri> capturedUris;
  late String? tokenToReturn;

  late List<Duration> capturedReconnectDelays;
  late void Function()? pendingReconnectCallback;

  late Duration? capturedHeartbeatPeriod;
  late void Function(Timer)? pendingHeartbeatCallback;
  late FakeTimer? lastHeartbeatTimer;

  ChatConnectionManager buildManager({
    String apiBaseUrl = 'http://10.0.2.2:8095',
    Duration heartbeatInterval = const Duration(seconds: 30),
  }) {
    return ChatConnectionManager(
      getAccessToken: () async => tokenToReturn,
      getApiBaseUrl: () => apiBaseUrl,
      heartbeatInterval: heartbeatInterval,
      socketFactory: (uri) {
        capturedUris.add(uri);
        final socket = FakeChatSocket();
        createdSockets.add(socket);
        return socket;
      },
      reconnectScheduler: (delay, callback) {
        capturedReconnectDelays.add(delay);
        pendingReconnectCallback = callback;
        return FakeTimer();
      },
      periodicTimerFactory: (period, callback) {
        capturedHeartbeatPeriod = period;
        pendingHeartbeatCallback = callback;
        lastHeartbeatTimer = FakeTimer();
        return lastHeartbeatTimer!;
      },
    );
  }

  setUp(() {
    createdSockets = [];
    capturedUris = [];
    tokenToReturn = 'test-access-token';
    capturedReconnectDelays = [];
    pendingReconnectCallback = null;
    capturedHeartbeatPeriod = null;
    pendingHeartbeatCallback = null;
    lastHeartbeatTimer = null;
  });

  group('connect() — URL construction (locked contract: /ws/ prefix)', () {
    test('uses ws:// and the /ws/conversations/<id>/ path for an http base', () async {
      final manager = buildManager(apiBaseUrl: 'http://10.0.2.2:8095');
      await manager.connect(7);

      final uri = capturedUris.single;
      expect(uri.scheme, 'ws');
      expect(uri.host, '10.0.2.2');
      expect(uri.port, 8095);
      expect(uri.path, '/ws/conversations/7/');
      expect(uri.queryParameters['token'], 'test-access-token');
    });

    test('uses wss:// for an https base, still with the /ws/ prefix', () async {
      final manager = buildManager(apiBaseUrl: 'https://api.example.com');
      await manager.connect(3);

      final uri = capturedUris.single;
      expect(uri.scheme, 'wss');
      expect(uri.host, 'api.example.com');
      expect(uri.path, '/ws/conversations/3/');
    });
  });

  group('connect()/disconnect() — state tracking (STEP 2 behavior, unchanged)', () {
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

    test('connect() throws StateError when no access token is available', () async {
      tokenToReturn = null;
      final manager = buildManager();

      await expectLater(() => manager.connect(1), throwsA(isA<StateError>()));
      expect(manager.currentState, ChatConnectionState.disconnected);
      expect(createdSockets, isEmpty);
    });
  });

  group('backoffDelayForAttempt — pure function, no Timer needed', () {
    test('follows 1s, 2s, 4s, 8s, 16s, then caps at 30s', () {
      expect(ChatConnectionManager.backoffDelayForAttempt(1), const Duration(seconds: 1));
      expect(ChatConnectionManager.backoffDelayForAttempt(2), const Duration(seconds: 2));
      expect(ChatConnectionManager.backoffDelayForAttempt(3), const Duration(seconds: 4));
      expect(ChatConnectionManager.backoffDelayForAttempt(4), const Duration(seconds: 8));
      expect(ChatConnectionManager.backoffDelayForAttempt(5), const Duration(seconds: 16));
      expect(ChatConnectionManager.backoffDelayForAttempt(6), const Duration(seconds: 30));
      expect(ChatConnectionManager.backoffDelayForAttempt(7), const Duration(seconds: 30));
      expect(ChatConnectionManager.backoffDelayForAttempt(20), const Duration(seconds: 30));
    });
  });

  group('reconnection vs deliberate disconnect', () {
    test(
      'an unexpected close moves to reconnecting, schedules attempt 1 at '
      '1s, and a successful retry reconnects and resets the attempt count',
      () async {
        final manager = buildManager();
        await manager.connect(1);
        final firstSocket = createdSockets.single;

        final statesExpectation = expectLater(
          manager.connectionState,
          emitsInOrder([
            ChatConnectionState.reconnecting,
            ChatConnectionState.connected,
          ]),
        );

        await firstSocket.simulateUnexpectedClose();
        await flushMicrotasks();

        expect(capturedReconnectDelays, [const Duration(seconds: 1)]);
        expect(manager.reconnectAttempt, 1);

        pendingReconnectCallback?.call();
        await statesExpectation;

        expect(createdSockets, hasLength(2));
        expect(manager.currentState, ChatConnectionState.connected);
        expect(manager.reconnectAttempt, 0);
      },
    );

    test(
      'repeated unexpected closes back off with increasing delays '
      '(1s, then 2s on the next failure)',
      () async {
        tokenToReturn = null; // every reconnect attempt fails
        final manager = buildManager();
        tokenToReturn = 'test-access-token';
        await manager.connect(1);
        final firstSocket = createdSockets.single;

        await firstSocket.simulateUnexpectedClose();
        await flushMicrotasks();
        expect(capturedReconnectDelays, [const Duration(seconds: 1)]);

        tokenToReturn = null; // make the retry itself fail too
        pendingReconnectCallback?.call();
        await flushMicrotasks();

        expect(
          capturedReconnectDelays,
          [const Duration(seconds: 1), const Duration(seconds: 2)],
        );
        expect(manager.currentState, ChatConnectionState.reconnecting);
      },
    );

    test(
      'a deliberate disconnect() does NOT schedule any reconnect attempt',
      () async {
        final manager = buildManager();
        await manager.connect(1);

        await manager.disconnect();

        expect(capturedReconnectDelays, isEmpty);
        expect(manager.currentState, ChatConnectionState.disconnected);
      },
    );

    test(
      'disconnect() called while a backoff retry is still pending cancels '
      'that pending attempt — it must not open a new socket',
      () async {
        final manager = buildManager();
        await manager.connect(1);
        final firstSocket = createdSockets.single;

        await firstSocket.simulateUnexpectedClose();
        await flushMicrotasks();
        expect(capturedReconnectDelays, [const Duration(seconds: 1)]);

        await manager.disconnect();

        // Simulate the already-scheduled Timer firing anyway (as if
        // cancellation raced it) — the manager's own internal
        // _deliberateDisconnect guard must still prevent it from acting.
        pendingReconnectCallback?.call();
        await flushMicrotasks();

        expect(createdSockets, hasLength(1)); // no second socket opened
        expect(manager.currentState, ChatConnectionState.disconnected);
      },
    );
  });

  group('heartbeat', () {
    test(
      'starts a periodic timer at the configured interval once connected, '
      'and each tick sends {"type": "heartbeat"}',
      () async {
        final manager = buildManager(heartbeatInterval: const Duration(seconds: 30));
        await manager.connect(1);
        final socket = createdSockets.single;

        expect(capturedHeartbeatPeriod, const Duration(seconds: 30));
        expect(socket.sent, isEmpty); // not sent yet, only scheduled

        pendingHeartbeatCallback?.call(lastHeartbeatTimer!);

        expect(socket.sent, hasLength(1));
        expect(jsonDecode(socket.sent.single as String), {'type': 'heartbeat'});
      },
    );

    test('the heartbeat timer is cancelled on a deliberate disconnect', () async {
      final manager = buildManager();
      await manager.connect(1);
      final heartbeatTimer = lastHeartbeatTimer!;

      await manager.disconnect();

      expect(heartbeatTimer.isActive, isFalse);
    });
  });

  group('outbound WS-only events — exact wire format', () {
    test('sendTyping(true) sends {"type": "typing", "is_typing": true}', () async {
      final manager = buildManager();
      await manager.connect(1);
      final socket = createdSockets.single;

      manager.sendTyping(true);

      expect(jsonDecode(socket.sent.single as String), {
        'type': 'typing',
        'is_typing': true,
      });
    });

    test('sendMarkDelivered(42) sends {"type": "mark_delivered", "message_id": 42}', () async {
      final manager = buildManager();
      await manager.connect(1);
      final socket = createdSockets.single;

      manager.sendMarkDelivered(42);

      expect(jsonDecode(socket.sent.single as String), {
        'type': 'mark_delivered',
        'message_id': 42,
      });
    });

    test('sendMarkRead(42) sends {"type": "mark_read", "message_id": 42}', () async {
      final manager = buildManager();
      await manager.connect(1);
      final socket = createdSockets.single;

      manager.sendMarkRead(42);

      expect(jsonDecode(socket.sent.single as String), {
        'type': 'mark_read',
        'message_id': 42,
      });
    });

    test('sending while not connected is a silent no-op (no throw)', () {
      final manager = buildManager();
      expect(() => manager.sendTyping(true), returnsNormally);
      expect(() => manager.sendHeartbeat(), returnsNormally);
      expect(() => manager.sendMarkDelivered(1), returnsNormally);
      expect(() => manager.sendMarkRead(1), returnsNormally);
    });
  });

  group('incoming frame parsing -> eventStream (unchanged from STEP 2)', () {
    test('a chat_message frame is parsed and emitted as MessageReceived', () async {
      final manager = buildManager();
      await manager.connect(1);
      final socket = createdSockets.single;

      final future = expectLater(manager.eventStream, emits(isA<MessageReceived>()));
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

    test('a typing_indicator frame is parsed and emitted as TypingIndicator', () async {
      final manager = buildManager();
      await manager.connect(1);
      final socket = createdSockets.single;

      final future = expectLater(manager.eventStream, emits(isA<TypingIndicator>()));
      socket.emit(jsonEncode({'is_typing': true}));
      await future;
    });

    test(
      'a malformed frame is dropped silently — a later well-formed frame '
      'still arrives',
      () async {
        final manager = buildManager();
        await manager.connect(1);
        final socket = createdSockets.single;

        final future = expectLater(manager.eventStream, emits(isA<TypingIndicator>()));

        socket.emit('not even json {{{');
        socket.emit(jsonEncode({'unexpected': 'shape'}));
        socket.emit(jsonEncode({'is_typing': false}));

        await future;
      },
    );
  });
}