import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part BI-04: the two analytics detail routes.
///
/// Checks the `RouteNames` constants and that a go_router table shaped like
/// the one documented in `route_names.dart` (children of
/// `businessAnalyticsPath`) resolves them with the right path parameters.
/// The Business-only gate is a prefix check on `/business-console`, so both
/// paths must live under it.
String _childOf(String parent, String full) => full.substring(parent.length + 1);

void main() {
  group('RouteNames constants', () {
    test('paths', () {
      expect(RouteNames.businessAnalyticsPath, '/business-console/analytics');
      expect(
        RouteNames.businessAnalyticsProductPath,
        '/business-console/analytics/product/:id',
      );
      expect(
        RouteNames.businessAnalyticsContentPath,
        '/business-console/analytics/content/:type/:id',
      );
    });

    test('both detail paths are under the Business-only prefix', () {
      expect(
        RouteNames.businessAnalyticsProductPath,
        startsWith('${RouteNames.businessConsolePath}/'),
      );
      expect(
        RouteNames.businessAnalyticsContentPath,
        startsWith('${RouteNames.businessConsolePath}/'),
      );
    });

    test('they are children of the analytics tab path', () {
      expect(
        _childOf(
          RouteNames.businessAnalyticsPath,
          RouteNames.businessAnalyticsProductPath,
        ),
        'product/:id',
      );
      expect(
        _childOf(
          RouteNames.businessAnalyticsPath,
          RouteNames.businessAnalyticsContentPath,
        ),
        'content/:type/:id',
      );
    });

    test('names and path parameter keys', () {
      expect(RouteNames.businessAnalyticsProduct, 'businessAnalyticsProduct');
      expect(RouteNames.businessAnalyticsContent, 'businessAnalyticsContent');
      expect(RouteNames.analyticsContentTypeParam, 'type');
      expect(RouteNames.idParam, 'id');
      expect(
        <String>{
          RouteNames.businessAnalytics,
          RouteNames.businessAnalyticsProduct,
          RouteNames.businessAnalyticsContent,
          RouteNames.ordersList,
          RouteNames.orderDetail,
        },
        hasLength(5),
      );
    });
  });

  group('go_router resolution', () {
    final List<String> seen = <String>[];

    GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext c, GoRouterState s) => const SizedBox(),
        ),
        GoRoute(
          path: RouteNames.businessAnalyticsPath,
          name: RouteNames.businessAnalytics,
          builder: (BuildContext c, GoRouterState s) {
            seen.add('dashboard');
            return const SizedBox();
          },
          routes: <RouteBase>[
            GoRoute(
              path: _childOf(
                RouteNames.businessAnalyticsPath,
                RouteNames.businessAnalyticsProductPath,
              ),
              name: RouteNames.businessAnalyticsProduct,
              builder: (BuildContext c, GoRouterState s) {
                seen.add('product:${s.pathParameters[RouteNames.idParam]}');
                return const SizedBox();
              },
            ),
            GoRoute(
              path: _childOf(
                RouteNames.businessAnalyticsPath,
                RouteNames.businessAnalyticsContentPath,
              ),
              name: RouteNames.businessAnalyticsContent,
              builder: (BuildContext c, GoRouterState s) {
                seen.add(
                  'content:'
                  '${s.pathParameters[RouteNames.analyticsContentTypeParam]}:'
                  '${s.pathParameters[RouteNames.idParam]}',
                );
                return const SizedBox();
              },
            ),
          ],
        ),
      ],
    );

    setUp(() => seen.clear());

    test('named locations build the full paths', () {
      final GoRouter router = buildRouter();

      expect(
        router.namedLocation(
          RouteNames.businessAnalyticsProduct,
          pathParameters: <String, String>{RouteNames.idParam: '7'},
        ),
        '/business-console/analytics/product/7',
      );
      expect(
        router.namedLocation(
          RouteNames.businessAnalyticsContent,
          pathParameters: <String, String>{
            RouteNames.analyticsContentTypeParam: 'reel',
            RouteNames.idParam: '9',
          },
        ),
        '/business-console/analytics/content/reel/9',
      );
    });

    testWidgets('a product location resolves with its id', (
      WidgetTester tester,
    ) async {
      final GoRouter router = buildRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      router.go('/business-console/analytics/product/7');
      await tester.pumpAndSettle();

      // The parent (dashboard) page is built under the child page, so the
      // probe records every builder call instead of only the last one.
      expect(seen, contains('product:7'));
    });

    testWidgets('a content location resolves with its type and id', (
      WidgetTester tester,
    ) async {
      final GoRouter router = buildRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      router.go('/business-console/analytics/content/reel/9');
      await tester.pumpAndSettle();

      expect(seen, contains('content:reel:9'));
    });

    testWidgets('the analytics tab path still resolves on its own', (
      WidgetTester tester,
    ) async {
      final GoRouter router = buildRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      router.go(RouteNames.businessAnalyticsPath);
      await tester.pumpAndSettle();

      expect(seen.toSet(), <String>{'dashboard'});
    });
  });
}