import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:social_commerce_app/core/shell/app_bottom_bar.dart';
import 'package:social_commerce_app/core/shell/app_shell.dart';
import 'package:social_commerce_app/core/shell/shell_branches.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/navigation_manifest.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-113 (STEP 2B): navigation tests of the app shell.
///
/// Two kinds of test:
///  * a small stub [GoRouter] that uses the REAL [AppShell] and
///    [AppBottomBar], to prove tab switching, per-tab back stacks, the
///    "tap the selected tab = back to its root" rule and the system back
///    button rule (non-Home tab root -> Home tab);
///  * the REAL [appRouterProvider], to prove the shell is declared with its
///    branches in [ShellBranch] order and that no tab route is left outside it.

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

GoRouter _stubRouter() {
  Widget screen(String label) => Scaffold(body: Center(child: Text(label)));

  GoRoute root(String name, String path, {List<RouteBase>? children}) {
    return GoRoute(
      path: path,
      name: name,
      builder: (BuildContext context, GoRouterState state) =>
          screen('$name root'),
      routes: children ?? const <RouteBase>[],
    );
  }

  // Same order as ShellBranch: home, discover, saved, moderation, chats,
  // profile.
  final List<StatefulShellBranch> branches = <StatefulShellBranch>[
    StatefulShellBranch(
      routes: <RouteBase>[
        root(
          RouteNames.home,
          RouteNames.homePath,
          children: <RouteBase>[
            GoRoute(
              path: 'detail',
              name: 'homeDetail',
              builder: (BuildContext context, GoRouterState state) =>
                  screen('home detail'),
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[root(RouteNames.discover, RouteNames.discoverPath)],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[root(RouteNames.saved, RouteNames.savedPath)],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[
        root(RouteNames.moderation, RouteNames.moderationPath),
      ],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[root(RouteNames.chatList, RouteNames.chatListPath)],
    ),
    StatefulShellBranch(
      routes: <RouteBase>[root(RouteNames.profile, RouteNames.profilePath)],
    ),
  ];

  return GoRouter(
    initialLocation: RouteNames.homePath,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell shell,
        ) => AppShell(navigationShell: shell),
        branches: branches,
      ),
    ],
  );
}

Future<GoRouter> _pump(WidgetTester tester, User user) async {
  final GoRouter router = _stubRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(() => _FakeSession(user))],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapTab(WidgetTester tester, String destinationId) async {
  await tester.tap(find.byKey(AppBottomBar.tabKey(destinationId)));
  await tester.pumpAndSettle();
}

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('P-113 STEP 2B: shell tabs (stub router, real AppShell)', () {
    testWidgets('Customer starts on Home and shows the five-tab bar', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _customer);

      expect(find.text('home root'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('tapping a tab shows that tab and hides the previous one', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _customer);

      await _tapTab(tester, RouteNames.chatList);
      expect(find.text('chatList root'), findsOneWidget);
      expect(find.text('home root'), findsNothing);

      await _tapTab(tester, RouteNames.saved);
      expect(find.text('saved root'), findsOneWidget);
      expect(find.text('chatList root'), findsNothing);

      await _tapTab(tester, RouteNames.profile);
      expect(find.text('profile root'), findsOneWidget);
    });

    testWidgets('each tab keeps its own back stack when you switch away', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pump(tester, _customer);

      router.go('${RouteNames.homePath}/detail');
      await tester.pumpAndSettle();
      expect(find.text('home detail'), findsOneWidget);

      await _tapTab(tester, RouteNames.chatList);
      expect(find.text('chatList root'), findsOneWidget);

      await _tapTab(tester, RouteNames.home);
      expect(
        find.text('home detail'),
        findsOneWidget,
        reason: 'the Home tab must come back where it was left',
      );
    });

    testWidgets('tapping the selected tab again goes back to its root', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pump(tester, _customer);

      router.go('${RouteNames.homePath}/detail');
      await tester.pumpAndSettle();
      expect(find.text('home detail'), findsOneWidget);

      await _tapTab(tester, RouteNames.home);
      expect(find.text('home root'), findsOneWidget);
      expect(find.text('home detail'), findsNothing);
    });

    testWidgets('Business: bar has Create and no Saved; + changes no tab', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _business);

      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);

      await _tapTab(tester, kNavCreateId);
      expect(
        find.text('home root'),
        findsOneWidget,
        reason: 'the + is an action; it must not switch the tab',
      );
    });

    testWidgets('Staff: bar has Moderation, and it opens the moderation tab', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _staff);

      expect(find.text('Moderation'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);

      await _tapTab(tester, RouteNames.moderation);
      expect(find.text('moderation root'), findsOneWidget);
    });
  });

  group('P-113 STEP 2B: system back button', () {
    testWidgets('on a non-Home tab root, back returns to the Home tab', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _customer);

      await _tapTab(tester, RouteNames.chatList);
      expect(find.text('chatList root'), findsOneWidget);

      await _systemBack(tester);

      expect(find.text('home root'), findsOneWidget);
      expect(find.text('chatList root'), findsNothing);
    });

    testWidgets('from Profile, back also returns to the Home tab', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _customer);

      await _tapTab(tester, RouteNames.profile);
      await _systemBack(tester);

      expect(find.text('home root'), findsOneWidget);
    });

    testWidgets('a screen pushed inside a tab is popped before tabs switch', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pump(tester, _customer);

      router.go('${RouteNames.homePath}/detail');
      await tester.pumpAndSettle();
      expect(find.text('home detail'), findsOneWidget);

      await _systemBack(tester);

      expect(find.text('home root'), findsOneWidget);
      expect(find.text('home detail'), findsNothing);
    });
  });

  group('P-113 STEP 2B: the real router declares the app shell', () {
    test('branches are in ShellBranch order and tab routes are not top-level', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [sessionProvider.overrideWith(() => _FakeSession(_customer))],
      );
      addTearDown(container.dispose);

      final GoRouter router = container.read(appRouterProvider);
      final List<RouteBase> topLevel = router.configuration.routes;

      final List<StatefulShellRoute> appShells =
          topLevel
              .whereType<StatefulShellRoute>()
              .where(
                (StatefulShellRoute s) => s.branches.length == ShellBranch.count,
              )
              .toList();
      expect(appShells, hasLength(1), reason: 'exactly one app shell');

      final List<StatefulShellBranch> branches = appShells.single.branches;
      for (int i = 0; i < branches.length; i++) {
        final RouteBase first = branches[i].routes.single;
        expect(first, isA<GoRoute>());
        expect(
          ShellBranch.byRouteName[(first as GoRoute).name],
          i,
          reason: 'branch $i is "${first.name}" but ShellBranch says otherwise',
        );
      }

      final Set<String?> topLevelNames =
          topLevel.whereType<GoRoute>().map((GoRoute r) => r.name).toSet();
      for (final String tabRoute in ShellBranch.byRouteName.keys) {
        expect(
          topLevelNames.contains(tabRoute),
          isFalse,
          reason: '"$tabRoute" must live inside the shell, not at top level',
        );
      }
    });
  });
}