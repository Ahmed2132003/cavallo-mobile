import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/shell/create_sheet.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-113 (STEP 4A): the Business create sheet.

const List<String> _forms = <String>[
  RouteNames.postForm,
  RouteNames.reelForm,
  RouteNames.storyForm,
  RouteNames.productForm,
];

const String _arTitle = '\u0625\u0646\u0634\u0627\u0621 \u062c\u062f\u064a\u062f';

GoRouter _router() {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder:
            (BuildContext context, GoRouterState state) => Scaffold(
              body: Builder(
                builder:
                    (BuildContext inner) => TextButton(
                      key: const Key('open-sheet'),
                      onPressed: () => showCreateSheet(inner),
                      child: const Text('open'),
                    ),
              ),
            ),
      ),
      for (final String name in _forms)
        GoRoute(
          path: '/$name',
          name: name,
          builder:
              (BuildContext context, GoRouterState state) =>
                  Scaffold(appBar: AppBar(), body: Text('stub:$name')),
        ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final GoRouter router = _router();
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
  await tester.tap(find.byKey(const Key('open-sheet')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sheet offers Post, Reel, Story and Product', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    expect(find.text('Create new'), findsOneWidget);
    for (final String name in _forms) {
      expect(find.byKey(CreateSheet.optionKey(name)), findsOneWidget, reason: name);
    }
    expect(find.text('Post'), findsOneWidget);
    expect(find.text('Reel'), findsOneWidget);
    expect(find.text('Story'), findsOneWidget);
    expect(find.text('Product'), findsOneWidget);
  });

  for (final String name in _forms) {
    testWidgets('choosing $name opens that form route', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(CreateSheet.optionKey(name)));
      await tester.pumpAndSettle();

      expect(find.text('stub:$name'), findsOneWidget);
      expect(find.byKey(CreateSheet.titleKey), findsNothing);
    });
  }

  testWidgets('dismissing the sheet opens nothing', (WidgetTester tester) async {
    await _pump(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byKey(CreateSheet.titleKey), findsNothing);
    expect(find.textContaining('stub:'), findsNothing);
  });

  testWidgets('works in Arabic', (WidgetTester tester) async {
    await _pump(tester, locale: const Locale('ar'));

    expect(find.text(_arTitle), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byKey(CreateSheet.titleKey))),
      TextDirection.rtl,
    );
  });
}
