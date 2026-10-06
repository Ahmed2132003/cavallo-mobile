import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/shell/home_top_bar.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/chat/presentation/chat_unread_provider.dart';
import 'package:social_commerce_app/features/notifications/data/notification_repository_impl.dart';
import 'package:social_commerce_app/features/notifications/domain/app_notification.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

import '../../features/notifications/fake_notification_repository.dart';

/// Part P-113 (STEP 5): the Home top bar.

class _FakeSession extends SessionNotifier {
  _FakeSession(this._user);

  final User? _user;

  @override
  Future<User?> build() async => _user;
}

const User _customer = User(
  id: 1,
  email: 'customer@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

const String _arNotifications =
    '\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a';
const String _arChats =
    '\u0627\u0644\u0645\u062d\u0627\u062f\u062b\u0627\u062a';

int _chatReads = 0;

Future<FakeNotificationRepository> _pump(
  WidgetTester tester, {
  User? user = _customer,
  List<AppNotification> notifications = const <AppNotification>[],
  int chatUnread = 0,
  Locale locale = const Locale('en'),
}) async {
  _chatReads = 0;
  final FakeNotificationRepository repository = FakeNotificationRepository(
    pages: {null: fakePage(notifications)},
  );
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder:
            (BuildContext context, GoRouterState state) => const Scaffold(
              appBar: HomeTopBar(
                extraActions: <Widget>[SizedBox(key: Key('extra'), width: 8)],
              ),
              body: SizedBox.shrink(),
            ),
      ),
      GoRoute(
        path: '/notifications',
        name: RouteNames.notifications,
        builder:
            (BuildContext context, GoRouterState state) =>
                Scaffold(appBar: AppBar(), body: const Text('stub:notif')),
      ),
      GoRoute(
        path: '/chats',
        name: RouteNames.chatList,
        builder:
            (BuildContext context, GoRouterState state) =>
                Scaffold(appBar: AppBar(), body: const Text('stub:chats')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _FakeSession(user)),
        notificationRepositoryProvider.overrideWithValue(repository),
        chatUnreadCountProvider.overrideWith((ref) async {
          _chatReads++;
          return chatUnread;
        }),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Finder _badgeIn(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(Badge));

Finder _badgeText(Key key, String text) =>
    find.descendant(of: _badgeIn(key), matching: find.text(text));

void main() {
  testWidgets('shows the wordmark, the bell, the chats icon and extras', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(HomeTopBar.wordmarkKey), findsOneWidget);
    expect(find.text('Cavallo'), findsOneWidget);
    expect(find.byKey(HomeTopBar.notificationsKey), findsOneWidget);
    expect(find.byKey(HomeTopBar.chatsKey), findsOneWidget);
    expect(find.byKey(const Key('extra')), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Chats'), findsOneWidget);
  });

  testWidgets('draws no badge when both counts are zero', (tester) async {
    await _pump(tester);

    expect(_badgeIn(HomeTopBar.notificationsKey), findsNothing);
    expect(_badgeIn(HomeTopBar.chatsKey), findsNothing);
  });

  testWidgets('the bell badge counts only unread notifications', (
    tester,
  ) async {
    await _pump(
      tester,
      notifications: <AppNotification>[
        fakeNotification(1),
        fakeNotification(2),
        fakeNotification(3, isRead: true),
      ],
    );

    expect(_badgeText(HomeTopBar.notificationsKey, '2'), findsOneWidget);
    expect(_badgeIn(HomeTopBar.chatsKey), findsNothing);
  });

  testWidgets('the chats badge shows the unread message count', (tester) async {
    await _pump(tester, chatUnread: 5);

    expect(_badgeText(HomeTopBar.chatsKey, '5'), findsOneWidget);
    expect(_badgeIn(HomeTopBar.notificationsKey), findsNothing);
  });

  testWidgets('a count above 99 is shown as 99+', (tester) async {
    await _pump(tester, chatUnread: 120);

    expect(_badgeText(HomeTopBar.chatsKey, '99+'), findsOneWidget);
  });

  testWidgets('signed out: no badges and no request is made', (tester) async {
    final FakeNotificationRepository repository = await _pump(
      tester,
      user: null,
      notifications: <AppNotification>[fakeNotification(1)],
      chatUnread: 4,
    );

    expect(_badgeIn(HomeTopBar.notificationsKey), findsNothing);
    expect(_badgeIn(HomeTopBar.chatsKey), findsNothing);
    expect(repository.listCursors, isEmpty);
    expect(_chatReads, 0);
  });

  testWidgets('signed in: each count is requested once (no polling)', (
    tester,
  ) async {
    final FakeNotificationRepository repository = await _pump(
      tester,
      notifications: <AppNotification>[fakeNotification(1)],
      chatUnread: 1,
    );

    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();

    expect(repository.listCursors.length, 1);
    expect(_chatReads, 1);
  });

  testWidgets('the bell opens the notification center', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(HomeTopBar.notificationsKey));
    await tester.pumpAndSettle();

    expect(find.text('stub:notif'), findsOneWidget);
  });

  testWidgets('the chats icon opens the chats list', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(HomeTopBar.chatsKey));
    await tester.pumpAndSettle();

    expect(find.text('stub:chats'), findsOneWidget);
  });

  testWidgets('English: wordmark at the start (left), icons at the end', (
    tester,
  ) async {
    await _pump(tester);

    final double wordmarkX =
        tester.getCenter(find.byKey(HomeTopBar.wordmarkKey)).dx;
    final double bellX =
        tester.getCenter(find.byKey(HomeTopBar.notificationsKey)).dx;
    final double chatsX = tester.getCenter(find.byKey(HomeTopBar.chatsKey)).dx;

    expect(wordmarkX, lessThan(bellX));
    expect(bellX, lessThan(chatsX));
  });

  testWidgets('Arabic: layout mirrors and tooltips are Arabic', (tester) async {
    await _pump(tester, locale: const Locale('ar'));

    final double wordmarkX =
        tester.getCenter(find.byKey(HomeTopBar.wordmarkKey)).dx;
    final double bellX =
        tester.getCenter(find.byKey(HomeTopBar.notificationsKey)).dx;
    final double chatsX = tester.getCenter(find.byKey(HomeTopBar.chatsKey)).dx;

    expect(wordmarkX, greaterThan(bellX));
    expect(bellX, greaterThan(chatsX));
    expect(find.byTooltip(_arNotifications), findsOneWidget);
    expect(find.byTooltip(_arChats), findsOneWidget);
  });
}
