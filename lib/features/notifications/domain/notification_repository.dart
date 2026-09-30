import '../../../core/network/paginated_response.dart';
import 'app_notification.dart';
import 'notification_preferences.dart';

/// Part P-082: what the notification center needs from the backend
/// (`notifications/views.py`, P-082 STEP 1).
///
/// Every method throws a typed `ApiFailure` (never a raw `DioException`).
abstract class NotificationRepository {
  /// `GET /api/v1/notifications/` — the caller's own notifications,
  /// newest first. [cursor] is the opaque full `next` URL from a previous
  /// page; omit it for the first page.
  Future<PaginatedResponse<AppNotification>> listNotifications({
    String? cursor,
  });

  /// `PATCH /api/v1/notifications/{id}/read/` — idempotent. Returns the
  /// notification as the server now has it. A notification that belongs
  /// to somebody else answers 404, same as one that does not exist.
  Future<AppNotification> markAsRead(int notificationId);

  /// `GET /api/v1/notifications/preferences/`.
  Future<NotificationPreferences> fetchPreferences();

  /// `PATCH /api/v1/notifications/preferences/` with ONLY [category]'s
  /// key in the body. Returns all three toggles as the server now has
  /// them.
  Future<NotificationPreferences> updatePreference({
    required NotificationCategory category,
    required bool enabled,
  });
}
