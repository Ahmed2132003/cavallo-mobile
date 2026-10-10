import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../routing/route_names.dart';
import '../domain/app_notification.dart';
import 'notification_grouping.dart';
import 'notification_list_provider.dart';
import 'notification_navigator.dart';
import '../../../core/widgets/cavallo_app_bar.dart';

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
///
/// Part P-115 (STEP 4): restyle only. Rows are grouped into Today / This
/// week / Earlier ([groupNotificationsByRecency]), use the design tokens
/// (`context.appColors`), hairline dividers, a skeleton loader and
/// localized text. The provider, the paging, the mark-read call and the
/// navigation call are exactly the P-082 ones.
///
/// The backend notification carries no actor avatar and no thumbnail
/// (`AppNotification` has exactly the eight serializer fields), so the
/// leading circle is the notification-type icon. Adding an avatar or a
/// thumbnail needs a backend field and is out of scope for P-115.
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
          SnackBar(content: Text(context.l10n.notifLoadMoreFailed)),
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
      appBar: CavalloAppBar(
        title: Text(context.l10n.notifTitle),
        actions: [
          IconButton(
            key: const ValueKey('notification-preferences-button'),
            tooltip: context.l10n.notifSettingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed:
                () => unawaited(
                  context.pushNamed<void>(RouteNames.notificationPreferences),
                ),
          ),
        ],
      ),
      body: switch (listAsync) {
        AsyncData(value: final state) => _NotificationListBody(
          state: state,
          scrollController: _scrollController,
          onTap: _onTapNotification,
        ),
        AsyncError() => ErrorStateWidget(
          message: context.l10n.notifLoadFailed,
          onRetry: () => ref.invalidate(notificationListProvider),
        ),
        _ => const _NotificationSkeleton(),
      },
    );
  }
}

/// One line of the grouped list: a section header or a notification.
sealed class _Row {
  const _Row();
}

final class _HeaderRow extends _Row {
  const _HeaderRow(this.section);

  final NotificationSection section;
}

final class _ItemRow extends _Row {
  const _ItemRow(this.notification);

  final AppNotification notification;
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
          children: [
            const SizedBox(height: 96),
            EmptyStateWidget(
              message: context.l10n.notifEmpty,
              icon: Icons.notifications_none_outlined,
            ),
          ],
        ),
      );
    }

    final List<_Row> rows = <_Row>[
      for (final NotificationGroup group in groupNotificationsByRecency(
        state.items,
        DateTime.now(),
      )) ...<_Row>[
        _HeaderRow(group.section),
        for (final AppNotification item in group.items) _ItemRow(item),
      ],
    ];
    final itemCount = rows.length + (state.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= rows.length) {
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
          return switch (rows[index]) {
            _HeaderRow(:final section) => _SectionHeader(section: section),
            _ItemRow(:final notification) => _NotificationTile(
              key: ValueKey('notification-item-${notification.id}'),
              notification: notification,
              onTap: () => onTap(notification),
            ),
          };
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final NotificationSection section;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String label = switch (section) {
      NotificationSection.today => context.l10n.notifSectionToday,
      NotificationSection.thisWeek => context.l10n.notifSectionThisWeek,
      NotificationSection.earlier => context.l10n.notifSectionEarlier,
    };
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 8),
        child: Text(
          label,
          key: ValueKey('notification-section-${section.name}'),
          style: (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
              .copyWith(fontWeight: FontWeight.w700, color: colors.textPrimary),
        ),
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

  static const double _leadingSize = 44;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final bool unread = !notification.isRead;
    final AppFormatters formatters = AppFormatters(context.l10n);

    // Unread is carried by THREE signals, never by colour alone: the tinted
    // row, the bold title and the dot (which also has a semantic label).
    return Material(
      color: unread ? colors.brandSubtle : Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: _leadingSize,
                    height: _leadingSize,
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconFor(notification.notificationType),
                      size: 22,
                      color: unread ? colors.brandText : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (theme.textTheme.titleSmall ??
                                  const TextStyle())
                              .copyWith(
                                fontWeight:
                                    unread ? FontWeight.w700 : FontWeight.w400,
                                color: colors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notification.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatters.relativeTime(notification.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (unread)
                        Semantics(
                          label: context.l10n.notifUnreadLabel,
                          child: Container(
                            key: ValueKey(
                              'notification-unread-dot-${notification.id}',
                            ),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors.brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 10),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 16 + _leadingSize + 12,
            color: colors.outline,
          ),
        ],
      ),
    );
  }
}

/// Skeleton shown while the first page loads (instead of a spinner).
class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.notifLoadingLabel,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        itemBuilder:
            (context, index) => Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
              child: Row(
                children: [
                  const AppShimmerBox.circle(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmerBox(height: 14, width: 160),
                        SizedBox(height: 8),
                        AppShimmerBox(height: 12, width: double.infinity),
                      ],
                    ),
                  ),
                ],
              ),
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
