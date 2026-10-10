import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_provider.dart';
import 'package:social_commerce_app/features/business_console/presentation/console_dashboard.dart';
import 'package:social_commerce_app/features/content/domain/content_item_entity.dart';
import 'package:social_commerce_app/features/content/presentation/own_content_provider.dart';
import 'package:social_commerce_app/features/moderation/domain/queue_item_entity.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_provider.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_queue_screen.dart';
import 'package:social_commerce_app/features/notifications/data/notification_repository_impl.dart';
import 'package:social_commerce_app/features/notifications/domain/app_notification.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_center_screen.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/presentation/own_products_provider.dart';
import 'package:social_commerce_app/features/stories/domain/own_story_entity.dart';
import 'package:social_commerce_app/features/stories/presentation/own_stories_provider.dart';

import '../features/notifications/fake_notification_repository.dart';
import 'golden_helpers.dart';

/// Part P-115 STEP 10B: goldens for the Notification Center, the Business
/// Console dashboard cards and the Moderation queue row (Staff), in
/// light_en, light_ar, dark_en, dark_ar. Images live in
/// `test/goldens/p115_screens/` and are created in STEP 10C (not here).
///
/// Offline and deterministic. NotificationCenterScreen groups with
/// DateTime.now() and formats with an AppFormatters that has no injectable
/// clock, so the data is built so the rendered text never changes:
///  - Today: 10 minutes in the future -> always "just now", always Today.
///  - This week: 3.5 and 5.5 days ago -> always "3 days ago" / "5 days ago".
///  - Earlier: a fixed old date -> always an absolute date.
/// The moderation row age comes from QueueItem.ageDuration (fixed).
/// This file is ASCII only.

const String _dir = 'p115_screens';

// --------------------------------------------------------------- notifications

AppNotification _notif(
  int id,
  String type,
  String title,
  String body,
  DateTime createdAt, {
  required bool isRead,
}) {
  return AppNotification(
    id: id,
    notificationType: type,
    title: title,
    body: body,
    deepLinkType: 'business_profile',
    targetId: 7,
    isRead: isRead,
    createdAt: createdAt,
  );
}

List<AppNotification> _notificationData() {
  final DateTime now = DateTime.now();
  return <AppNotification>[
    _notif(
      1,
      'new_follower',
      'New follower',
      'Nile Traders started following you.',
      now.add(const Duration(minutes: 10)),
      isRead: false,
    ),
    _notif(
      2,
      'chat_message',
      'New message',
      'Al Ananka Store sent you a message.',
      now.add(const Duration(minutes: 10)),
      isRead: true,
    ),
    _notif(
      3,
      'comment',
      'New comment',
      'Someone commented on your post.',
      now.subtract(const Duration(days: 3, hours: 12)),
      isRead: false,
    ),
    _notif(
      4,
      'moderation_result',
      'Post approved',
      'Your post is now live.',
      now.subtract(const Duration(days: 5, hours: 12)),
      isRead: true,
    ),
    _notif(
      5,
      'new_follower',
      'New follower',
      'Delta Leather started following you.',
      DateTime(2026, 1, 5, 12),
      isRead: true,
    ),
  ];
}

// --------------------------------------------------------------- console

class _FixedProducts extends OwnProductsNotifier {
  @override
  Future<List<Product>> build() async => <Product>[
    for (int i = 1; i <= 12; i++)
      Product(
        id: i,
        businessId: 7,
        categoryId: 1,
        name: 'Product $i',
        description: '',
        price: '100.00',
        currency: Currency.egp,
      ),
  ];
}

class _NoContent extends OwnContentNotifier {
  @override
  Future<List<ContentItem>> build() async => const <ContentItem>[];
}

class _NoStories extends OwnStoriesNotifier {
  @override
  Future<List<OwnStory>> build() async => const <OwnStory>[];
}

// --------------------------------------------------------------- moderation

class _FixedQueue extends ModerationQueueNotifier {
  _FixedQueue(this._items);

  final List<QueueItem> _items;

  @override
  Future<List<QueueItem>> build() async => _items;
}

QueueItem _queueItem(
  int id, {
  required String contentType,
  required QueuePriority priority,
  required Duration age,
  required String preview,
  required String business,
}) {
  return QueueItem(
    id: id,
    contentType: contentType,
    status: QueueItemStatus.pending,
    priority: priority,
    createdAt: DateTime.utc(2026, 1, 5, 10),
    ageDuration: age,
    previewText: preview,
    submitterBusinessName: business,
  );
}

final List<QueueItem> _queueData = <QueueItem>[
  _queueItem(
    1,
    contentType: 'post',
    priority: QueuePriority.normal,
    age: const Duration(minutes: 5),
    preview: 'New arrivals just landed.',
    business: 'Al Ananka Store',
  ),
  _queueItem(
    2,
    contentType: 'reel',
    priority: QueuePriority.fastPath,
    age: const Duration(minutes: 10),
    preview: 'Behind the scenes.',
    business: 'Nile Traders',
  ),
  _queueItem(
    3,
    contentType: 'story',
    priority: QueuePriority.fastPath,
    age: const Duration(minutes: 20),
    preview: 'Weekend sale.',
    business: 'Delta Leather',
  ),
  _queueItem(
    4,
    contentType: 'post',
    priority: QueuePriority.fastPath,
    age: const Duration(minutes: 31),
    preview: 'Limited edition bags.',
    business: 'Sphinx Studio',
  ),
];

// --------------------------------------------------------------- goldens

void main() {
  group('P-115 screens goldens', () {
    for (final GoldenCombo c in kGoldenCombos) {
      testWidgets('notification center (${c.tag})', (tester) async {
        await pumpGoldenApp(
          tester,
          c,
          const NotificationCenterScreen(),
          overrides: [
            notificationRepositoryProvider.overrideWithValue(
              FakeNotificationRepository(
                pages: {null: fakePage(_notificationData())},
              ),
            ),
          ],
        );
        await expectGolden(_dir, 'notification_center', c);
        await unmountGolden(tester);
      });

      testWidgets('console dashboard (${c.tag})', (tester) async {
        await pumpGoldenApp(
          tester,
          c,
          const Scaffold(body: ConsoleDashboardCards()),
          size: const Size(680, 160),
          overrides: [
            ownProductsProvider.overrideWith(_FixedProducts.new),
            ownContentProvider.overrideWith(_NoContent.new),
            ownStoriesProvider.overrideWith(_NoStories.new),
            analyticsStatsProvider.overrideWith((ref) async => <DailyStats>[]),
          ],
        );
        await expectGolden(_dir, 'console_dashboard', c);
        await unmountGolden(tester);
      });

      testWidgets('moderation queue row (${c.tag})', (tester) async {
        await pumpGoldenApp(
          tester,
          c,
          ModerationQueueScreen(onOpenItem: (item) {}),
          size: const Size(400, 900),
          overrides: [
            moderationQueueProvider.overrideWith(
              () => _FixedQueue(_queueData),
            ),
          ],
        );
        await expectGolden(_dir, 'moderation_queue', c);
        await unmountGolden(tester);
      });
    }
  });
}