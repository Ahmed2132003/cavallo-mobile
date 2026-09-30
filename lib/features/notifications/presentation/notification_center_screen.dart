import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../domain/app_notification.dart';
import 'notification_list_provider.dart';
import 'notification_navigator.dart';

/// Part P-082 (STEP 4): the notification center (`/notifications`),
/// replacing the P-007 placeholder.
///
/// * Paginated list (scroll past 80% loads the next page, same pattern as
///   `HomeFeedScreen`) with pull-to-refresh.
/// * Unread rows are visually distinct: bold title, a dot and a tinted
///   background.
/// * Tapping a row starts `markAsRead` (not awaited, so navigation is
///   never delayed by a network round trip; a failed mark-read never
///   blocks navigation) and then navigates through
///   [NotificationNavigator.openNotification], the single navigation
///   point shared with the foreground banner and push taps. This screen
///   never builds a route itself.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    if (position.pixels >= position.maxScrollExtent * 0.8) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(notificationListProvider.notifier).loadMore();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not load more notifications.')),
        );
    }
  }

  void _onTapNotification(AppNotification notification) {
    final navigator = ref.read(notificationNavigatorProvider);
    if (!notification.isRead) {
      // Never throws; returns false on failure, which must not block
      // navigation.
      unawaited(
        ref.read(notificationListProvider.notifier).markAsRead(notification.id),
      );
    }
    unawaited(navigator.openNotification(notification));
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(notificationListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: switch (listAsync) {
        AsyncData(value: final state) => _NotificationListBody(
          state: state,
          scrollController: _scrollController,
          onTap: _onTapNotification,
        ),
        AsyncError() => ErrorStateWidget(
          message: 'Could not load your notifications.',
          onRetry: () => ref.invalidate(notificationListProvider),
        ),
        _ => const LoadingIndicator(),
      },
    );
  }
}

class _NotificationListBody extends ConsumerWidget {
  const _NotificationListBody({
    required this.state,
    required this.scrollController,
    required this.onTap,
  });

  final NotificationListState state;
  final ScrollController scrollController;
  final ValueChanged<AppNotification> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleRefresh() =>
        ref.read(notificationListProvider.notifier).refresh();

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 96),
            EmptyStateWidget(
              message: 'No notifications yet.',
              icon: Icons.notifications_none_outlined,
            ),
          ],
        ),
      );
    }

    final itemCount = state.items.length + (state.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }
          final notification = state.items[index];
          return _NotificationTile(
            key: ValueKey('notification-item-${notification.id}'),
            notification: notification,
            onTap: () => onTap(notification),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;

    return Material(
      color:
          unread
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
              : Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Icon(_iconFor(notification.notificationType)),
        ),
        title: Text(
          notification.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        subtitle: Text(
          notification.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _timeAgo(notification.createdAt),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            if (unread)
              Container(
                key: ValueKey('notification-unread-dot-${notification.id}'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

/// Icon by the backend's `notification_type` (WHY the notification
/// exists). Unknown types get the generic bell.
IconData _iconFor(String notificationType) {
  if (notificationType.contains('follow')) return Icons.person_add_outlined;
  if (notificationType.contains('chat') ||
      notificationType.contains('message')) {
    return Icons.chat_bubble_outline;
  }
  if (notificationType.contains('comment')) {
    return Icons.mode_comment_outlined;
  }
  if (notificationType.contains('moderation')) {
    return Icons.shield_outlined;
  }
  return Icons.notifications_outlined;
}

String _timeAgo(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}
