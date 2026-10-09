import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_provider.dart';
import '../../../core/push/fcm_service.dart';
import '../../../l10n/app_localizations.dart';
import '../data/notification_repository_impl.dart';
import 'notification_list_provider.dart';
import 'notification_navigator.dart';

/// Part P-082 (STEP 6): the key of the app-wide [ScaffoldMessenger].
///
/// [PushNotificationHandler] sits ABOVE `MaterialApp`, so it has no
/// `BuildContext` that can reach a messenger. `main.dart` hands this key
/// to `MaterialApp.router(scaffoldMessengerKey: ...)` and the handler
/// shows the foreground banner through it.
final rootScaffoldMessengerKeyProvider =
    Provider<GlobalKey<ScaffoldMessengerState>>((ref) {
      return GlobalKey<ScaffoldMessengerState>();
    });

/// Part P-082 (STEP 6): turns [FcmService]'s streams into UI + navigation.
///
/// * **Foreground push** ([FcmService.foregroundMessages]): a short
///   SnackBar with the title and body, tappable. The notification list is
///   also refreshed so the center shows the new row.
/// * **Background / terminated tap** ([FcmService.taps] plus
///   [FcmService.takePendingTaps] for a tap that arrived before this
///   handler subscribed, notably the one that launched the app).
///
/// EVERY navigation goes through [NotificationNavigator.openPush] — the
/// same single mechanism as the notification center (STEP 3). When the
/// message carries a `notification_id`, that notification is also marked
/// read, like a tap on its row in the center.
///
/// Before navigating it waits for the first frame to finish, so a tap
/// that launched the app is handled once the router is mounted.
final pushNotificationHandlerProvider = Provider<void>((ref) {
  final fcmService = ref.read(fcmServiceProvider);
  var disposed = false;

  Future<void> markRead(int notificationId) async {
    try {
      await ref.read(notificationRepositoryProvider).markAsRead(notificationId);
      if (!disposed) ref.invalidate(notificationListProvider);
    } catch (_) {
      // Best effort: the user still gets to the right screen.
    }
  }

  Future<void> openLink(PushDeepLink link) async {
    await WidgetsBinding.instance.endOfFrame;
    if (disposed) return;
    final notificationId = link.notificationId;
    if (notificationId != null) unawaited(markRead(notificationId));
    await ref.read(notificationNavigatorProvider).openPush(link);
  }

  void showBanner(PushMessage message) {
    // A new notification exists on the server: refresh the center.
    ref.invalidate(notificationListProvider);

    final title = message.title?.trim() ?? '';
    final body = message.body?.trim() ?? '';
    if (title.isEmpty && body.isEmpty) return;

    final messenger = ref.read(rootScaffoldMessengerKeyProvider).currentState;
    if (messenger == null) return;

    final link = PushDeepLink.fromData(message.data);
    // This handler sits above MaterialApp (no BuildContext), so the active
    // language is read from the same provider the Accept-Language header uses.
    final l10n = lookupAppLocalizations(
      Locale(ref.read(activeLanguageCodeGetterProvider)()),
    );
    void open() {
      messenger.hideCurrentSnackBar();
      if (link != null) unawaited(openLink(link));
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: GestureDetector(
            key: const ValueKey('push-banner'),
            behavior: HitTestBehavior.opaque,
            onTap: link == null ? null : open,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (body.isNotEmpty)
                  Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          action:
              link == null
                  ? null
                  : SnackBarAction(label: l10n.pushBannerView, onPressed: open),
        ),
      );
  }

  final tapSubscription = fcmService.taps.listen(
    (link) => unawaited(openLink(link)),
  );
  final foregroundSubscription = fcmService.foregroundMessages.listen(
    showBanner,
  );

  // Taps that arrived before this handler was listening (the one that
  // launched the app from terminated).
  for (final link in fcmService.takePendingTaps()) {
    unawaited(openLink(link));
  }

  ref.onDispose(() {
    disposed = true;
    unawaited(tapSubscription.cancel());
    unawaited(foregroundSubscription.cancel());
  });
});

/// Activates [pushNotificationHandlerProvider] for as long as it is
/// mounted. Wrapped around the app in `main()` (see `main.dart`), inside
/// `PushSessionBridge`; renders only [child].
class PushNotificationHandler extends ConsumerWidget {
  const PushNotificationHandler({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushNotificationHandlerProvider);
    return child;
  }
}
