import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/notifications/data/notification_repository_impl.dart';
import 'package:social_commerce_app/features/notifications/domain/notification_preferences.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_preferences_provider.dart';

import '../fake_notification_repository.dart';

ProviderContainer _container(FakeNotificationRepository fake) {
  final container = ProviderContainer(
    overrides: [notificationRepositoryProvider.overrideWithValue(fake)],
  );
  // The provider is autoDispose: keep it alive for the whole test.
  container.listen(notificationPreferencesProvider, (previous, next) {});
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('build() loads the preferences from the server', () async {
    final fake = FakeNotificationRepository(
      preferences: const NotificationPreferences(socialEnabled: false),
    );
    final container = _container(fake);

    final prefs = await container.read(notificationPreferencesProvider.future);

    expect(prefs.socialEnabled, isFalse);
    expect(prefs.chatEnabled, isTrue);
    expect(fake.fetchPreferencesCalls, 1);
  });

  test('setEnabled() flips at once and sends one category payload', () async {
    final fake = FakeNotificationRepository();
    final gate = Completer<void>();
    fake.updateGates[NotificationCategory.social] = gate;
    final container = _container(fake);
    await container.read(notificationPreferencesProvider.future);
    final notifier = container.read(notificationPreferencesProvider.notifier);

    final future = notifier.setEnabled(NotificationCategory.social, false);

    // The "server" has not answered yet: the optimistic value is shown.
    var prefs = container.read(notificationPreferencesProvider).value!;
    expect(prefs.socialEnabled, isFalse);
    expect(prefs.chatEnabled, isTrue);

    gate.complete();
    await future;

    prefs = container.read(notificationPreferencesProvider).value!;
    expect(prefs.socialEnabled, isFalse);
    expect(fake.updateCalls, [
      (category: NotificationCategory.social, enabled: false),
    ]);
  });

  test('setEnabled() failure reverts that category and rethrows', () async {
    final fake =
        FakeNotificationRepository()
          ..updateErrors[NotificationCategory.chat] = StateError('boom');
    final container = _container(fake);
    await container.read(notificationPreferencesProvider.future);
    final notifier = container.read(notificationPreferencesProvider.notifier);

    await expectLater(
      notifier.setEnabled(NotificationCategory.chat, false),
      throwsA(isA<StateError>()),
    );

    expect(
      container.read(notificationPreferencesProvider).value,
      const NotificationPreferences(),
    );
  });

  test(
    'a failed toggle does not undo a different toggle made meanwhile',
    () async {
      final fake = FakeNotificationRepository();
      final gate = Completer<void>();
      fake.updateGates[NotificationCategory.chat] = gate;
      fake.updateErrors[NotificationCategory.chat] = StateError('boom');
      final container = _container(fake);
      await container.read(notificationPreferencesProvider.future);
      final notifier = container.read(notificationPreferencesProvider.notifier);

      final first = notifier.setEnabled(NotificationCategory.chat, false);
      final firstOutcome = expectLater(first, throwsA(isA<StateError>()));
      await notifier.setEnabled(NotificationCategory.social, false);

      gate.complete();
      await firstOutcome;

      final prefs = container.read(notificationPreferencesProvider).value!;
      expect(prefs.chatEnabled, isTrue);
      expect(prefs.socialEnabled, isFalse);
    },
  );

  test('setEnabled() with the current value makes no call', () async {
    final fake = FakeNotificationRepository();
    final container = _container(fake);
    await container.read(notificationPreferencesProvider.future);

    await container
        .read(notificationPreferencesProvider.notifier)
        .setEnabled(NotificationCategory.chat, true);

    expect(fake.updateCalls, isEmpty);
  });
}
