import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_entity.dart';
import '../../features/auth/presentation/session_provider.dart';
import '../../features/chat/presentation/chat_unread_provider.dart';
import '../../features/notifications/presentation/notification_list_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../routing/route_names.dart';
import '../l10n/formatters.dart';
import '../l10n/l10n_context.dart';
import '../theme/app_colors.dart';

/// Part P-113 (STEP 5): the top bar of the Home tab, Instagram style.
///
/// * The wordmark sits at the START of the bar (left in English, right in
///   Arabic - the bar is built with directional widgets only).
/// * The Notifications bell and the Chats icon sit at the END, each with an
///   unread-count badge in brand blue. The Chats icon intentionally
///   duplicates the Chats tab so messaging is always one tap away, for every
///   account type.
///
/// ## Where the numbers come from (no new polling)
/// * Notifications: `notificationListProvider.unreadCount`, the same
///   provider the notification center uses, so reading a notification there
///   updates this badge at once.
/// * Chats: `chatUnreadCountProvider` (one read of the existing conversation
///   list, see that file).
/// Both are read only while a user is signed in. Nothing is timed or polled.
///
/// ## Navigation
/// * Bell: `pushNamed(notifications)` - the notification center sits above
///   the shell, with its own back button.
/// * Chats: `goNamed(chatList)` - it switches to the Chats tab, which keeps
///   its own back stack; system back returns to Home.
///
/// A count of zero draws no badge. A count above 99 is shown as "99+".
///
/// [extraActions] are appended after the two icons. HomeFeedScreen uses it to
/// carry the temporary debug menu until STEP 6 deletes that menu.
class HomeTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const HomeTopBar({this.extraActions = const <Widget>[], super.key});

  /// Widgets drawn after the Notifications and Chats icons.
  final List<Widget> extraActions;

  /// Key of the wordmark text.
  static const Key wordmarkKey = ValueKey<String>('home-wordmark');

  /// Key of the Notifications icon button (unchanged since Part P-082).
  static const Key notificationsKey = ValueKey<String>(
    'home-notifications-button',
  );

  /// Key of the Chats icon button.
  static const Key chatsKey = ValueKey<String>('home-chats-button');

  /// Largest number drawn in a badge before it turns into "99+".
  static const int maxBadgeCount = 99;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.appColors;
    final AppFormatters formatters = AppFormatters(l10n);

    final bool signedIn = ref.watch(
      sessionProvider.select(
        (AsyncValue<User?> session) => switch (session) {
          AsyncData(:final value) => value != null,
          _ => false,
        },
      ),
    );

    final int notificationCount =
        signedIn
            ? ref.watch(
              notificationListProvider.select(
                (AsyncValue<NotificationListState> list) =>
                    list.value?.unreadCount ?? 0,
              ),
            )
            : 0;
    final int chatCount =
        signedIn
            ? ref.watch(
              chatUnreadCountProvider.select(
                (AsyncValue<int> count) => count.value ?? 0,
              ),
            )
            : 0;

    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      title: Text(
        l10n.homeWordmark,
        key: wordmarkKey,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: colors.brandText,
        ),
      ),
      actions: <Widget>[
        _badgedAction(
          key: notificationsKey,
          tooltip: l10n.homeNotificationsTooltip,
          icon: Icons.notifications_outlined,
          count: notificationCount,
          colors: colors,
          formatters: formatters,
          onPressed: () => context.pushNamed(RouteNames.notifications),
        ),
        _badgedAction(
          key: chatsKey,
          tooltip: l10n.homeChatsTooltip,
          icon: Icons.chat_bubble_outline,
          count: chatCount,
          colors: colors,
          formatters: formatters,
          onPressed: () => context.goNamed(RouteNames.chatList),
        ),
        ...extraActions,
      ],
    );
  }

  Widget _badgedAction({
    required Key key,
    required String tooltip,
    required IconData icon,
    required int count,
    required AppColors colors,
    required AppFormatters formatters,
    required VoidCallback onPressed,
  }) {
    final Widget base = Icon(icon);
    final Widget child =
        count <= 0
            ? base
            : Badge(
              backgroundColor: colors.brand,
              textColor: colors.onBrand,
              label: Text(
                count > maxBadgeCount
                    ? '${formatters.compactCount(maxBadgeCount)}+'
                    : formatters.compactCount(count),
              ),
              child: base,
            );
    return IconButton(
      key: key,
      tooltip: tooltip,
      icon: child,
      onPressed: onPressed,
    );
  }
}
