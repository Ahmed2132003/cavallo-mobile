import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/shell/app_bottom_bar.dart';
import 'package:social_commerce_app/core/shell/shell_branches.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/navigation_manifest.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-113 (STEP 2A): widget tests of [AppBottomBar] and [ShellBranch].
///
/// The bar is built from the navigation manifest, so these tests also keep the
/// manifest, the branch order and the bar's icon/label table in sync.

const String _arHome = '\u0627\u0644\u0631\u0626\u064a\u0633\u064a\u0629';

Widget _host({
  required NavAudience audience,
  int currentBranch = ShellBranch.home,
  ValueChanged<int>? onSelectBranch,
  VoidCallback? onCreate,
  Map<String, int> badgeCounts = const <String, int>{},
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme ?? AppTheme.light,
    home: Scaffold(
      body: const SizedBox.shrink(),
      bottomNavigationBar: AppBottomBar(
        audience: audience,
        currentBranch: currentBranch,
        onSelectBranch: onSelectBranch ?? (int _) {},
        onCreate: onCreate,
        badgeCounts: badgeCounts,
      ),
    ),
  );
}

List<Key?> _tabKeys(WidgetTester tester) {
  return tester
      .widgetList<NavigationDestination>(find.byType(NavigationDestination))
      .map((NavigationDestination d) => d.key)
      .toList();
}

void main() {
  group('P-113 STEP 2A: ShellBranch', () {
    test('branch indexes are 0..5 with no gaps and no duplicates', () {
      final List<int> all = <int>[
        ShellBranch.home,
        ShellBranch.discover,
        ShellBranch.saved,
        ShellBranch.moderation,
        ShellBranch.chats,
        ShellBranch.profile,
      ];
      expect(all, <int>[0, 1, 2, 3, 4, 5]);
      expect(ShellBranch.count, all.length);
      expect(ShellBranch.byRouteName.values.toSet().length, ShellBranch.count);
    });

    test('forRouteName maps tab routes and ignores everything else', () {
      expect(ShellBranch.forRouteName(RouteNames.home), ShellBranch.home);
      expect(ShellBranch.forRouteName(RouteNames.chatList), ShellBranch.chats);
      expect(ShellBranch.forRouteName(RouteNames.search), isNull);
      expect(ShellBranch.forRouteName(kNavCreateId), isNull);
      expect(ShellBranch.forRouteName(null), isNull);
    });

    test(
      'every bottom tab of every audience is a branch, or the create action',
      () {
        for (final NavAudience audience in NavAudience.values) {
          final tabs = bottomTabsFor(audience);
          expect(tabs, hasLength(5), reason: '$audience must have 5 tabs');
          for (final tab in tabs) {
            final bool isCreate = tab.key.id == kNavCreateId;
            final int? branch = ShellBranch.forRouteName(tab.key.routeName);
            expect(
              isCreate ? branch == null : branch != null,
              isTrue,
              reason: '$audience tab "${tab.key.id}" has no shell branch',
            );
            expect(
              appBottomBarKnownIds.contains(tab.key.id),
              isTrue,
              reason: 'AppBottomBar has no icon/label for "${tab.key.id}"',
            );
          }
        }
      },
    );
  });

  group('P-113 STEP 2A: AppBottomBar tabs per account type', () {
    testWidgets('Customer: Home, Explore, Saved, Chats, Profile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(audience: NavAudience.customer));

      expect(_tabKeys(tester), <Key>[
        AppBottomBar.tabKey(RouteNames.home),
        AppBottomBar.tabKey(RouteNames.discover),
        AppBottomBar.tabKey(RouteNames.saved),
        AppBottomBar.tabKey(RouteNames.chatList),
        AppBottomBar.tabKey(RouteNames.profile),
      ]);
      for (final String label in <String>[
        'Home',
        'Explore',
        'Saved',
        'Chats',
        'Profile',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Create'), findsNothing);
      expect(find.text('Moderation'), findsNothing);
    });

    testWidgets('Business: Home, Explore, Create (+), Chats, Profile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(audience: NavAudience.business));

      expect(_tabKeys(tester), <Key>[
        AppBottomBar.tabKey(RouteNames.home),
        AppBottomBar.tabKey(RouteNames.discover),
        AppBottomBar.tabKey(kNavCreateId),
        AppBottomBar.tabKey(RouteNames.chatList),
        AppBottomBar.tabKey(RouteNames.profile),
      ]);
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      expect(find.text('Moderation'), findsNothing);
    });

    testWidgets('Staff: Home, Explore, Moderation, Chats, Profile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(audience: NavAudience.staff));

      expect(_tabKeys(tester), <Key>[
        AppBottomBar.tabKey(RouteNames.home),
        AppBottomBar.tabKey(RouteNames.discover),
        AppBottomBar.tabKey(RouteNames.moderation),
        AppBottomBar.tabKey(RouteNames.chatList),
        AppBottomBar.tabKey(RouteNames.profile),
      ]);
      expect(find.text('Moderation'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      expect(find.text('Create'), findsNothing);
    });
  });

  group('P-113 STEP 2A: AppBottomBar behaviour', () {
    testWidgets('the selected tab follows the current branch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(audience: NavAudience.customer, currentBranch: ShellBranch.chats),
      );
      NavigationBar bar = tester.widget<NavigationBar>(
        find.byKey(AppBottomBar.barKey),
      );
      expect(bar.selectedIndex, 3);

      await tester.pumpWidget(
        _host(audience: NavAudience.staff, currentBranch: ShellBranch.moderation),
      );
      bar = tester.widget<NavigationBar>(find.byKey(AppBottomBar.barKey));
      expect(bar.selectedIndex, 2);
    });

    testWidgets('a branch the audience does not show falls back to Home', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          audience: NavAudience.customer,
          currentBranch: ShellBranch.moderation,
        ),
      );
      final NavigationBar bar = tester.widget<NavigationBar>(
        find.byKey(AppBottomBar.barKey),
      );
      expect(bar.selectedIndex, 0);
    });

    testWidgets('tapping a branch tab reports its branch index', (
      WidgetTester tester,
    ) async {
      final List<int> selected = <int>[];
      await tester.pumpWidget(
        _host(audience: NavAudience.customer, onSelectBranch: selected.add),
      );

      await tester.tap(find.byKey(AppBottomBar.tabKey(RouteNames.chatList)));
      await tester.pump();
      await tester.tap(find.byKey(AppBottomBar.tabKey(RouteNames.saved)));
      await tester.pump();

      expect(selected, <int>[ShellBranch.chats, ShellBranch.saved]);
    });

    testWidgets('the Business + calls onCreate and never selects a branch', (
      WidgetTester tester,
    ) async {
      final List<int> selected = <int>[];
      int created = 0;
      await tester.pumpWidget(
        _host(
          audience: NavAudience.business,
          onSelectBranch: selected.add,
          onCreate: () => created++,
        ),
      );

      await tester.tap(find.byKey(AppBottomBar.tabKey(kNavCreateId)));
      await tester.pump();

      expect(created, 1);
      expect(selected, isEmpty);
      final NavigationBar bar = tester.widget<NavigationBar>(
        find.byKey(AppBottomBar.barKey),
      );
      expect(bar.selectedIndex, 0, reason: '+ is an action, never selected');
    });

    testWidgets('the Business + with no onCreate wired does not crash', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(audience: NavAudience.business));
      await tester.tap(find.byKey(AppBottomBar.tabKey(kNavCreateId)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a badge count above zero shows on that tab only', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          audience: NavAudience.staff,
          badgeCounts: <String, int>{RouteNames.moderation: 3},
        ),
      );
      expect(find.byType(Badge), findsWidgets);
      expect(find.text('3'), findsWidgets);

      await tester.pumpWidget(
        _host(
          audience: NavAudience.staff,
          badgeCounts: <String, int>{RouteNames.moderation: 0},
        ),
      );
      expect(find.byType(Badge), findsNothing);
    });
  });

  group('P-113 STEP 2A: AppBottomBar theming and language', () {
    testWidgets('builds in the dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(audience: NavAudience.customer, theme: AppTheme.dark),
      );
      expect(find.byKey(AppBottomBar.barKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Arabic: translated labels and a mirrored (RTL) bar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(audience: NavAudience.customer, locale: const Locale('ar')),
      );

      expect(find.text(_arHome), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(
        Directionality.of(tester.element(find.byKey(AppBottomBar.barKey))),
        TextDirection.rtl,
      );
      final double homeX =
          tester.getCenter(find.byKey(AppBottomBar.tabKey(RouteNames.home))).dx;
      final double profileX =
          tester
              .getCenter(find.byKey(AppBottomBar.tabKey(RouteNames.profile)))
              .dx;
      expect(homeX, greaterThan(profileX), reason: 'Home is on the right in RTL');
    });
  });
}