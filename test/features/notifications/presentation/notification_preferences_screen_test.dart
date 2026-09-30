import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/notifications/data/notification_repository_impl.dart';
import 'package:social_commerce_app/features/notifications/domain/notification_preferences.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_preferences_screen.dart';

import '../fake_notification_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeNotificationRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notificationRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: NotificationPreferencesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _switch(NotificationCategory category) =>
    find.byKey(ValueKey('notification-preference-${category.name}'));

bool _isOn(WidgetTester tester, NotificationCategory category) =>
    tester.widget<SwitchListTile>(_switch(category)).value;

void main() {
  testWidgets('shows the three switches with the values from the server', (
    tester,
  ) async {
    final repository = FakeNotificationRepository(
      preferences: const NotificationPreferences(moderationEnabled: false),
    );

    await _pump(tester, repository);

    expect(_isOn(tester, NotificationCategory.chat), isTrue);
    expect(_isOn(tester, NotificationCategory.moderation), isFalse);
    expect(_isOn(tester, NotificationCategory.social), isTrue);
    expect(repository.fetchPreferencesCalls, 1);
  });

  testWidgets('toggling a switch sends exactly that category and value', (
    tester,
  ) async {
    final repository = FakeNotificationRepository();
    await _pump(tester, repository);

    await tester.tap(_switch(NotificationCategory.chat));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, [
      (category: NotificationCategory.chat, enabled: false),
    ]);
    expect(_isOn(tester, NotificationCategory.chat), isFalse);
    expect(_isOn(tester, NotificationCategory.social), isTrue);
  });

  testWidgets('a failed save puts the switch back and shows a message', (
    tester,
  ) async {
    final repository = FakeNotificationRepository();
    repository.updateErrors[NotificationCategory.social] = Exception('boom');
    await _pump(tester, repository);

    await tester.tap(_switch(NotificationCategory.social));
    await tester.pumpAndSettle();

    expect(_isOn(tester, NotificationCategory.social), isTrue);
    expect(
      find.text('Could not save your preference. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('says that system announcements are always delivered', (
    tester,
  ) async {
    await _pump(tester, FakeNotificationRepository());

    expect(
      find.text('Important system announcements are always delivered.'),
      findsOneWidget,
    );
  });
}
