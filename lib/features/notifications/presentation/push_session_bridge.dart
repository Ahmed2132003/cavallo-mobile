import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/fcm_service.dart';
import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';

/// Part P-081 (STEP 4): connects [sessionProvider] to [FcmService].
///
/// - A user becomes signed in (a fresh login, or a session restored at
///   cold start): [FcmService.initialize] — asks permission and registers
///   the device token, so the backend upserts it to THIS user.
/// - The session becomes signed out (logout, or a failed silent token
///   refresh): [FcmService.stop] — no more registrations, foreground
///   messages, or queued taps for the previous user.
///
/// Loading and error states are ignored on purpose: `SessionNotifier`
/// moves through a bare loading state on every login/logout attempt, and
/// that says nothing about who is signed in.
///
/// Same pattern as `_SessionRefreshListenable` in `routing/app_router.dart`:
/// a plain `ref.listen` side effect on [sessionProvider]. Lives in
/// `features/notifications/` (not `core/push/`) because it depends on the
/// auth feature, and `core/` must stay feature-agnostic.
final pushSessionBridgeProvider = Provider<void>((ref) {
  final fcmService = ref.read(fcmServiceProvider);

  ref.listen<AsyncValue<User?>>(sessionProvider, (previous, next) {
    if (next case AsyncData<User?>(:final value)) {
      if (value != null) {
        unawaited(fcmService.initialize());
      } else {
        unawaited(fcmService.stop());
      }
    }
  }, fireImmediately: true);
});

/// Activates [pushSessionBridgeProvider] for as long as it is mounted.
/// Wrapped around the app in `main()` (see `main.dart`); renders only
/// [child].
class PushSessionBridge extends ConsumerWidget {
  const PushSessionBridge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushSessionBridgeProvider);
    return child;
  }
}
