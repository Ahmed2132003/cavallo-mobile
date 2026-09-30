import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/deep_link_resolver.dart';
import 'package:social_commerce_app/features/notifications/domain/app_notification.dart';

Map<String, dynamic> _json({
  String deepLinkType = 'business_profile',
  Object? targetId = 7,
}) => {
  'id': 12,
  'notification_type': 'new_follower',
  'title': 'New follower',
  'body': 'Someone started following your business.',
  'deep_link_type': deepLinkType,
  'target_id': targetId,
  'is_read': false,
  'created_at': '2026-09-28T10:15:00Z',
};

void main() {
  test('fromJson parses every field of the backend payload', () {
    final n = AppNotification.fromJson(_json());

    expect(n.id, 12);
    expect(n.notificationType, 'new_follower');
    expect(n.title, 'New follower');
    expect(n.body, 'Someone started following your business.');
    expect(n.deepLinkType, 'business_profile');
    expect(n.targetId, 7);
    expect(n.isRead, isFalse);
    expect(n.createdAt, DateTime.utc(2026, 9, 28, 10, 15));
  });

  test('fromJson tolerates a blank deep_link_type and a null target_id', () {
    final n = AppNotification.fromJson(_json(deepLinkType: '', targetId: null));

    expect(n.deepLinkType, '');
    expect(n.targetId, isNull);
  });

  test('hasDeepLink is false for a blank type and true otherwise', () {
    expect(
      AppNotification.fromJson(_json(deepLinkType: '')).hasDeepLink,
      isFalse,
    );
    expect(AppNotification.fromJson(_json()).hasDeepLink, isTrue);
  });

  test('route delegates to resolveDeepLink (P-080)', () {
    final n = AppNotification.fromJson(_json());

    expect(n.route, '/business/7');
    expect(n.route, resolveDeepLink('business_profile', 7));
  });

  test('route falls back to the P-080 fallback when the type is blank', () {
    final n = AppNotification.fromJson(_json(deepLinkType: '', targetId: null));

    expect(n.route, deepLinkFallbackRoute);
  });

  test('copyWith(isRead) changes only isRead', () {
    final original = AppNotification.fromJson(_json());

    final read = original.copyWith(isRead: true);

    expect(read.isRead, isTrue);
    expect(read.id, original.id);
    expect(read.title, original.title);
    expect(read.deepLinkType, original.deepLinkType);
    expect(read.targetId, original.targetId);
    expect(read.createdAt, original.createdAt);
    expect(original.isRead, isFalse);
  });
}
