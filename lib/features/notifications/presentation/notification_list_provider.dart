/// Part P-082: `notificationListProvider` — the notification center's
/// list and its pagination position. Plain (non-code-gen) Riverpod
/// `AsyncNotifier`, same convention as `homeFeedProvider`.
///
/// ### `refresh()` vs `loadMore()`
/// * [NotificationListNotifier.refresh] discards local state and fetches a
///   fresh first page. A failed refresh settles into `AsyncError` without
///   rethrowing (non-destructive, retryable read).
/// * [NotificationListNotifier.loadMore] appends the next page. No-op when
///   there is no cursor or a load is already running. On failure it keeps
///   the items already loaded, resets `isLoadingMore` and rethrows to the
///   caller (the screen shows a transient message).
///
/// ### `markAsRead`
/// Never throws. Returns `true` when the notification is (now) read,
/// `false` when the server call failed. The caller navigates either way:
/// a failed "mark read" must never block opening the notification.
///
/// ### Why `autoDispose`
/// The list is live, per-session data. When no screen watches it, the
/// provider is disposed. Code that runs WITHOUT the list screen (a
/// foreground-banner tap, a push tap) must therefore call
/// `notificationRepositoryProvider` directly, not this notifier.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_repository_impl.dart';
import '../domain/app_notification.dart';

class NotificationListState {
  const NotificationListState({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<AppNotification> items;
  final String? nextCursor;
  final bool isLoadingMore;

  /// Unread notifications among the pages loaded so far (not a
  /// server-side total).
  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationListState copyWith({
    List<AppNotification>? items,
    String? nextCursor,
    bool? isLoadingMore,
    bool clearNextCursor = false,
  }) {
    return NotificationListState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class NotificationListNotifier extends AsyncNotifier<NotificationListState> {
  @override
  Future<NotificationListState> build() async {
    final page =
        await ref.watch(notificationRepositoryProvider).listNotifications();
    return NotificationListState(items: page.results, nextCursor: page.next);
  }

  /// Discards local state and fetches a genuine fresh first page.
  Future<void> refresh() async {
    state = const AsyncValue<NotificationListState>.loading();
    state = await AsyncValue.guard<NotificationListState>(() async {
      final page =
          await ref.read(notificationRepositoryProvider).listNotifications();
      return NotificationListState(items: page.results, nextCursor: page.next);
    });
  }

  /// Appends the next page using the current cursor.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.nextCursor == null ||
        current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final page = await ref
          .read(notificationRepositoryProvider)
          .listNotifications(cursor: current.nextCursor);
      if (!ref.mounted) return;

      // Re-read: markAsRead may have changed the list while the page loaded.
      final latest = state.value ?? current;
      final knownIds = latest.items.map((n) => n.id).toSet();
      state = AsyncData(
        latest.copyWith(
          items: [
            ...latest.items,
            ...page.results.where((n) => !knownIds.contains(n.id)),
          ],
          nextCursor: page.next,
          isLoadingMore: false,
          clearNextCursor: page.next == null,
        ),
      );
    } catch (_) {
      if (ref.mounted) {
        final latest = state.value ?? current;
        state = AsyncData(latest.copyWith(isLoadingMore: false));
      }
      rethrow;
    }
  }

  /// Marks one notification read. See the library docstring.
  Future<bool> markAsRead(int notificationId) async {
    final existing =
        state.value?.items.where((n) => n.id == notificationId).firstOrNull;
    if (existing != null && existing.isRead) return true;

    try {
      final updated = await ref
          .read(notificationRepositoryProvider)
          .markAsRead(notificationId);
      if (!ref.mounted) return true;
      _replace(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _replace(AppNotification updated) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final n in current.items) n.id == updated.id ? updated : n,
        ],
      ),
    );
  }
}

final notificationListProvider = AsyncNotifierProvider.autoDispose<
  NotificationListNotifier,
  NotificationListState
>(NotificationListNotifier.new, retry: (retryCount, error) => null);
