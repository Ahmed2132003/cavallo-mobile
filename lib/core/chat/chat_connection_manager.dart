import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../storage/secure_token_storage.dart';
import 'chat_event.dart';

/// The lifecycle state of the single active chat WebSocket connection.
///
/// [reconnecting] now (STEP 3) covers the *entire* window from an
/// unexpected close until either a reconnect attempt succeeds
/// ([connected]) or a deliberate [ChatConnectionManager.disconnect] call
/// settles it to [disconnected] — including every failed retry in
/// between. It does not re-emit per failed attempt; only the transition
/// *into* and *out of* [reconnecting] is broadcast on [ChatConnectionManager.connectionState].
enum ChatConnectionState { disconnected, connecting, connected, reconnecting }

/// A minimal, test-friendly abstraction over one open WebSocket
/// connection. See STEP 2's own note: deliberately NOT the full
/// `WebSocketChannel` interface, to keep `FakeChatSocket` in
/// `test/core/chat/chat_connection_manager_test.dart` small and stable
/// across `web_socket_channel` version bumps.
abstract class ChatSocket {
  Stream<dynamic> get stream;
  void add(dynamic data);
  Future<void> close();
}

/// Wraps a real [WebSocketChannel] (opened via `WebSocketChannel.connect`)
/// as a [ChatSocket].
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

/// Signature for opening a [ChatSocket] for a given [Uri]. Lets tests
/// inject a fake instead of hitting a real socket.
typedef ChatSocketFactory = ChatSocket Function(Uri uri);

ChatSocket _defaultChatSocketFactory(Uri uri) =>
    _RealChatSocket(WebSocketChannel.connect(uri));

/// STEP 3: schedules a one-shot callback after [delay] and returns the
/// [Timer] governing it, so the caller can [Timer.cancel] it (e.g. a
/// deliberate [ChatConnectionManager.disconnect] mid-backoff-wait, or a
/// fresh [ChatConnectionManager.connect] to a different conversation).
/// Production default is a real [Timer]; tests inject a fake that lets
/// them fire the callback manually instead of waiting real seconds.
typedef ReconnectScheduler =
    Timer Function(Duration delay, void Function() callback);

Timer _defaultReconnectScheduler(Duration delay, void Function() callback) =>
    Timer(delay, callback);

/// STEP 3: schedules a repeating callback every [period] (the heartbeat
/// timer), matching [Timer.periodic]'s own signature so the production
/// default can just be [Timer.periodic] itself.
typedef PeriodicTimerFactory =
    Timer Function(Duration period, void Function(Timer timer) callback);

Timer _defaultPeriodicTimerFactory(
  Duration period,
  void Function(Timer) callback,
) => Timer.periodic(period, callback);

/// Part P-073 — the global-singleton WebSocket connection manager for
/// chat (`lib/core/chat/`, per Architecture Section 13 — see this part's
/// own master-plan spec for why this is core-layer, not
/// `lib/features/chat/`).
///
/// ### Connection-scope decision (restated from STEP 2, unchanged)
/// Connects **per-conversation, on demand**: [connect] when a chat
/// thread screen opens, [disconnect] when it closes. "Singleton" means
/// one [ChatConnectionManager] instance (via [chatConnectionManagerProvider])
/// governs whichever single conversation is currently active — not one
/// permanent app-wide socket for the whole session. Safe specifically
/// because P-068's persistence-first backend design means no message is
/// ever lost just because no live socket happened to be open.
///
/// ### STEP 3 scope (this file, now complete for P-073)
/// - **Reconnection**: an *unexpected* close (server/network dropped the
///   connection) moves to [ChatConnectionState.reconnecting] and retries
///   with exponential backoff — 1s, 2s, 4s, 8s, 16s, capped at 30s (see
///   [backoffDelayForAttempt]) — resetting to attempt 1 as soon as a
///   reconnect actually succeeds. A *deliberate* [disconnect] (tracked
///   via `_deliberateDisconnect`, exactly as STEP 2 wired it) never
///   triggers this — checked both before scheduling and again right
///   before each retry actually fires, so a `disconnect()` that lands
///   while a backoff timer is still pending correctly prevents that
///   pending attempt from doing anything.
/// - **Heartbeat**: a periodic timer sends `sendHeartbeat()` every 30s
///   while connected (comfortably under `chat/consumers.py`'s
///   `PRESENCE_TTL_SECONDS = 60`), started right after every successful
///   connection (initial or reconnected) and cancelled on any close.
/// - **Outbound WS-only events**: [sendTyping], [sendHeartbeat],
///   [sendMarkDelivered], [sendMarkRead] — each matching
///   `chat/consumers.py`'s `receive()` exactly (verified directly
///   against that file, not assumed): every outbound frame carries an
///   explicit `"type"` key (`"heartbeat"` / `"typing"` /
///   `"mark_delivered"` / `"mark_read"`), which is the mirror image of
///   the *inbound* frames documented in `chat_event.dart` — those carry
///   **no** `"type"` key at all. This asymmetry is a real, verified
///   property of this backend, not an inconsistency to "fix".
///
/// ### Bug fixed in this step
/// STEP 2's `_buildUri()` built `ws://<host>/conversations/<id>/?token=...`
/// — missing the `/ws/` prefix `chat/middleware.py` and `chat/routing.py`
/// both document as a locked contract
/// (`ws://<host>/ws/conversations/<conversation_id>/?token=<access_token>`).
/// Fixed below; the two URL-construction tests in
/// `chat_connection_manager_test.dart` are updated to match.
class ChatConnectionManager {
  ChatConnectionManager({
    required Future<String?> Function() getAccessToken,
    required String Function() getApiBaseUrl,
    ChatSocketFactory socketFactory = _defaultChatSocketFactory,
    ReconnectScheduler reconnectScheduler = _defaultReconnectScheduler,
    PeriodicTimerFactory periodicTimerFactory = _defaultPeriodicTimerFactory,
    Duration heartbeatInterval = const Duration(seconds: 30),
  }) : _getAccessToken = getAccessToken,
       _getApiBaseUrl = getApiBaseUrl,
       _socketFactory = socketFactory,
       _reconnectScheduler = reconnectScheduler,
       _periodicTimerFactory = periodicTimerFactory,
       _heartbeatInterval = heartbeatInterval;

  final Future<String?> Function() _getAccessToken;
  final String Function() _getApiBaseUrl;
  final ChatSocketFactory _socketFactory;
  final ReconnectScheduler _reconnectScheduler;
  final PeriodicTimerFactory _periodicTimerFactory;
  final Duration _heartbeatInterval;

  ChatSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  int? _activeConversationId;

  /// See STEP 2's own note — set by [disconnect] so the close handlers
  /// can tell a deliberate close apart from an unexpected one. STEP 3
  /// checks this flag twice on the reconnect path: once when deciding
  /// whether to *schedule* a retry at all, and again right before a
  /// scheduled retry actually *runs* — a `disconnect()` landing while a
  /// backoff timer is pending must cancel that in-flight attempt too.
  bool _deliberateDisconnect = false;

  ChatConnectionState _state = ChatConnectionState.disconnected;

  /// STEP 3. How many consecutive failed (re)connect attempts have
  /// happened since the last successful connection — 0 means "not
  /// currently backing off". Feeds [backoffDelayForAttempt] and resets
  /// to 0 the moment a connection succeeds, by any path (fresh [connect]
  /// or an automatic reconnect).
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  final _stateController = StreamController<ChatConnectionState>.broadcast();
  final _eventController = StreamController<ChatEvent>.broadcast();

  ChatConnectionState get currentState => _state;
  Stream<ChatConnectionState> get connectionState => _stateController.stream;
  Stream<ChatEvent> get eventStream => _eventController.stream;
  int? get activeConversationId => _activeConversationId;

  /// STEP 3. Exposed for observability/debugging (e.g. a "reconnecting…
  /// attempt 3" banner in P-074) — not required by any test, but cheap
  /// to expose since the field already exists.
  int get reconnectAttempt => _reconnectAttempt;

  /// Opens the chat WebSocket for [conversationId]. See STEP 2's own doc
  /// comment for the no-op/replace-existing-connection rules — STEP 3
  /// extends the no-op check to also cover
  /// [ChatConnectionState.reconnecting] (calling [connect] again for the
  /// conversation a backoff cycle is already trying to reach is a no-op,
  /// not a reason to restart that cycle from attempt 1), and cancels any
  /// pending reconnect timer before doing anything else so switching to
  /// a different conversation mid-backoff behaves correctly.
  ///
  /// Throws [StateError] if no access token is available — unchanged
  /// from STEP 2. This is distinct from an *automatic* reconnect attempt
  /// hitting the same condition, which is caught internally and treated
  /// as just another failed attempt (see [_tryReconnectOnce]) rather
  /// than an uncaught error.
  Future<void> connect(int conversationId) async {
    if (_activeConversationId == conversationId &&
        (_state == ChatConnectionState.connected ||
            _state == ChatConnectionState.connecting ||
            _state == ChatConnectionState.reconnecting)) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_socket != null) {
      await disconnect();
    }

    _reconnectAttempt = 0;
    _activeConversationId = conversationId;
    _deliberateDisconnect = false;
    _setState(ChatConnectionState.connecting);

    try {
      await _openSocketOrThrow(conversationId);
    } catch (e) {
      _activeConversationId = null;
      _setState(ChatConnectionState.disconnected);
      rethrow;
    }
  }

  /// A deliberate, caller-initiated close. Cancels any pending reconnect
  /// backoff timer and the heartbeat timer, then closes the socket (if
  /// any) exactly as STEP 2 did. Safe to call at any time, including
  /// mid-backoff-wait (when [currentState] is
  /// [ChatConnectionState.reconnecting] but there is no live [_socket]
  /// yet) — that case now correctly settles to
  /// [ChatConnectionState.disconnected] too, instead of being a no-op.
  Future<void> disconnect() async {
    _deliberateDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _stopHeartbeatTimer();

    if (_socket == null) {
      if (_state != ChatConnectionState.disconnected) {
        _activeConversationId = null;
        _setState(ChatConnectionState.disconnected);
      }
      return;
    }

    final socket = _socket;
    _socket = null;
    _activeConversationId = null;

    await _socketSubscription?.cancel();
    _socketSubscription = null;

    await socket?.close();

    _setState(ChatConnectionState.disconnected);
  }

  // ---------------------------------------------------------------------
  // Outbound WS-only events (STEP 3) — matching chat/consumers.py's
  // receive() exactly. Every one of these carries an explicit "type"
  // key; a call while not connected is a silent no-op (the caller — a
  // thread screen's "stop typing" on dispose, say — should never have to
  // guard every call site on connection state itself).
  // ---------------------------------------------------------------------

  void sendTyping(bool isTyping) =>
      _sendJson({'type': 'typing', 'is_typing': isTyping});

  void sendHeartbeat() => _sendJson({'type': 'heartbeat'});

  void sendMarkDelivered(int messageId) =>
      _sendJson({'type': 'mark_delivered', 'message_id': messageId});

  void sendMarkRead(int messageId) =>
      _sendJson({'type': 'mark_read', 'message_id': messageId});

  void _sendJson(Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null) return;
    socket.add(jsonEncode(payload));
  }

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

  void _onMalformedFrame(String reason, dynamic raw) {
    // ignore: avoid_print
    print('ChatConnectionManager: dropped malformed frame — $reason');
  }

  /// Any close reaching this handler stops the heartbeat timer first
  /// (STEP 3 — no point heartbeating a dead socket). Then:
  /// - deliberate close → settle to [ChatConnectionState.disconnected],
  ///   same as STEP 2.
  /// - unexpected close → [ChatConnectionState.reconnecting] +
  ///   [_scheduleReconnect] (STEP 3's actual new behavior).
  void _handleDone() {
    _socket = null;
    _socketSubscription = null;
    _stopHeartbeatTimer();

    if (_deliberateDisconnect) {
      _activeConversationId = null;
      _reconnectAttempt = 0;
      _setState(ChatConnectionState.disconnected);
      return;
    }

    _setState(ChatConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _handleDone();
  }

  /// STEP 3. Increments the attempt counter, computes the next backoff
  /// delay via [backoffDelayForAttempt], and schedules
  /// [_performReconnectAttempt] via [_reconnectScheduler]. Stores the
  /// returned [Timer] in [_reconnectTimer] so [connect]/[disconnect] can
  /// cancel it if the situation changes before it fires.
  void _scheduleReconnect() {
    _reconnectAttempt += 1;
    final delay = backoffDelayForAttempt(_reconnectAttempt);
    _reconnectTimer = _reconnectScheduler(delay, _performReconnectAttempt);
  }

  void _performReconnectAttempt() {
    // A disconnect() landed while this backoff timer was pending —
    // cancelling the Timer itself (done in disconnect()) is the normal
    // path, but this is a second, belt-and-suspenders guard in case a
    // test (or a race) invokes the callback directly rather than through
    // a real cancellable Timer.
    if (_deliberateDisconnect) return;

    final conversationId = _activeConversationId;
    if (conversationId == null) return;

    unawaited(_tryReconnectOnce(conversationId));
  }

  /// One reconnect attempt. On success, resets [_reconnectAttempt] to 0
  /// (so the *next* unexpected close starts backing off from 1s again,
  /// not from wherever the previous cycle left off). On any failure —
  /// no access token available, or the socket factory itself throwing —
  /// schedules another attempt at the next backoff step, unless a
  /// deliberate [disconnect] happened in the meantime.
  Future<void> _tryReconnectOnce(int conversationId) async {
    try {
      await _openSocketOrThrow(conversationId);
      _reconnectAttempt = 0;
    } catch (_) {
      if (!_deliberateDisconnect) {
        _scheduleReconnect();
      }
    }
  }

  /// Shared by [connect] (first connection) and [_tryReconnectOnce]
  /// (every automatic reconnect attempt): fetches a fresh token, builds
  /// the URI, opens the socket, subscribes, and — only on success — sets
  /// [ChatConnectionState.connected] and starts the heartbeat timer.
  /// Throws [StateError] if no token is available; callers decide what
  /// that means for them (see each call site's own doc comment).
  Future<void> _openSocketOrThrow(int conversationId) async {
    final token = await _getAccessToken();
    if (token == null) {
      throw StateError(
        'ChatConnectionManager: no access token available for '
        'conversation $conversationId.',
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
    _startHeartbeatTimer();
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = _periodicTimerFactory(
      _heartbeatInterval,
      (_) => sendHeartbeat(),
    );
  }

  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Builds `ws://<host>/ws/conversations/<id>/?token=<access_token>`
  /// (`wss://` for an `https://` [AppConfig.apiBaseUrl]) — verified
  /// directly against `chat/middleware.py` and `chat/routing.py`'s own
  /// "locked contract" doc comments. **Fixed in STEP 3**: previously
  /// missing the `/ws/` path prefix (see this class's own top doc
  /// comment).
  Uri _buildUri({required int conversationId, required String token}) {
    final base = Uri.parse(_getApiBaseUrl());
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: wsScheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/ws/conversations/$conversationId/',
      queryParameters: {'token': token},
    );
  }

  void _setState(ChatConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _eventController.close();
  }

  /// STEP 3's exponential backoff schedule: 1s, 2s, 4s, 8s, 16s, then
  /// capped at 30s for every attempt after that. [attempt] is 1-based
  /// (the first retry after an unexpected close is attempt 1). A pure,
  /// static function — deliberately has no dependency on `this` — so it
  /// can be (and is, in `chat_connection_manager_test.dart`) unit-tested
  /// directly with no `Timer`/async machinery at all.
  static Duration backoffDelayForAttempt(int attempt) {
    assert(attempt >= 1, 'attempt is 1-based — the first retry is attempt 1');
    const initialSeconds = 1;
    const maxSeconds = 30;
    // 2^5 * 1s = 32s already exceeds the 30s cap, so clamping the
    // exponent at 5 is sufficient and avoids any risk of integer
    // overflow from an unbounded attempt count during a very long
    // outage.
    final exponent = (attempt - 1).clamp(0, 5);
    final seconds = initialSeconds << exponent;
    return Duration(seconds: seconds > maxSeconds ? maxSeconds : seconds);
  }
}

/// The shared [ChatConnectionManager] for the whole app — unchanged from
/// STEP 2: same `Provider` pattern as `dioClientProvider`/
/// `secureTokenStorageProvider`.
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
