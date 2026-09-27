import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/chat/chat_connection_manager.dart';
import 'package:social_commerce_app/core/chat/chat_event.dart';

/// A [ChatSocket] fake — implements only the 3 members [ChatSocket]
/// declares (see that class's own doc comment in chat_connection_manager.dart
/// for why this deliberately isn't a `WebSocketChannel` fake).
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
}

void main() {
  late List<FakeChatSocket> createdSockets;
  late List<Uri> capturedUris;
  late String? tokenToReturn;

  ChatConnectionManager buildManager({String apiBaseUrl = 'http://10.0.2.2:8095'}) {
    return ChatConnectionManager(
      getAccessToken: () async => tokenToReturn,
      getApiBaseUrl: () => apiBaseUrl,
      socketFactory: (uri) {
        capturedUris.add(uri);
        final socket = FakeChatSocket();
        createdSockets.add(socket);
        return socket;
      },
    );
  }

  setUp(() {
    createdSockets = [];
    capturedUris = [];
    tokenToReturn = 'test-access-token';
  });

  group('connect() — URL construction', () {
    test('uses ws:// and preserves host/port for an http apiBaseUrl', () async {
      final manager = buildManager(apiBaseUrl: 'http://10.0.2.2:8095');
      await manager.connect(7);

      expect(capturedUris, hasLength(1));
      final uri = capturedUris.single;
      expect(uri.scheme, 'ws');
      expect(uri.host, '10.0.2.2');
      expect(uri.port, 8095);
      expect(uri.path, '/conversations/7/');
      expect(uri.queryParameters['token'], 'test-access-token');
    });

    test('uses wss:// for an https apiBaseUrl', () async {
      final manager = buildManager(apiBaseUrl: 'https://api.example.com');
      await manager.connect(3);

      final uri = capturedUris.single;
      expect(uri.scheme, 'wss');
      expect(uri.host, 'api.example.com');
      expect(uri.path, '/conversations/3/');
    });
  });

  group('connect()/disconnect() — state tracking', () {
    test('transitions disconnected -> connecting -> connected', () async {
      final manager = buildManager();
      expect(manager.currentState, ChatConnectionState.disconnected);

      // IMPORTANT: subscribe to the expectation *before* calling connect(),
      // and let expectLater's own listener wait for the events to actually
      // arrive — broadcast StreamController delivery is asynchronous
      // (microtask-scheduled), so collecting into a plain List and
      // asserting immediately after `await connect()` races against that
      // delivery. `emitsInOrder` avoids the race by listening until the
      // sequence is actually observed, however many microtasks that takes.
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
      await manager.disconnect(); // must not throw
      expect(manager.currentState, ChatConnectionState.disconnected);
    });

    test('connect() with the same conversationId while connected is a no-op', () async {
      final manager = buildManager();
      await manager.connect(1);
      await manager.connect(1);

      expect(createdSockets, hasLength(1)); // only one socket ever created
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
}