import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../deep_link_resolver.dart';
import '../error_reporting.dart';
import '../network/dio_client.dart';

/// Part P-081: the FCM pipeline on the Flutter side.
///
/// STEP 3 built the token lifecycle (permission, token, backend
/// registration, re-registration on rotation). STEP 4 (this file's final
/// form) adds:
/// - [FcmService.foregroundMessages]: messages that arrive while the app
///   is open. FCM does not display them on most platforms, so P-082 shows
///   an in-app banner from this stream.
/// - [FcmService.taps] / [FcmService.takePendingTaps]: the user tapped a
///   notification (app in the background, or launched from terminated).
///   Each tap is parsed into a [PushDeepLink]. This part does NOT
///   navigate; P-082 consumes the link and navigates using
///   [PushDeepLink.route] (which wraps P-080's `resolveDeepLink`).
///
/// ### Why a [PushMessagingClient] abstraction
/// Mirrors `ChatSocket` in `core/chat/chat_connection_manager.dart`: the
/// service depends on a tiny interface instead of `FirebaseMessaging`
/// directly, so unit tests use a plain fake and never need
/// `Firebase.initializeApp()` (no Firebase project exists yet —
/// architecture Section 7 item 4, BLOCKED).
///
/// ### The app must run without Firebase configured
/// Until `google-services.json` / `GoogleService-Info.plist` exist,
/// `Firebase.initializeApp()` throws. [FirebaseMessagingClient.ensureInitialized]
/// catches that and reports `false`, and [FcmService.initialize] then
/// returns [FcmInitResult.notConfigured] — every other feature keeps
/// working. Once the config files exist, no Dart change is needed.

/// A push message reduced to what the app needs. Decouples the rest of
/// the app (and the tests) from Firebase's `RemoteMessage`.
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  /// The notification title, when the message carries one.
  final String? title;

  /// The notification body, when the message carries one.
  final String? body;

  /// The data payload the backend sends
  /// (`notifications.services.send_push_notification`): `type`,
  /// `notification_id`, `deep_link_type`, `target_id`. FCM only carries
  /// strings, so every value is a string.
  final Map<String, String> data;
}

/// Where a tapped notification wants to go. Built from the backend's
/// `deep_link_type` + `target_id` data keys (Part P-078/P-081 backend).
class PushDeepLink {
  const PushDeepLink({required this.type, this.targetId, this.notificationId});

  /// The raw `deep_link_type` (for example `chat_thread`). Never blank.
  final String type;

  /// The `target_id`, or `null` when missing or not a number.
  final int? targetId;

  /// The `notification_id` of the in-app Notification row, when present
  /// (lets P-082 mark it read).
  final int? notificationId;

  /// The route to open, via P-080's [resolveDeepLink]. Never throws;
  /// falls back to [deepLinkFallbackRoute] for an unknown type or a
  /// missing/invalid id.
  String get route => resolveDeepLink(type, targetId);

  /// Parses a push data payload. Returns `null` when the message has no
  /// deep link (missing or blank `deep_link_type`, which the backend
  /// sends for notifications that navigate nowhere).
  static PushDeepLink? fromData(Map<String, String> data) {
    final type = data['deep_link_type']?.trim();
    if (type == null || type.isEmpty) return null;
    return PushDeepLink(
      type: type,
      targetId: int.tryParse(data['target_id'] ?? ''),
      notificationId: int.tryParse(data['notification_id'] ?? ''),
    );
  }
}

/// The narrow slice of Firebase Messaging that [FcmService] needs.
abstract class PushMessagingClient {
  /// Initialises Firebase if needed. Returns `false` (never throws) when
  /// Firebase is not configured for this build.
  Future<bool> ensureInitialized();

  /// Asks the OS for notification permission. `true` when granted
  /// (authorized or iOS-provisional).
  Future<bool> requestPermission();

  /// The current FCM registration token, or `null` if unavailable.
  Future<String?> getToken();

  /// Emits a new token whenever FCM rotates it.
  Stream<String> get onTokenRefresh;

  /// Messages received while the app is in the foreground.
  Stream<PushMessage> get onForegroundMessage;

  /// Notification taps while the app was in the background.
  Stream<PushMessage> get onMessageOpenedApp;

  /// The message whose notification launched the app from terminated,
  /// or `null` when the app was launched some other way.
  Future<PushMessage?> getInitialMessage();
}

/// Converts Firebase's [RemoteMessage] into a [PushMessage]. Null data
/// values are dropped; the rest are stringified.
@visibleForTesting
PushMessage pushMessageFromRemote(RemoteMessage message) {
  return PushMessage(
    title: message.notification?.title,
    body: message.notification?.body,
    data: {
      for (final entry in message.data.entries)
        if (entry.value != null) entry.key: '${entry.value}',
    },
  );
}

/// Production [PushMessagingClient] backed by the real Firebase SDK.
///
/// `FirebaseMessaging.instance` and the static message streams are only
/// touched after [ensureInitialized] has succeeded — reading them
/// earlier throws.
class FirebaseMessagingClient implements PushMessagingClient {
  @override
  Future<bool> ensureInitialized() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return true;
    } catch (error) {
      debugPrint('[FcmService] Firebase not configured: $error');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  @override
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<PushMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(pushMessageFromRemote);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(pushMessageFromRemote);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : pushMessageFromRemote(message);
  }
}

/// What happened on one [FcmService.initialize] call. Never thrown —
/// push is best-effort and must not break login.
enum FcmInitResult {
  /// Token obtained and accepted by the backend.
  registered,

  /// Web/desktop: FCM registration is only wired for Android and iOS.
  unsupportedPlatform,

  /// Firebase is not configured for this build (no config files yet).
  notConfigured,

  /// The user declined the notification permission; nothing registered.
  permissionDenied,

  /// Firebase returned no token.
  noToken,

  /// A token exists but the backend call failed. The refresh listener is
  /// still active, and the next launch/login retries.
  registrationFailed,

  /// [FcmService.stop] (logout) or a newer [FcmService.initialize] call
  /// happened while this one was still waiting; it was abandoned.
  stopped,

  /// An unexpected error was reported through `reportError`.
  failed,
}

/// Resolves the backend's `platform` value, or `null` when FCM is not
/// wired for the current platform.
String? defaultPushPlatform() {
  if (kIsWeb) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    default:
      return null;
  }
}

class FcmService {
  FcmService({
    required PushMessagingClient client,
    required Dio dio,
    String? Function() platformResolver = defaultPushPlatform,
  }) : _client = client,
       _dio = dio,
       _platformResolver = platformResolver;

  /// Backend endpoint (Part P-081 backend, `devices/urls.py`).
  static const registerPath = '/api/v1/devices/register/';

  final PushMessagingClient _client;
  final Dio _dio;
  final String? Function() _platformResolver;

  final StreamController<PushMessage> _foregroundController =
      StreamController<PushMessage>.broadcast();
  final StreamController<PushDeepLink> _tapController =
      StreamController<PushDeepLink>.broadcast();
  final List<PushDeepLink> _pendingTaps = <PushDeepLink>[];

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<PushMessage>? _foregroundSubscription;
  StreamSubscription<PushMessage>? _openedAppSubscription;

  /// `getInitialMessage()` is asked once per service lifetime (one app
  /// launch): asking again after a logout/login must not replay the same
  /// launch notification.
  bool _initialMessageChecked = false;

  /// Bumped by every [initialize] and [stop]; an in-flight [initialize]
  /// compares it after each await and abandons itself when it changed.
  int _generation = 0;

  /// Messages received while the app is in the foreground. Broadcast; P-082
  /// subscribes to show an in-app banner. Emits nothing before
  /// [initialize] has succeeded or after [stop].
  Stream<PushMessage> get foregroundMessages => _foregroundController.stream;

  /// Live notification taps that carry a deep link (app was in the
  /// background). A tap with no deep link is not emitted.
  Stream<PushDeepLink> get taps => _tapController.stream;

  /// Taps that arrived while nobody was listening to [taps] — notably the
  /// notification that launched the app from terminated. Returns them
  /// oldest-first and clears the queue. P-082 calls this once when it
  /// starts, then subscribes to [taps].
  List<PushDeepLink> takePendingTaps() {
    final taps = List<PushDeepLink>.of(_pendingTaps);
    _pendingTaps.clear();
    return taps;
  }

  /// Requests permission, starts listening for messages and taps, fetches
  /// the FCM token and registers it with the backend, then keeps
  /// registering every rotated token.
  ///
  /// Call it after every successful login (the backend upserts, so a
  /// different user signing in on the same device takes the token over)
  /// and on every app launch with an existing session (tokens can rotate
  /// while the app is closed). Safe to call repeatedly: the previous
  /// subscriptions are replaced, never stacked.
  Future<FcmInitResult> initialize() async {
    final platform = _platformResolver();
    if (platform == null) return FcmInitResult.unsupportedPlatform;

    final generation = ++_generation;
    bool isStale() => generation != _generation;

    try {
      if (!await _client.ensureInitialized()) {
        return FcmInitResult.notConfigured;
      }
      if (isStale()) return FcmInitResult.stopped;

      final granted = await _client.requestPermission();
      if (isStale()) return FcmInitResult.stopped;
      if (!granted) return FcmInitResult.permissionDenied;

      await _cancelSubscriptions();
      if (isStale()) return FcmInitResult.stopped;

      // Subscribe BEFORE reading the token so a rotation that happens in
      // between cannot be missed.
      _tokenRefreshSubscription = _client.onTokenRefresh.listen(
        (token) => unawaited(_register(token, platform)),
        onError: (Object error, StackTrace stack) => reportError(error, stack),
      );
      _foregroundSubscription = _client.onForegroundMessage.listen(
        _foregroundController.add,
        onError: (Object error, StackTrace stack) => reportError(error, stack),
      );
      _openedAppSubscription = _client.onMessageOpenedApp.listen(
        _handleTap,
        onError: (Object error, StackTrace stack) => reportError(error, stack),
      );

      if (!_initialMessageChecked) {
        _initialMessageChecked = true;
        final initial = await _client.getInitialMessage();
        if (isStale()) return FcmInitResult.stopped;
        if (initial != null) _handleTap(initial);
      }

      final token = await _client.getToken();
      if (isStale()) return FcmInitResult.stopped;
      if (token == null || token.isEmpty) return FcmInitResult.noToken;

      final registered = await _register(token, platform);
      return registered
          ? FcmInitResult.registered
          : FcmInitResult.registrationFailed;
    } catch (error, stack) {
      reportError(error, stack);
      return FcmInitResult.failed;
    }
  }

  /// Stops everything [initialize] started and drops queued taps (call
  /// on logout — without a session the register call would just fail
  /// with 401, and the next user must not see this user's messages).
  Future<void> stop() async {
    _generation++;
    _pendingTaps.clear();
    await _cancelSubscriptions();
  }

  /// [stop], then closes the public streams. Called when the provider is
  /// disposed; the service cannot be used afterwards.
  Future<void> dispose() async {
    await stop();
    await _foregroundController.close();
    await _tapController.close();
  }

  Future<void> _cancelSubscriptions() async {
    final subscriptions = <StreamSubscription<Object?>>[
      if (_tokenRefreshSubscription != null) _tokenRefreshSubscription!,
      if (_foregroundSubscription != null) _foregroundSubscription!,
      if (_openedAppSubscription != null) _openedAppSubscription!,
    ];
    _tokenRefreshSubscription = null;
    _foregroundSubscription = null;
    _openedAppSubscription = null;
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
  }

  /// A notification was tapped: emit its deep link live, or queue it when
  /// nobody is listening yet. A message without a deep link is ignored.
  void _handleTap(PushMessage message) {
    final link = PushDeepLink.fromData(message.data);
    if (link == null) return;
    if (_tapController.hasListener) {
      _tapController.add(link);
    } else {
      _pendingTaps.add(link);
    }
  }

  /// POSTs the token. Never throws: returns `false` and reports the
  /// error, so neither login nor the refresh listener can be broken by
  /// a backend/network failure.
  Future<bool> _register(String token, String platform) async {
    try {
      await _dio.post<dynamic>(
        registerPath,
        data: {'token': token, 'platform': platform},
      );
      return true;
    } catch (error, stack) {
      reportError(error, stack);
      return false;
    }
  }
}

/// The real Firebase-backed client. Override in tests.
final pushMessagingClientProvider = Provider<PushMessagingClient>((ref) {
  return FirebaseMessagingClient();
});

/// The app-wide [FcmService]. Uses the shared Dio client so the
/// Authorization header and silent token refresh come for free.
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(
    client: ref.watch(pushMessagingClientProvider),
    dio: ref.watch(dioClientProvider),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
