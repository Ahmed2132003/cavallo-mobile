import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../domain/notification_preferences.dart';
import 'notification_preferences_provider.dart';

/// Part P-082 (STEP 5): the notification preferences screen.
///
/// Three switches, one per [NotificationCategory]. Each change goes
/// through [NotificationPreferencesNotifier.setEnabled], which flips the
/// switch immediately, sends ONE PATCH for that category only, and puts
/// that category back (then rethrows) if the request fails. This screen
/// only shows a message in that case.
///
/// `system_announcement` has no switch: it is always delivered, and the
/// footer says so.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  static const _tiles =
      <({NotificationCategory category, String title, String subtitle})>[
        (
          category: NotificationCategory.chat,
          title: 'Chat messages',
          subtitle: 'New messages in your conversations.',
        ),
        (
          category: NotificationCategory.moderation,
          title: 'Content review',
          subtitle: 'When your content is approved or rejected.',
        ),
        (
          category: NotificationCategory.social,
          title: 'Social activity',
          subtitle: 'New followers, comments, likes, shares and ratings.',
        ),
      ];

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    NotificationCategory category,
    bool enabled,
  ) async {
    try {
      await ref
          .read(notificationPreferencesProvider.notifier)
          .setEnabled(category, enabled);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not save your preference. Please try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: switch (preferencesAsync) {
        AsyncData(value: final preferences) => ListView(
          children: [
            for (final tile in _tiles)
              SwitchListTile(
                key: ValueKey('notification-preference-${tile.category.name}'),
                title: Text(tile.title),
                subtitle: Text(tile.subtitle),
                value: preferences.isEnabled(tile.category),
                onChanged:
                    (value) =>
                        unawaited(_toggle(context, ref, tile.category, value)),
              ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Important system announcements are always delivered.',
              ),
            ),
          ],
        ),
        AsyncError() => ErrorStateWidget(
          message: 'Could not load your notification settings.',
          onRetry: () => ref.invalidate(notificationPreferencesProvider),
        ),
        _ => const LoadingIndicator(),
      },
    );
  }
}
