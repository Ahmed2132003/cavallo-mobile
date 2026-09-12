import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/route_names.dart';

void main() {
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    container = ProviderContainer();
    router = container.read(appRouterProvider);
  });

  tearDown(() => container.dispose());

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('splash route resolves at the initial location', (
    tester,
  ) async {
    await pumpRouter(tester);
    expect(find.text('Route: splash'), findsOneWidget);
  });

  testWidgets('every non-parameterized named route resolves', (tester) async {
    await pumpRouter(tester);

    const simpleRoutes = <String>[
      RouteNames.login,
      RouteNames.register,
      RouteNames.home,
      RouteNames.discover,
      RouteNames.search,
      RouteNames.chatList,
      RouteNames.notifications,
      RouteNames.businessConsole,
    ];

    for (final name in simpleRoutes) {
      router.goNamed(name);
      await tester.pumpAndSettle();
      expect(
        find.text('Route: $name'),
        findsOneWidget,
        reason: 'route "$name" did not resolve',
      );
    }
  });

  testWidgets('businessProfile route resolves with its :id path parameter', (
    tester,
  ) async {
    await pumpRouter(tester);

    router.goNamed(
      RouteNames.businessProfile,
      pathParameters: {RouteNames.idParam: 'sample-business-1'},
    );
    await tester.pumpAndSettle();

    expect(find.text('Route: businessProfile'), findsOneWidget);
    expect(find.text('id param: sample-business-1'), findsOneWidget);
  });

  testWidgets('productDetail route resolves with its :id path parameter', (
    tester,
  ) async {
    await pumpRouter(tester);

    router.goNamed(
      RouteNames.productDetail,
      pathParameters: {RouteNames.idParam: 'sample-product-1'},
    );
    await tester.pumpAndSettle();

    expect(find.text('Route: productDetail'), findsOneWidget);
    expect(find.text('id param: sample-product-1'), findsOneWidget);
  });

  testWidgets('chatThread route resolves with its :id path parameter', (
    tester,
  ) async {
    await pumpRouter(tester);

    router.goNamed(
      RouteNames.chatThread,
      pathParameters: {RouteNames.idParam: 'sample-thread-1'},
    );
    await tester.pumpAndSettle();

    expect(find.text('Route: chatThread'), findsOneWidget);
    expect(find.text('id param: sample-thread-1'), findsOneWidget);
  });

  testWidgets(
    'tapping the debug button on every placeholder screen forms a closed '
    'cycle through all 12 routes back to splash',
    (tester) async {
      await pumpRouter(tester);

      // splash -> login -> register -> home -> discover -> search ->
      // businessProfile -> productDetail -> chatList -> chatThread ->
      // notifications -> businessConsole -> splash (12 taps, 12 routes).
      for (var i = 0; i < 12; i++) {
        final button = find.byType(FilledButton);
        expect(button, findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      expect(find.text('Route: splash'), findsOneWidget);
    },
  );
}
