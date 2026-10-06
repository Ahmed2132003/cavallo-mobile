import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/business_shortcuts.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/profile_hub_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-113 (STEP 4B): the Business shortcuts under the hub header.
///
/// * each of the four buttons opens its screen, and back returns to the hub;
/// * the hub draws the shortcuts for a Business account only;
/// * they work (and mirror) in Arabic.

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

BusinessProfile _profile() {
  return BusinessProfile(
    id: 1,
    businessName: 'Roots Atelier',
    businessType: BusinessType.trader,
    country: 'EG',
    city: 'Cairo',
    isVerified: false,
    isFeatured: false,
  );
}

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

Future<void> _pumpHub(
  WidgetTester tester, {
  required User user,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final GoRouter router = _stubRouter();
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _FakeSession(user)),
        hubBusinessProfileProvider.overrideWithValue(
          user.accountType == AccountType.business ? _profile() : null,
        ),
        hubModerationPendingCountProvider.overrideWithValue(0),
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
}

void main() {
  group('P-113 STEP 4B: Business shortcuts in the hub', () {
    testWidgets('Business: four shortcuts, in order, with their tooltips', (
      WidgetTester tester,
    ) async {
      await _pumpHub(tester, user: _business);

      for (final String routeName in BusinessShortcuts.routeNames) {
        expect(
          find.byKey(BusinessShortcuts.shortcutKey(routeName)),
          findsOneWidget,
          reason: routeName,
        );
      }
      expect(find.byTooltip('Products'), findsOneWidget);
      expect(find.byTooltip('Content'), findsOneWidget);
      expect(find.byTooltip('Stories'), findsOneWidget);
      expect(find.byTooltip('Analytics'), findsOneWidget);
    });

    for (final String routeName in BusinessShortcuts.routeNames) {
      testWidgets('Business: the $routeName shortcut opens it, back returns', (
        WidgetTester tester,
      ) async {
        await _pumpHub(tester, user: _business);

        await tester.tap(find.byKey(BusinessShortcuts.shortcutKey(routeName)));
        await tester.pumpAndSettle();
        expect(find.text('stub:$routeName'), findsOneWidget);

        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        expect(find.byType(ProfileHubScreen), findsOneWidget);
      });
    }

    testWidgets('Customer: no shortcuts', (WidgetTester tester) async {
      await _pumpHub(tester, user: _customer);
      for (final String routeName in BusinessShortcuts.routeNames) {
        expect(
          find.byKey(BusinessShortcuts.shortcutKey(routeName)),
          findsNothing,
          reason: routeName,
        );
      }
    });

    testWidgets('Staff: no shortcuts', (WidgetTester tester) async {
      await _pumpHub(tester, user: _staff);
      for (final String routeName in BusinessShortcuts.routeNames) {
        expect(
          find.byKey(BusinessShortcuts.shortcutKey(routeName)),
          findsNothing,
          reason: routeName,
        );
      }
    });

    testWidgets('Arabic: the shortcuts are drawn and the page is right-to-left', (
      WidgetTester tester,
    ) async {
      await _pumpHub(tester, user: _business, locale: const Locale('ar'));

      for (final String routeName in BusinessShortcuts.routeNames) {
        expect(
          find.byKey(BusinessShortcuts.shortcutKey(routeName)),
          findsOneWidget,
          reason: routeName,
        );
      }
      expect(
        Directionality.of(tester.element(find.byType(BusinessShortcuts))),
        TextDirection.rtl,
      );
    });
  });
}
