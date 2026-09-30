import '../../../core/deep_link_resolver.dart';

/// Part P-082: one row of the in-app notification center, mirroring the
/// backend's `NotificationSerializer` (`notifications/serializers.py`)
/// exactly: `{id, notification_type, title, body, deep_link_type,
/// target_id, is_read, created_at}`.
///
/// Named `AppNotification`, not `Notification`, because Flutter's own
/// `Notification` class (widgets library) would collide with it.
///
/// `notification_type` answers WHY the notification exists (icon,
/// wording); `deep_link_type` + `target_id` answer WHERE tapping it goes.
/// They stay separate fields on purpose (see the backend model's
/// docstring).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.deepLinkType,
    required this.targetId,
    required this.isRead,
    required this.createdAt,
  });

  final int id;

  /// Raw backend value, e.g. `new_follower`, `chat_message`,
  /// `moderation_rejected`. Kept as a string so a type added by a later
  /// backend phase never crashes parsing.
  final String notificationType;
  final String title;
  final String body;

  /// Raw `deep_link_type`; blank (`''`) when the notification navigates
  /// nowhere (e.g. `system_announcement`).
  final String deepLinkType;

  /// Id of the thing to open, or `null` when there is none.
  final int? targetId;
  final bool isRead;
  final DateTime createdAt;

  /// `false` for a notification that navigates nowhere. Tapping such an
  /// item should only mark it read: [route] would answer the `/home`
  /// fallback, which is wrong for "no destination".
  bool get hasDeepLink => deepLinkType.trim().isNotEmpty;

  /// The route to open, via P-080's [resolveDeepLink] (the single
  /// navigation-resolution mechanism for every notification-tap source).
  /// Never throws; falls back to [deepLinkFallbackRoute] for an unknown
  /// type or a missing/invalid id.
  String get route => resolveDeepLink(deepLinkType, targetId);

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      notificationType: notificationType,
      title: title,
      body: body,
      deepLinkType: deepLinkType,
      targetId: targetId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      notificationType: json['notification_type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      deepLinkType: (json['deep_link_type'] as String?) ?? '',
      targetId: json['target_id'] as int?,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
