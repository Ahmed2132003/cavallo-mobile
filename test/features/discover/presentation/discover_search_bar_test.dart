import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/features/discover/presentation/discover_search_bar.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-113 (STEP 6A): the Explore tab's search entry point.

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder:
            (BuildContext context, GoRouterState state) =>
                Scaffold(appBar: AppBar(title: const DiscoverSearchBar())),
      ),
      GoRoute(
        path: '/search',
        name: RouteNames.search,
        builder:
            (BuildContext context, GoRouterState state) =>
                Scaffold(appBar: AppBar(), body: const Text('stub:search')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the English hint', (tester) async {
    await _pump(tester);

    expect(find.byKey(DiscoverSearchBar.barKey), findsOneWidget);
    expect(find.text('Search businesses, products and posts'), findsOneWidget);
  });

  testWidgets('shows the Arabic hint', (tester) async {
    await _pump(tester, locale: const Locale('ar'));

    expect(
      find.text(lookupAppLocalizations(const Locale('ar')).discoverSearchHint),
      findsOneWidget,
    );
  });

  testWidgets('tapping the bar opens the search screen', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(DiscoverSearchBar.barKey));
    await tester.pumpAndSettle();

    expect(find.text('stub:search'), findsOneWidget);
  });
}
