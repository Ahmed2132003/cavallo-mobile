import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_error_screen.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-112 STEP 6: the unknown-address page, in both languages.
///
/// ASCII only on purpose: Arabic text is a \uXXXX escape.
Widget _app(Locale locale, GoRouter router) {
  return MaterialApp.router(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/does-not-exist',
    errorBuilder: (BuildContext context, GoRouterState state) =>
        const RouteErrorScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: RouteNames.homePath,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('HOME_PLACEHOLDER')),
      ),
    ],
  );
}

void main() {
  testWidgets('English: texts, left-to-right, and the button goes home', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const Locale('en'), _router()));
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
    expect(find.text('The page you are looking for does not exist or has moved.'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(RouteErrorScreen))),
      TextDirection.ltr,
    );

    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();
    expect(find.text('HOME_PLACEHOLDER'), findsOneWidget);
  });

  testWidgets('Arabic: texts and right-to-left', (tester) async {
    await tester.pumpWidget(_app(const Locale('ar'), _router()));
    await tester.pumpAndSettle();

    expect(find.text('\u0627\u0644\u0635\u0641\u062d\u0629 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f\u0629'), findsOneWidget);
    expect(find.text('\u0627\u0644\u0635\u0641\u062d\u0629 \u0627\u0644\u062a\u064a \u062a\u0628\u062d\u062b \u0639\u0646\u0647\u0627 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f\u0629 \u0623\u0648 \u062a\u0645 \u0646\u0642\u0644\u0647\u0627.'), findsOneWidget);
    expect(find.text('\u0627\u0644\u0639\u0648\u062f\u0629 \u0625\u0644\u0649 \u0627\u0644\u0631\u0626\u064a\u0633\u064a\u0629'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(RouteErrorScreen))),
      TextDirection.rtl,
    );
  });
}
