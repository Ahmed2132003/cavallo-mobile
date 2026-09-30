import 'dart:async';

import 'package:social_commerce_app/core/push/fcm_service.dart';

/// A plain fake [PushMessagingClient] shared by the P-081 push tests.
/// No Firebase, no platform channels.
class FakePushMessagingClient implements PushMessagingClient {
  FakePushMessagingClient({
    this.configured = true,
    this.permissionGranted = true,
    this.token = 'tok-1',
    this.initialMessage,
  });

  bool configured;
  bool permissionGranted;
  String? token;
  PushMessage? initialMessage;

  /// When set, [requestPermission] waits on it — lets a test hold the
  /// "permission prompt" open while it calls `stop()`.
  Completer<bool>? permissionGate;

  int ensureInitializedCalls = 0;
  int permissionCalls = 0;
  int getTokenCalls = 0;
  int initialMessageCalls = 0;

  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final openedApp = StreamController<PushMessage>.broadcast();

  @override
  Future<bool> ensureInitialized() async {
    ensureInitializedCalls++;
    return configured;
  }

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    final gate = permissionGate;
    if (gate != null) return gate.future;
    return permissionGranted;
  }

  @override
  Future<String?> getToken() async {
    getTokenCalls++;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushMessage> get onMessageOpenedApp => openedApp.stream;

  @override
  Future<PushMessage?> getInitialMessage() async {
    initialMessageCalls++;
    return initialMessage;
  }
}
