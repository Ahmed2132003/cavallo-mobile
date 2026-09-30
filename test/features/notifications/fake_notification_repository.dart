import 'dart:async';

import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/notifications/domain/app_notification.dart';
import 'package:social_commerce_app/features/notifications/domain/notification_preferences.dart';
import 'package:social_commerce_app/features/notifications/domain/notification_repository.dart';

AppNotification fakeNotification(
  int id, {
  bool isRead = false,
  String deepLinkType = 'business_profile',
  int? targetId = 7,
}) {
  return AppNotification(
    id: id,
    notificationType: 'new_follower',
    title: 'Title $id',
    body: 'Body $id',
    deepLinkType: deepLinkType,
    targetId: targetId,
    isRead: isRead,
    createdAt: DateTime.utc(2026, 9, 28, 10, 0, id),
  );
}

PaginatedResponse<AppNotification> fakePage(
  List<AppNotification> items, {
  String? next,
}) {
  return PaginatedResponse<AppNotification>(
    results: items,
    next: next,
    previous: null,
  );
}

/// Hand-rolled fake (same convention as the project's other fakes).
///
/// - [pages]: keyed by the cursor that returns it (`null` = first page).
/// - [listErrors] / [markReadError] / [updateErrors]: make a call throw.
/// - [updateGates]: make an update wait until the test completes the gate,
///   so a test can look at the optimistic state first.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({
    Map<String?, PaginatedResponse<AppNotification>>? pages,
    NotificationPreferences? preferences,
  }) : pages = pages ?? {},
       serverPreferences = preferences ?? const NotificationPreferences();

  final Map<String?, PaginatedResponse<AppNotification>> pages;
  NotificationPreferences serverPreferences;

  final List<String?> listCursors = [];
  final List<int> markReadCalls = [];
  final List<({NotificationCategory category, bool enabled})> updateCalls = [];
  int fetchPreferencesCalls = 0;

  final Map<String?, Object> listErrors = {};
  Object? markReadError;
  final Map<NotificationCategory, Object> updateErrors = {};
  final Map<NotificationCategory, Completer<void>> updateGates = {};

  @override
  Future<PaginatedResponse<AppNotification>> listNotifications({
    String? cursor,
  }) async {
    listCursors.add(cursor);
    final error = listErrors[cursor];
    if (error != null) throw error;
    final page = pages[cursor];
    if (page == null) {
      throw StateError('Unexpected cursor requested: $cursor');
    }
    return page;
  }

  @override
  Future<AppNotification> markAsRead(int notificationId) async {
    markReadCalls.add(notificationId);
    final error = markReadError;
    if (error != null) throw error;
    for (final page in pages.values) {
      for (final notification in page.results) {
        if (notification.id == notificationId) {
          return notification.copyWith(isRead: true);
        }
      }
    }
    return fakeNotification(notificationId, isRead: true);
  }

  @override
  Future<NotificationPreferences> fetchPreferences() async {
    fetchPreferencesCalls++;
    return serverPreferences;
  }

  @override
  Future<NotificationPreferences> updatePreference({
    required NotificationCategory category,
    required bool enabled,
  }) async {
    updateCalls.add((category: category, enabled: enabled));
    final gate = updateGates[category];
    if (gate != null) await gate.future;
    final error = updateErrors[category];
    if (error != null) throw error;
    serverPreferences = serverPreferences.withCategory(category, enabled);
    return serverPreferences;
  }
}
