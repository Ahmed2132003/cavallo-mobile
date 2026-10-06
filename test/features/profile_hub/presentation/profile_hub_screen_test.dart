import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/profile_hub_screen.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/settings_rows.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/navigation_manifest.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-113 (STEP 3A): widget tests of the Profile & Settings hub.
///
/// * the rows drawn for each account type are EXACTLY the rows the navigation
///   manifest lists as hub rows (plus the "About" row, which is not a
///   destination), so the hub and the manifest cannot drift apart;
/// * header, Business tools, Moderation badge and Featured status;
/// * every row opens the right route;
/// * Log out asks first and signs out only after the confirmation;
/// * the screen works in Arabic and mirrors.

const String _arTitle =
    '\u0627\u0644\u062d\u0633\u0627\u0628 '
    '\u0648\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a';
const String _arLogOut =
    '\u062a\u0633\u062c\u064a\u0644 '
    '\u0627\u0644\u062e\u0631\u0648\u062c';

class _FakeSession extends SessionNotifier {
  _FakeSession(this._user);

  final User? _user;
  int logoutCalls = 0;

  @override
  Future<User?> build() async => _user;

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncValue<User?>.data(null);
  }
}

const User _customer = User(
  id: 1,
  email: 'customer@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

const User _business = User(
  id: 2,
  email: 'business@example.com',
  accountType: AccountType.business,
  isModerator: false,
  isStaff: false,
);

const User _staff = User(
  id: 3,
  email: 'staff@example.com',
  accountType: AccountType.customer,
  isModerator: true,
  isStaff: false,
);

BusinessProfile _profile({bool featured = false}) {
  return BusinessProfile(
    id: 1,
    businessName: 'Roots Atelier',
    businessType: BusinessType.trader,
    country: 'EG',
    city: 'Cairo',
    isVerified: false,
    isFeatured: featured,
  );
}

/// Every destination a hub row can open, as a stub screen that prints
/// `stub:<route name>`, so a test can see where a tap landed.
GoRouter _stubRouter() {
  GoRoute stub(String name, String path) {
    return GoRoute(
      path: path,
      name: name,
      builder:
          (BuildContext context, GoRouterState state) =>
              Scaffold(body: Center(child: Text('stub:$name'))),
    );
  }

  return GoRouter(
    initialLocation: RouteNames.profilePath,
    routes: <RouteBase>[
      GoRoute(
        path: RouteNames.profilePath,
        name: RouteNames.profile,
        builder:
            (BuildContext context, GoRouterState state) =>
                const ProfileHubScreen(),
      ),
      stub(RouteNames.saved, RouteNames.savedPath),
      stub(RouteNames.moderation, RouteNames.moderationPath),
      stub(
        RouteNames.notificationPreferences,
        RouteNames.notificationPreferencesPath,
      ),
      stub(RouteNames.businessProfileEdit, RouteNames.businessProfileEditPath),
      stub(RouteNames.businessConsole, RouteNames.businessConsolePath),
      stub(RouteNames.productList, RouteNames.productListPath),
      stub(RouteNames.contentList, RouteNames.contentListPath),
      stub(RouteNames.storyList, RouteNames.storyListPath),
      stub(RouteNames.businessAnalytics, RouteNames.businessAnalyticsPath),
    ],
  );
}

Future<_FakeSession> _pump(
  WidgetTester tester, {
  required User user,
  BusinessProfile? business,
  int pending = 0,
  Locale locale = const Locale('en'),
}) async {
  // Tall surface so every row of the ListView is built.
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final _FakeSession session = _FakeSession(user);
  final GoRouter router = _stubRouter();
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => session),
        hubBusinessProfileProvider.overrideWithValue(business),
        hubModerationPendingCountProvider.overrideWithValue(pending),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

Finder _row(String id) => find.byKey(ProfileHubScreen.rowKey(id));

/// The ids of every hub row currently drawn.
Set<String> _drawnRowIds(WidgetTester tester) {
  const String prefix = 'hub-row-';
  final Finder rows = find.byWidgetPredicate((Widget widget) {
    final Key? key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
  });
  return tester
      .widgetList(rows)
      .map((Widget w) => (w.key! as ValueKey<String>).value.substring(prefix.length))
      .toSet();
}

void main() {
  group('P-113 STEP 3A: hub rows follow the navigation manifest', () {
    final Map<NavAudience, User> users = <NavAudience, User>{
      NavAudience.customer: _customer,
      NavAudience.business: _business,
      NavAudience.staff: _staff,
    };

    for (final MapEntry<NavAudience, User> entry in users.entries) {
      testWidgets(
        '${entry.key.name}: draws every manifest hub row and nothing else',
        (WidgetTester tester) async {
          await _pump(
            tester,
            user: entry.value,
            business:
                entry.key == NavAudience.business ? _profile() : null,
          );

          final Set<String> expected = <String>{
            ...hubRowIdsFor(entry.key),
            ProfileHubScreen.aboutId,
          };
          expect(_drawnRowIds(tester), expected);
        },
      );
    }

    test('the manifest lists at least Saved, notification preferences, '
        'appearance, language and log out for everyone', () {
      for (final NavAudience audience in NavAudience.values) {
        expect(
          hubRowIdsFor(audience),
          containsAll(<String>[
            RouteNames.saved,
            RouteNames.notificationPreferences,
            kNavAppearanceId,
            kNavLanguageId,
            kNavLogoutId,
          ]),
          reason: audience.name,
        );
      }
    });
  });

  group('P-113 STEP 3A: header and groups', () {
    testWidgets('Customer: email, Customer chip, no Business or Moderation', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _customer);

      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(find.text('customer@example.com'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ProfileHubScreen.accountTypeChipKey),
          matching: find.text('Customer'),
        ),
        findsOneWidget,
      );
      expect(find.text('Business tools'), findsNothing);
      expect(find.text('Moderation'), findsNothing);
      expect(find.byKey(ProfileHubScreen.featuredStatusKey), findsNothing);
    });

    testWidgets('Business: business name, email line, Business chip, tools', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _business, business: _profile());

      expect(find.text('Roots Atelier'), findsOneWidget);
      expect(find.text('business@example.com'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ProfileHubScreen.accountTypeChipKey),
          matching: find.text('Business'),
        ),
        findsOneWidget,
      );
      expect(find.text('Business tools'), findsOneWidget);
      expect(find.text('Edit business profile'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Stories'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Moderation'), findsNothing);
    });

    testWidgets('Business without a loaded profile falls back to the email', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _business);

      expect(find.text('business@example.com'), findsOneWidget);
      expect(find.byKey(ProfileHubScreen.featuredStatusKey), findsNothing);
    });

    testWidgets('Featured status: "Not featured" when the business is not', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _business, business: _profile());

      expect(find.byKey(ProfileHubScreen.featuredStatusKey), findsOneWidget);
      expect(find.text('Not featured'), findsOneWidget);
      expect(find.byType(FeaturedBadge), findsNothing);
    });

    testWidgets('Featured status: the Featured badge when it is', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _business, business: _profile(featured: true));

      expect(find.byType(FeaturedBadge), findsOneWidget);
      expect(find.text('Not featured'), findsNothing);
    });

    testWidgets('Featured status row is display only (no navigation)', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _business, business: _profile(featured: true));

      final ListTile tile = tester.widget<ListTile>(
        find.descendant(
          of: find.byKey(ProfileHubScreen.featuredStatusKey),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile.onTap, isNull);
    });

    testWidgets('Staff: Moderation group with the pending count badge', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _staff, pending: 7);

      expect(find.text('Moderation'), findsOneWidget);
      expect(find.text('Moderation queue'), findsOneWidget);
      expect(find.byKey(ProfileHubScreen.moderationBadgeKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ProfileHubScreen.moderationBadgeKey),
          matching: find.text('7'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ProfileHubScreen.accountTypeChipKey),
          matching: find.text('Staff'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Staff: no badge when nothing is pending', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _staff, pending: 0);

      expect(_row(RouteNames.moderation), findsOneWidget);
      expect(find.byKey(ProfileHubScreen.moderationBadgeKey), findsNothing);
    });
  });

  group('P-113 STEP 3A: rows open the right screen', () {
    Future<void> expectTapOpens(
      WidgetTester tester, {
      required User user,
      required String rowId,
      required String routeName,
      BusinessProfile? business,
    }) async {
      await _pump(tester, user: user, business: business);
      await tester.tap(_row(rowId));
      await tester.pumpAndSettle();
      expect(find.text('stub:$routeName'), findsOneWidget);
    }

    testWidgets('Saved', (WidgetTester tester) async {
      await expectTapOpens(
        tester,
        user: _customer,
        rowId: RouteNames.saved,
        routeName: RouteNames.saved,
      );
    });

    testWidgets('Notification preferences', (WidgetTester tester) async {
      await expectTapOpens(
        tester,
        user: _customer,
        rowId: RouteNames.notificationPreferences,
        routeName: RouteNames.notificationPreferences,
      );
    });

    for (final String route in <String>[
      RouteNames.businessConsole,
      RouteNames.businessProfileEdit,
      RouteNames.productList,
      RouteNames.contentList,
      RouteNames.storyList,
      RouteNames.businessAnalytics,
    ]) {
      testWidgets('Business tools row: $route', (WidgetTester tester) async {
        await expectTapOpens(
          tester,
          user: _business,
          business: _profile(),
          rowId: route,
          routeName: route,
        );
      });
    }

    testWidgets('Moderation queue (Staff)', (WidgetTester tester) async {
      await expectTapOpens(
        tester,
        user: _staff,
        rowId: RouteNames.moderation,
        routeName: RouteNames.moderation,
      );
    });

    testWidgets('a pushed screen returns to the hub with back', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _customer);
      await tester.tap(_row(RouteNames.notificationPreferences));
      await tester.pumpAndSettle();
      expect(find.text('stub:${RouteNames.notificationPreferences}'), findsOneWidget);

      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('Profile & Settings'), findsOneWidget);
    });

    testWidgets('About opens the about dialog', (WidgetTester tester) async {
      await _pump(tester, user: _customer);
      await tester.tap(_row(ProfileHubScreen.aboutId));
      await tester.pumpAndSettle();

      expect(find.byType(AboutDialog), findsOneWidget);
    });
  });

  group('P-113 STEP 3A: log out', () {
    testWidgets('asks for confirmation and does not sign out yet', (
      WidgetTester tester,
    ) async {
      final _FakeSession session = await _pump(tester, user: _customer);

      await tester.tap(_row(kNavLogoutId));
      await tester.pumpAndSettle();

      expect(find.byKey(ProfileHubScreen.logoutDialogKey), findsOneWidget);
      expect(find.text('Log out?'), findsOneWidget);
      expect(session.logoutCalls, 0);
    });

    testWidgets('Cancel closes the dialog and keeps the session', (
      WidgetTester tester,
    ) async {
      final _FakeSession session = await _pump(tester, user: _customer);

      await tester.tap(_row(kNavLogoutId));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProfileHubScreen.logoutCancelKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ProfileHubScreen.logoutDialogKey), findsNothing);
      expect(session.logoutCalls, 0);
      expect(find.text('Profile & Settings'), findsOneWidget);
    });

    testWidgets('Confirm signs out exactly once', (WidgetTester tester) async {
      final _FakeSession session = await _pump(tester, user: _customer);

      await tester.tap(_row(kNavLogoutId));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProfileHubScreen.logoutConfirmKey));
      await tester.pumpAndSettle();

      expect(session.logoutCalls, 1);
      expect(find.byKey(ProfileHubScreen.logoutDialogKey), findsNothing);
    });
  });

  group('P-113 STEP 3A: Arabic', () {
    testWidgets('texts are Arabic and the layout is right-to-left', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _customer, locale: const Locale('ar'));

      expect(find.text(_arTitle), findsOneWidget);
      expect(find.text(_arLogOut), findsOneWidget);
      expect(find.text('Profile & Settings'), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(ProfileHubScreen))),
        TextDirection.rtl,
      );
    });
  });
}
