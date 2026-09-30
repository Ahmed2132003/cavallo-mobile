/// Part P-082: the three notification categories a user can toggle,
/// matching the backend's `NotificationPreference` model (Part P-078).
///
/// `system_announcement` has no toggle: it is always delivered.
///
/// [jsonKey] is the exact field name the backend's
/// `NotificationPreferenceSerializer` reads and writes. It is pinned by a
/// test, because a typo here would make the PATCH silently change nothing.
enum NotificationCategory {
  chat('chat_notifications_enabled'),
  moderation('moderation_notifications_enabled'),
  social('social_notifications_enabled');

  const NotificationCategory(this.jsonKey);

  final String jsonKey;
}

/// The user's three category toggles. Every category defaults to enabled,
/// matching the backend (a missing row means "everything enabled").
class NotificationPreferences {
  const NotificationPreferences({
    this.chatEnabled = true,
    this.moderationEnabled = true,
    this.socialEnabled = true,
  });

  final bool chatEnabled;
  final bool moderationEnabled;
  final bool socialEnabled;

  bool isEnabled(NotificationCategory category) => switch (category) {
    NotificationCategory.chat => chatEnabled,
    NotificationCategory.moderation => moderationEnabled,
    NotificationCategory.social => socialEnabled,
  };

  /// A copy with ONLY [category] changed.
  NotificationPreferences withCategory(
    NotificationCategory category,
    bool enabled,
  ) => switch (category) {
    NotificationCategory.chat => copyWith(chatEnabled: enabled),
    NotificationCategory.moderation => copyWith(moderationEnabled: enabled),
    NotificationCategory.social => copyWith(socialEnabled: enabled),
  };

  NotificationPreferences copyWith({
    bool? chatEnabled,
    bool? moderationEnabled,
    bool? socialEnabled,
  }) {
    return NotificationPreferences(
      chatEnabled: chatEnabled ?? this.chatEnabled,
      moderationEnabled: moderationEnabled ?? this.moderationEnabled,
      socialEnabled: socialEnabled ?? this.socialEnabled,
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      chatEnabled: json[NotificationCategory.chat.jsonKey] as bool,
      moderationEnabled: json[NotificationCategory.moderation.jsonKey] as bool,
      socialEnabled: json[NotificationCategory.social.jsonKey] as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.chatEnabled == chatEnabled &&
      other.moderationEnabled == moderationEnabled &&
      other.socialEnabled == socialEnabled;

  @override
  int get hashCode =>
      Object.hash(chatEnabled, moderationEnabled, socialEnabled);
}
