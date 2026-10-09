import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/notifications/data/notification_repository_impl.dart';
import 'package:social_commerce_app/features/notifications/domain/app_notification.dart';
import 'package:social_commerce_app/features/notifications/domain/notification_preferences.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_center_screen.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_grouping.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_preferences_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import '../fake_notification_repository.dart';

/// Part P-115 (STEP 4): restyle checks for the notification center and the
/// notification preferences. The behaviour tests (tap, mark-read, paging,
/// toggling) stay in the P-082 test files, which are unchanged.
///
/// This file is ASCII only: Arabic text is read from the generated
/// localizations, never typed here.

AppNotification _at(int id, DateTime createdAt, {bool isRead = false}) {
  return AppNotification(
    id: id,
    notificationType: 'new_follower',
    title: 'Title $id',
    body: 'Body $id',
    deepLinkType: 'business_profile',
    targetId: 7,
    isRead: isRead,
    createdAt: createdAt,
  );
}

Future<void> _pumpCenter(
  WidgetTester tester,
  FakeNotificationRepository repository, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notificationRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        locale: locale,
        theme: theme ?? AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NotificationCenterScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPreferences(
  WidgetTester tester,
  FakeNotificationRepository repository, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notificationRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        locale: locale,
        theme: theme ?? AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NotificationPreferencesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _section(String name) =>
    find.byKey(ValueKey<String>('notification-section-$name'));

void main() {
  group('recency grouping', () {
    final DateTime now = DateTime(2026, 10, 9, 15, 0);

    test('section boundaries are calendar days, not 24-hour windows', () {
      expect(
        notificationSectionFor(DateTime(2026, 10, 9, 0, 1), now),
        NotificationSection.today,
      );
      expect(
        notificationSectionFor(DateTime(2026, 10, 8, 23, 59), now),
        NotificationSection.thisWeek,
      );
      expect(
        notificationSectionFor(DateTime(2026, 10, 3, 8, 0), now),
        NotificationSection.thisWeek,
      );
      expect(
        notificationSectionFor(DateTime(2026, 10, 2, 23, 0), now),
        NotificationSection.earlier,
      );
    });

    test('a time slightly in the future still counts as today', () {
      expect(
        notificationSectionFor(DateTime(2026, 10, 9, 15, 5), now),
        NotificationSection.today,
      );
    });

    test('sections are ordered, empty ones are left out, order is kept', () {
      final List<AppNotification> items = <AppNotification>[
        _at(1, DateTime(2026, 9, 1)),
        _at(2, DateTime(2026, 10, 9, 14)),
        _at(3, DateTime(2026, 10, 8, 10)),
        _at(4, DateTime(2026, 10, 9, 9)),
      ];

      final List<NotificationGroup> groups = groupNotificationsByRecency(
        items,
        now,
      );

      expect(
        groups.map((NotificationGroup g) => g.section),
        <NotificationSection>[
          NotificationSection.today,
          NotificationSection.thisWeek,
          NotificationSection.earlier,
        ],
      );
      expect(groups[0].items.map((AppNotification n) => n.id).toList(), <int>[
        2,
        4,
      ]);
      expect(groups[1].items.single.id, 3);
      expect(groups[2].items.single.id, 1);

      final List<NotificationGroup> onlyToday = groupNotificationsByRecency(
        <AppNotification>[_at(5, DateTime(2026, 10, 9, 1))],
        now,
      );
      expect(onlyToday, hasLength(1));
      expect(onlyToday.single.section, NotificationSection.today);
    });

    test('an empty list gives no groups', () {
      expect(groupNotificationsByRecency(<AppNotification>[], now), isEmpty);
    });
  });

  group('notification center', () {
    testWidgets('shows Today / This week / Earlier headers in English', (
      tester,
    ) async {
      final DateTime now = DateTime.now();
      final FakeNotificationRepository repository = FakeNotificationRepository(
        pages: {
          null: fakePage(<AppNotification>[
            _at(1, now),
            _at(2, now.subtract(const Duration(days: 3))),
            _at(3, now.subtract(const Duration(days: 30))),
          ]),
        },
      );

      await _pumpCenter(tester, repository);

      expect(_section('today'), findsOneWidget);
      expect(_section('thisWeek'), findsOneWidget);
      expect(_section('earlier'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('notification-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('notification-item-3')),
        findsOneWidget,
      );
    });

    testWidgets('a section with no items has no header', (tester) async {
      final FakeNotificationRepository repository = FakeNotificationRepository(
        pages: {
          null: fakePage(<AppNotification>[_at(1, DateTime.now())]),
        },
      );

      await _pumpCenter(tester, repository);

      expect(_section('today'), findsOneWidget);
      expect(_section('thisWeek'), findsNothing);
      expect(_section('earlier'), findsNothing);
    });

    testWidgets('Arabic dark: RTL and localized headers, no errors', (
      tester,
    ) async {
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final FakeNotificationRepository repository = FakeNotificationRepository(
        pages: {
          null: fakePage(<AppNotification>[
            _at(1, DateTime.now()),
            _at(
              2,
              DateTime.now().subtract(const Duration(days: 40)),
              isRead: true,
            ),
          ]),
        },
      );

      await _pumpCenter(
        tester,
        repository,
        locale: const Locale('ar'),
        theme: AppTheme.dark,
      );

      expect(
        Directionality.of(
          tester.element(find.byType(NotificationCenterScreen)),
        ),
        TextDirection.rtl,
      );
      expect(find.text(ar.notifSectionToday), findsOneWidget);
      expect(find.text(ar.notifSectionEarlier), findsOneWidget);
      expect(find.text(ar.notifTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Arabic dark: localized empty state', (tester) async {
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

      await _pumpCenter(
        tester,
        FakeNotificationRepository(
          pages: {null: fakePage(<AppNotification>[])},
        ),
        locale: const Locale('ar'),
        theme: AppTheme.dark,
      );

      expect(find.text(ar.notifEmpty), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the unread dot carries a semantic label', (tester) async {
      final FakeNotificationRepository repository = FakeNotificationRepository(
        pages: {
          null: fakePage(<AppNotification>[_at(1, DateTime.now())]),
        },
      );

      await _pumpCenter(tester, repository);

      final Semantics wrapper = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(
                const ValueKey<String>('notification-unread-dot-1'),
              ),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(wrapper.properties.label, 'Unread');
    });
  });

  group('notification preferences', () {
    testWidgets('three switches in one group, English light', (tester) async {
      await _pumpPreferences(tester, FakeNotificationRepository());

      expect(find.byType(SwitchListTile), findsNWidgets(3));
      expect(find.text('Chat messages'), findsOneWidget);
      expect(find.text('Content review'), findsOneWidget);
      expect(find.text('Social activity'), findsOneWidget);
      expect(
        find.text('Important system announcements are always delivered.'),
        findsOneWidget,
      );
    });

    testWidgets('Arabic dark: RTL, localized, and a toggle still saves', (
      tester,
    ) async {
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final FakeNotificationRepository repository =
          FakeNotificationRepository();

      await _pumpPreferences(
        tester,
        repository,
        locale: const Locale('ar'),
        theme: AppTheme.dark,
      );

      expect(
        Directionality.of(
          tester.element(find.byType(NotificationPreferencesScreen)),
        ),
        TextDirection.rtl,
      );
      expect(find.text(ar.notifPrefChatTitle), findsOneWidget);
      expect(find.text(ar.notifPrefsSystemFooter), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('notification-preference-chat')),
      );
      await tester.pumpAndSettle();

      expect(
        repository.updateCalls,
        <({NotificationCategory category, bool enabled})>[
          (category: NotificationCategory.chat, enabled: false),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });
}
