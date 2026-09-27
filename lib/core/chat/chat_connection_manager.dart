import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../storage/secure_token_storage.dart';
import 'chat_event.dart';

/// The lifecycle state of the single active chat WebSocket connection.
///
/// [reconnecting] is declared here in STEP 2 even though the automatic
/// reconnection logic that actually drives it doesn't exist yet — that's
/// STEP 3. Defining the full enum now (rather than adding a case to it
/// later) avoids a breaking change to every `switch` written against this
/// type in this step, in STEP 3, and in P-074 (STEP 4).
enum ChatConnectionState { disconnected, connecting, connected, reconnecting }

/// A minimal, test-friendly abstraction over one open WebSocket
/// connection.
///
/// Deliberately NOT the full `WebSocketChannel` interface from
/// `package:web_socket_channel` — that class's exact member set
/// (`closeCode`, `closeReason`, `protocol`, and possibly more depending on
/// the pinned version) is more than this manager needs, and pinning a
/// fake to it would make our own tests brittle against a dependency
/// upgrade. [ChatSocket] exposes only the 3 operations this manager
/// actually performs (`stream`, `add`, `close`), so
/// `test/core/chat/chat_connection_manager_test.dart`'s `FakeChatSocket`
/// only has to implement those 3, not track `web_socket_channel`'s full,
/// version-sensitive API shape.
abstract class ChatSocket {
  /// The stream of incoming raw frames (each element is the `String`
  /// text payload of one WebSocket text message).
  Stream<dynamic> get stream;

  /// Sends a raw frame. STEP 3's `sendTyping`/`sendHeartbeat`/
  /// `sendMarkDelivered`/`sendMarkRead` will call this with a
  /// JSON-encoded `String`.
  void add(dynamic data);

  /// Closes the connection.
  Future<void> close();
}

/// Wraps a real [WebSocketChannel] (opened via `WebSocketChannel.connect`,
/// the master plan's own "standard choice") as a [ChatSocket].
class _RealChatSocket implements ChatSocket {
  _RealChatSocket(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  void add(dynamic data) => _channel.sink.add(data);

  @override
  Future<void> close() => _channel.sink.close();
}

/// Signature for opening a [ChatSocket] for a given [Uri]. Exists purely
/// so tests (this step's own, and STEP 3's backoff tests) can inject a
/// fake instead of hitting a real socket.
typedef ChatSocketFactory = ChatSocket Function(Uri uri);

ChatSocket _defaultChatSocketFactory(Uri uri) =>
    _RealChatSocket(WebSocketChannel.connect(uri));

/// Part P-073 — the global-singleton WebSocket connection manager for
/// chat. See this part's own master-plan spec and Architecture Section 13
/// for why this lives in `lib/core/chat/`, not `lib/features/chat/`.
///
/// ### STEP 2 scope (this file, as of this step)
/// Connection lifecycle (`connect`/`disconnect`), state tracking, URL
/// construction, and dispatching parsed [ChatEvent]s on [eventStream].
/// Deliberately NOT yet in this file:
///   - Exponential-backoff automatic reconnection on an *unexpected*
///     close — STEP 3. [_handleDone] is already wired to check
///     [_deliberateDisconnect] so STEP 3 only has to add the backoff
///     logic itself there, not touch `connect`/`disconnect` again.
///   - The periodic heartbeat `Timer` and the `sendTyping`/
///     `sendHeartbeat`/`sendMarkDelivered`/`sendMarkRead` outbound
///     methods — STEP 3 (these will call [ChatSocket.add] on
///     whatever [_socket] currently is).
///
/// ### Connection-scope decision (per this part's own requirement —
/// restated in PROJECT_PROGRESS.md at the end of P-073)
/// Connects **per-conversation, on demand**: [connect] is called when a
/// chat thread screen opens, [disconnect] when it closes. This is *not*
/// an app-wide always-on connection. "Singleton" here means one
/// [ChatConnectionManager] instance (provided via
/// [chatConnectionManagerProvider], reused across the whole app) governs
/// whichever single conversation is currently active — calling [connect]
/// while already connected to a *different* conversation closes that old
/// connection first (see [connect]'s own doc comment below). It does
/// **not** mean one permanent app-wide socket held open for the whole
/// session. This is the simpler MVP choice the master plan explicitly
/// allows, and is safe specifically because P-068's persistence-first
/// backend design means no message is ever lost just because no live
/// socket happened to be open at some point.
class ChatConnectionManager {
  ChatConnectionManager({
    required Future<String?> Function() getAccessToken,
    required String Function() getApiBaseUrl,
    ChatSocketFactory socketFactory = _defaultChatSocketFactory,
  }) : _getAccessToken = getAccessToken,
       _getApiBaseUrl = getApiBaseUrl,
       _socketFactory = socketFactory;

  final Future<String?> Function() _getAccessToken;
  final String Function() _getApiBaseUrl;
  final ChatSocketFactory _socketFactory;

  ChatSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  int? _activeConversationId;

  /// Set by [disconnect] immediately before tearing the socket down, so
  /// [_handleDone] can tell a deliberate close apart from an unexpected
  /// one. STEP 2 doesn't yet act differently on this distinction in
  /// [_handleDone] beyond reading it — the actual reconnect-vs-not branch
  /// is STEP 3 — but the flag is threaded through now exactly as the
  /// master plan's own EXECUTION PROMPT asks ("track this with an
  /// internal flag"), so STEP 3 only adds behavior, not new state.
  bool _deliberateDisconnect = false;

  ChatConnectionState _state = ChatConnectionState.disconnected;

  final _stateController = StreamController<ChatConnectionState>.broadcast();
  final _eventController = StreamController<ChatEvent>.broadcast();

  /// The current state, readable synchronously — e.g. so a chat thread
  /// screen's `initState`/`build` can decide what to show immediately,
  /// without waiting for the first [connectionState] stream event.
  ChatConnectionState get currentState => _state;

  /// Emits every time [currentState] changes. Broadcast — more than one
  /// listener (a connection-status banner widget, the thread screen
  /// itself) can subscribe independently. Does **not** replay the current
  /// state to a late subscriber — read [currentState] first for that.
  Stream<ChatConnectionState> get connectionState => _stateController.stream;

  /// Parsed incoming events for UI consumption (P-074 is the primary
  /// consumer). Broadcast, same no-replay caveat as [connectionState]. A
  /// malformed frame is logged and dropped (see [_handleData]) rather
  /// than tearing the stream down.
  Stream<ChatEvent> get eventStream => _eventController.stream;

  /// The conversation this manager is currently connected (or attempting
  /// to connect) to, or `null` when [currentState] is
  /// [ChatConnectionState.disconnected].
  int? get activeConversationId => _activeConversationId;

  /// Opens the chat WebSocket for [conversationId].
  ///
  /// - No-op if already [ChatConnectionState.connected] or
  ///   [ChatConnectionState.connecting] to this exact [conversationId].
  /// - If already connected/connecting to a **different** conversation,
  ///   that connection is closed first (as a deliberate disconnect — see
  ///   [disconnect]) before the new one opens, since this manager holds
  ///   at most one live connection at a time (the per-conversation
  ///   "singleton" scope decision above).
  ///
  /// Throws [StateError] if no access token is available. This manager
  /// assumes its caller (P-074) never invokes [connect] before the user
  /// is authenticated — a null token here is a caller bug, not a runtime
  /// condition to recover from silently, since there is no sensible chat
  /// connection for a logged-out user.
  ///
  /// NOTE on the "connected" transition: this sets
  /// [ChatConnectionState.connected] as soon as the socket is opened and
  /// its listener attached, not after any handshake acknowledgement from
  /// the server — `web_socket_channel`'s `WebSocketChannel.connect`
  /// connects lazily and this step keeps things simple to match the
  /// MVP scope. If a later part needs a stricter "server actually
  /// accepted this connection" signal, that would be layered on top of
  /// this state, not replace it.
  Future<void> connect(int conversationId) async {
    if (_activeConversationId == conversationId &&
        (_state == ChatConnectionState.connected ||
            _state == ChatConnectionState.connecting)) {
      return;
    }

    if (_socket != null) {
      await disconnect();
    }

    _activeConversationId = conversationId;
    _deliberateDisconnect = false;
    _setState(ChatConnectionState.connecting);

    final token = await _getAccessToken();
    if (token == null) {
      _activeConversationId = null;
      _setState(ChatConnectionState.disconnected);
      throw StateError(
        'ChatConnectionManager.connect() called with no access token '
        'available — the caller must ensure the user is authenticated '
        'before opening a chat connection.',
      );
    }

    final uri = _buildUri(conversationId: conversationId, token: token);
    final socket = _socketFactory(uri);
    _socket = socket;

    _socketSubscription = socket.stream.listen(
      _handleData,
      onDone: _handleDone,
      onError: _handleError,
      cancelOnError: false,
    );

    _setState(ChatConnectionState.connected);
  }

  /// A deliberate, caller-initiated close (e.g. the chat thread screen
  /// was popped). Cancels the subscription *before* closing the socket,
  /// so no `onDone`/`onError` callback fires for this close — combined
  /// with [_deliberateDisconnect] (set first, for STEP 3's benefit if the
  /// call order is ever restructured). Safe to call when already
  /// disconnected — no-op.
  Future<void> disconnect() async {
    if (_socket == null) return;

    _deliberateDisconnect = true;
    final socket = _socket;
    _socket = null;
    _activeConversationId = null;

    await _socketSubscription?.cancel();
    _socketSubscription = null;

    await socket?.close();

    _setState(ChatConnectionState.disconnected);
  }

  /// Parses one raw incoming WebSocket frame and forwards it on
  /// [eventStream]. A frame that fails to decode as JSON, or that
  /// [ChatEvent.fromJson] doesn't recognize, is dropped (after being
  /// surfaced via [_onMalformedFrame] for logging) rather than tearing
  /// the connection down — matching the backend's own
  /// malformed-frame-is-a-no-op contract on the send side (see
  /// chat_event.dart's top-level doc comment).
  void _handleData(dynamic raw) {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw as String) as Map<String, dynamic>;
    } on Object catch (e) {
      _onMalformedFrame('Could not JSON-decode incoming frame: $e', raw);
      return;
    }

    final ChatEvent event;
    try {
      event = ChatEvent.fromJson(decoded);
    } on ChatEventParseException catch (e) {
      _onMalformedFrame(e.toString(), raw);
      return;
    }

    _eventController.add(event);
  }

  /// Hook for this step's own tests to assert a malformed frame is
  /// dropped without crashing. Logs via `print` for now — P-073's spec
  /// has no dedicated logging/observability part to hook into yet.
  void _onMalformedFrame(String reason, dynamic raw) {
    // ignore: avoid_print
    print('ChatConnectionManager: dropped malformed frame — $reason');
  }

  /// STEP 2 behavior: any close (deliberate or not) that reaches this
  /// handler moves to [ChatConnectionState.disconnected] and does nothing
  /// further. STEP 3 adds the actual branch here: if
  /// `!_deliberateDisconnect`, start exponential-backoff reconnection
  /// instead of just settling on `disconnected`.
  void _handleDone() {
    _socket = null;
    _socketSubscription = null;
    if (_deliberateDisconnect) {
      _activeConversationId = null;
    }
    _setState(ChatConnectionState.disconnected);
  }

  /// Treated the same as a clean close for STEP 2 — STEP 3 will decide
  /// whether a stream error should behave differently from a plain
  /// `onDone` before triggering reconnection.
  void _handleError(Object error, StackTrace stackTrace) {
    _handleDone();
  }

  /// Builds the chat WebSocket URI, matching P-067's convention verified
  /// during STEP 1's backend review:
  /// `ws://<host>[:<port>]/conversations/<id>/?token=<access_token>`
  /// (`wss://` instead of `ws://` when [AppConfig.apiBaseUrl] is
  /// `https://`). If the real backend routing turns out to need an extra
  /// path segment (e.g. a `/ws/chat/` prefix), this is the one place to
  /// change it.
  Uri _buildUri({required int conversationId, required String token}) {
    final base = Uri.parse(_getApiBaseUrl());
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: wsScheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/conversations/$conversationId/',
      queryParameters: {'token': token},
    );
  }

  void _setState(ChatConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Releases the broadcast stream controllers. Call when this manager
  /// itself is being torn down (e.g. `ref.onDispose` on
  /// [chatConnectionManagerProvider] below) — **not** on every
  /// [disconnect]/[connect] cycle, since the same manager instance is
  /// reused across conversations per the per-conversation scope decision
  /// above.
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _eventController.close();
  }
}

/// The shared [ChatConnectionManager] for the whole app — the same
/// `Provider` pattern as `dioClientProvider` (P-004,
/// `lib/core/network/dio_client.dart`) and `secureTokenStorageProvider`
/// (P-005, `lib/core/storage/secure_token_storage.dart`): a plain
/// `Provider`, not a singleton/global, so it's overridable in tests via
/// `ProviderContainer(overrides: [...])`.
final chatConnectionManagerProvider = Provider<ChatConnectionManager>((ref) {
  final tokenStorage = ref.watch(secureTokenStorageProvider);
  final manager = ChatConnectionManager(
    getAccessToken: tokenStorage.getAccessToken,
    getApiBaseUrl: () => AppConfig.apiBaseUrl,
  );
  ref.onDispose(() {
    unawaited(manager.dispose());
  });
  return manager;
});