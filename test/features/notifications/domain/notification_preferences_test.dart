import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/notifications/domain/notification_preferences.dart';

void main() {
  test('every category is enabled by default', () {
    const prefs = NotificationPreferences();

    for (final category in NotificationCategory.values) {
      expect(prefs.isEnabled(category), isTrue);
    }
  });

  test('fromJson reads the three backend keys', () {
    final prefs = NotificationPreferences.fromJson({
      'chat_notifications_enabled': false,
      'moderation_notifications_enabled': true,
      'social_notifications_enabled': false,
    });

    expect(prefs.chatEnabled, isFalse);
    expect(prefs.moderationEnabled, isTrue);
    expect(prefs.socialEnabled, isFalse);
  });

  test('isEnabled answers per category', () {
    const prefs = NotificationPreferences(
      chatEnabled: false,
      moderationEnabled: true,
      socialEnabled: false,
    );

    expect(prefs.isEnabled(NotificationCategory.chat), isFalse);
    expect(prefs.isEnabled(NotificationCategory.moderation), isTrue);
    expect(prefs.isEnabled(NotificationCategory.social), isFalse);
  });

  test('withCategory changes only the named category', () {
    const prefs = NotificationPreferences();

    final changed = prefs.withCategory(NotificationCategory.moderation, false);

    expect(changed.chatEnabled, isTrue);
    expect(changed.moderationEnabled, isFalse);
    expect(changed.socialEnabled, isTrue);
    expect(prefs.moderationEnabled, isTrue);
  });

  test('jsonKey values are the locked backend field names', () {
    expect(NotificationCategory.chat.jsonKey, 'chat_notifications_enabled');
    expect(
      NotificationCategory.moderation.jsonKey,
      'moderation_notifications_enabled',
    );
    expect(NotificationCategory.social.jsonKey, 'social_notifications_enabled');
  });

  test('equality and hashCode compare all three toggles', () {
    const a = NotificationPreferences(socialEnabled: false);
    const b = NotificationPreferences(socialEnabled: false);
    const c = NotificationPreferences();

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });
}
