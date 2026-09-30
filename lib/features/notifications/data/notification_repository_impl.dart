import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/app_notification.dart';
import '../domain/notification_preferences.dart';
import '../domain/notification_repository.dart';

/// Part P-082: [NotificationRepository] over the shared Dio client (so the
/// Authorization header and silent token refresh come for free).
///
/// Error convention: same as `ConversationRepository` — catch
/// [DioException] and rethrow the typed [ApiFailure] that `ErrorInterceptor`
/// stored on `.error`, so callers only ever catch [ApiFailure].
class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const listPath = '/api/v1/notifications/';
  static const preferencesPath = '/api/v1/notifications/preferences/';
  static String readPath(int notificationId) =>
      '/api/v1/notifications/$notificationId/read/';

  @override
  Future<PaginatedResponse<AppNotification>> listNotifications({
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(cursor ?? listPath);
      return PaginatedResponse.fromJson(
        response.data!,
        AppNotification.fromJson,
      );
    } on DioException catch (e) {
      _rethrowTyped(e);
    }
  }

  @override
  Future<AppNotification> markAsRead(int notificationId) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        readPath(notificationId),
      );
      return AppNotification.fromJson(response.data!);
    } on DioException catch (e) {
      _rethrowTyped(e);
    }
  }

  @override
  Future<NotificationPreferences> fetchPreferences() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(preferencesPath);
      return NotificationPreferences.fromJson(response.data!);
    } on DioException catch (e) {
      _rethrowTyped(e);
    }
  }

  @override
  Future<NotificationPreferences> updatePreference({
    required NotificationCategory category,
    required bool enabled,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        preferencesPath,
        data: {category.jsonKey: enabled},
      );
      return NotificationPreferences.fromJson(response.data!);
    } on DioException catch (e) {
      _rethrowTyped(e);
    }
  }

  Never _rethrowTyped(DioException e) {
    final error = e.error;
    if (error is ApiFailure) throw error;
    throw e;
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(dio: ref.watch(dioClientProvider));
});
