/// Part P-082: `notificationPreferencesProvider` — the three category
/// toggles of the preferences screen.
///
/// [NotificationPreferencesNotifier.setEnabled] is optimistic: the switch
/// flips immediately, then ONE PATCH (only that category's key) goes out.
///
/// ### Failure and concurrency
/// On failure ONLY that category goes back to its previous value and the
/// error is rethrown, so the screen can show a message. The other
/// categories are never touched, so two quick toggles cannot undo each
/// other. On success only that category's value is taken from the
/// server's answer, for the same reason.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_repository_impl.dart';
import '../domain/notification_preferences.dart';

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() {
    return ref.watch(notificationRepositoryProvider).fetchPreferences();
  }

  Future<void> setEnabled(NotificationCategory category, bool enabled) async {
    final current = state.value;
    if (current == null) return;

    final previous = current.isEnabled(category);
    if (previous == enabled) return;

    state = AsyncData(current.withCategory(category, enabled));

    try {
      final saved = await ref
          .read(notificationRepositoryProvider)
          .updatePreference(category: category, enabled: enabled);
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.withCategory(category, saved.isEnabled(category)),
      );
    } catch (_) {
      if (ref.mounted) {
        final latest = state.value ?? current;
        state = AsyncData(latest.withCategory(category, previous));
      }
      rethrow;
    }
  }
}

final notificationPreferencesProvider = AsyncNotifierProvider.autoDispose<
  NotificationPreferencesNotifier,
  NotificationPreferences
>(NotificationPreferencesNotifier.new, retry: (retryCount, error) => null);
