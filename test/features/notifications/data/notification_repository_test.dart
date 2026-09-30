import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/notifications/data/notification_repository_impl.dart';
import 'package:social_commerce_app/features/notifications/domain/notification_preferences.dart';

import '../../chat/data/fake_http_client_adapter.dart';

Map<String, dynamic> _item(
  int id, {
  bool isRead = false,
  String deepLinkType = 'business_profile',
  int? targetId = 7,
}) => {
  'id': id,
  'notification_type': 'new_follower',
  'title': 'Title $id',
  'body': 'Body $id',
  'deep_link_type': deepLinkType,
  'target_id': targetId,
  'is_read': isRead,
  'created_at': '2026-09-28T10:00:00Z',
};

void main() {
  late FakeHttpClientAdapter adapter;
  late NotificationRepositoryImpl repository;

  setUp(() {
    adapter = FakeHttpClientAdapter();
    final dio =
        Dio(BaseOptions(baseUrl: 'http://test.local'))
          ..httpClientAdapter = adapter
          ..interceptors.add(ErrorInterceptor());
    repository = NotificationRepositoryImpl(dio: dio);
  });

  group('listNotifications', () {
    test(
      'GETs the list path and parses a page, including a blank link',
      () async {
        adapter.enqueue(
          statusCode: 200,
          data: {
            'results': [
              _item(2, isRead: true),
              _item(1, deepLinkType: '', targetId: null),
            ],
            'next': 'http://test.local/api/v1/notifications/?cursor=abc',
            'previous': null,
          },
        );

        final page = await repository.listNotifications();

        expect(page.results, hasLength(2));
        expect(page.results[0].isRead, isTrue);
        expect(page.results[1].deepLinkType, '');
        expect(page.results[1].targetId, isNull);
        expect(page.next, 'http://test.local/api/v1/notifications/?cursor=abc');
        final request = adapter.requestedOptions.single;
        expect(request.method, 'GET');
        expect(request.path, '/api/v1/notifications/');
      },
    );

    test('requests the exact cursor URL it is given', () async {
      adapter.enqueue(
        statusCode: 200,
        data: {'results': [], 'next': null, 'previous': null},
      );
      const cursor = 'http://test.local/api/v1/notifications/?cursor=abc';

      final page = await repository.listNotifications(cursor: cursor);

      expect(page.results, isEmpty);
      expect(page.next, isNull);
      expect(adapter.requestedOptions.single.uri.toString(), cursor);
    });

    test('an unauthenticated response becomes an AuthFailure', () async {
      adapter.enqueue(
        statusCode: 401,
        data: {
          'error': {'code': 'NOT_AUTHENTICATED', 'message': 'Sign in first.'},
        },
      );

      await expectLater(
        repository.listNotifications(),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('markAsRead', () {
    test('PATCHes the read path and parses the notification', () async {
      adapter.enqueue(statusCode: 200, data: _item(5, isRead: true));

      final notification = await repository.markAsRead(5);

      expect(notification.id, 5);
      expect(notification.isRead, isTrue);
      final request = adapter.requestedOptions.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/api/v1/notifications/5/read/');
    });

    test('a 404 surfaces the backend message as a typed failure', () async {
      adapter.enqueue(
        statusCode: 404,
        data: {
          'error': {'code': 'NOT_FOUND', 'message': 'Notification not found.'},
        },
      );

      await expectLater(
        repository.markAsRead(999),
        throwsA(
          isA<UnknownFailure>().having(
            (f) => f.message,
            'message',
            'Notification not found.',
          ),
        ),
      );
    });
  });

  group('preferences', () {
    test('fetchPreferences GETs the preferences path', () async {
      adapter.enqueue(
        statusCode: 200,
        data: {
          'chat_notifications_enabled': true,
          'moderation_notifications_enabled': false,
          'social_notifications_enabled': true,
        },
      );

      final prefs = await repository.fetchPreferences();

      expect(prefs.chatEnabled, isTrue);
      expect(prefs.moderationEnabled, isFalse);
      expect(prefs.socialEnabled, isTrue);
      final request = adapter.requestedOptions.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/notifications/preferences/');
    });

    test('updatePreference PATCHes exactly one key', () async {
      adapter.enqueue(
        statusCode: 200,
        data: {
          'chat_notifications_enabled': true,
          'moderation_notifications_enabled': true,
          'social_notifications_enabled': false,
        },
      );

      final prefs = await repository.updatePreference(
        category: NotificationCategory.social,
        enabled: false,
      );

      expect(prefs.socialEnabled, isFalse);
      final request = adapter.requestedOptions.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/api/v1/notifications/preferences/');
      expect(request.data, {'social_notifications_enabled': false});
    });
  });
}
