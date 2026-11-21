import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_dashboard_screen.dart';
import 'package:social_commerce_app/features/business_console/presentation/content_analytics_detail_screen.dart';
import 'package:social_commerce_app/features/business_console/presentation/product_analytics_detail_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

import '../fake_business_analytics_repository.dart';
import 'bi_test_harness.dart';

/// Part BI-04: navigation between the dashboard and the two detail screens.
///
/// The router table mirrors the one documented in `route_names.dart`: the two
/// detail routes are CHILDREN of `businessAnalyticsPath`
/// (`product/:id` and `content/:type/:id`). The real screens are built by
/// them; the orders list is a stub (its own tests live in BI-03).
const ValueKey<String> _ordersStubKey = ValueKey<String>('orders-stub');

GoRouter _router() => GoRouter(
  initialLocation: RouteNames.businessAnalyticsPath,
  routes: <RouteBase>[
    GoRoute(
      path: RouteNames.businessAnalyticsPath,
      name: RouteNames.businessAnalytics,
      builder:
          (BuildContext context, GoRouterState state) =>
              const AnalyticsDashboardScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'product/:id',
          name: RouteNames.businessAnalyticsProduct,
          builder:
              (BuildContext context, GoRouterState state) =>
                  ProductAnalyticsDetailScreen(
                    productId: int.parse(
                      state.pathParameters[RouteNames.idParam]!,
                    ),
                  ),
        ),
        GoRoute(
          path: 'content/:type/:id',
          name: RouteNames.businessAnalyticsContent,
          builder:
              (BuildContext context, GoRouterState state) =>
                  ContentAnalyticsDetailScreen(
                    contentType:
                        state.pathParameters[RouteNames.analyticsContentTypeParam]!,
                    contentId: int.parse(
                      state.pathParameters[RouteNames.idParam]!,
                    ),
                  ),
        ),
      ],
    ),
    GoRoute(
      path: RouteNames.ordersListPath,
      name: RouteNames.ordersList,
      builder:
          (BuildContext context, GoRouterState state) => const Scaffold(
            key: _ordersStubKey,
            body: Text('orders stub'),
          ),
    ),
  ],
);

void main() {
  testWidgets('a product row opens that product\'s analytics', (
    WidgetTester tester,
  ) async {
    final FakeBusinessAnalyticsRepository repo = biFullRepository();
    await pumpBi(tester, repository: repo, router: _router());
    await openBiTab(tester, 'products');

    await tester.tap(find.text('Leather belt'));
    await tester.pumpAndSettle();

    expect(find.byType(ProductAnalyticsDetailScreen), findsOneWidget);
    expect(repo.productDetailCalls.single.productId, 1);
    expect(repo.productDetailCalls.single.businessId, 42);
  });

  testWidgets('a content card opens that post\'s analytics', (
    WidgetTester tester,
  ) async {
    final FakeBusinessAnalyticsRepository repo = biFullRepository();
    await pumpBi(tester, repository: repo, router: _router());
    await openBiTab(tester, 'content');

    await tester.tap(find.text('Summer sale'));
    await tester.pumpAndSettle();

    expect(find.byType(ContentAnalyticsDetailScreen), findsOneWidget);
    expect(repo.contentDetailCalls.single.contentType, 'post');
    expect(repo.contentDetailCalls.single.contentId, 5);
  });

  testWidgets('"Open orders" goes to the orders list', (
    WidgetTester tester,
  ) async {
    final AppLocalizations l10n = await biL10n('en');
    final FakeBusinessAnalyticsRepository repo = biFullRepository();
    await pumpBi(tester, repository: repo, router: _router());
    await openBiTab(tester, 'products');
    await tester.tap(find.text('Leather belt'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(l10n.analyticsProdOpenOrders));
    await tester.tap(find.text(l10n.analyticsProdOpenOrders));
    await tester.pumpAndSettle();

    expect(find.byKey(_ordersStubKey), findsOneWidget);
  });

  testWidgets('going back to the dashboard does not reload it', (
    WidgetTester tester,
  ) async {
    final FakeBusinessAnalyticsRepository repo = biFullRepository();
    await pumpBi(tester, repository: repo, router: _router());
    await openBiTab(tester, 'products');
    final List<String> before = List<String>.of(repo.calls);

    await tester.tap(find.text('Leather belt'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(AnalyticsDashboardScreen), findsOneWidget);
    // Only the detail request was added; overview / products were not
    // requested again.
    final List<String> added = repo.calls.sublist(before.length);
    expect(added, <String>['productDetail']);
  });
}