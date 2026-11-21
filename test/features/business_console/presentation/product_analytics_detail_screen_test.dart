import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/business_console/presentation/product_analytics_detail_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import '../bi_fixtures.dart';
import '../fake_business_analytics_repository.dart';
import 'bi_test_harness.dart';

/// Part BI-04: analytics of ONE product. Totals, sales per currency (never
/// summed), the funnel exactly as the backend returned it, and the orders link.
const String _dash = '—';

Map<String, dynamic> _totals({
  int? views = 100,
  int? uniqueViews = 80,
  int? saves = 5,
  double? conversion = 0.0375,
  List<Map<String, dynamic>>? sales,
}) => <String, dynamic>{
  'views': views,
  'unique_views': uniqueViews,
  'saves': saves,
  'interests': 10,
  'orders': 4,
  'sold_orders': 3,
  'units': 6,
  'sales': sales ?? <Map<String, dynamic>>[biSalesJson()],
  'conversion': conversion,
};

void main() {
  const Widget screen = ProductAnalyticsDetailScreen(productId: 1);

  group('loaded', () {
    testWidgets('requests the product of the signed-in business', (
      WidgetTester tester,
    ) async {
      final FakeBusinessAnalyticsRepository repo = biFullRepository();

      await pumpBi(tester, repository: repo, home: screen);

      expect(repo.productDetailCalls, hasLength(1));
      expect(repo.productDetailCalls.single.businessId, 42);
      expect(repo.productDetailCalls.single.productId, 1);
      expect(find.text('Leather belt'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows totals, sales, funnel and the orders link', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');

      await pumpBi(tester, repository: biFullRepository(), home: screen);

      expect(find.text(l10n.analyticsProdTotalsTitle), findsOneWidget);
      expect(find.text(l10n.analyticsProdSalesTitle), findsOneWidget);
      expect(find.text(l10n.analyticsProdFunnelTitle), findsOneWidget);
      expect(find.text(l10n.analyticsProdOrdersLinkNote), findsOneWidget);
      expect(find.text(l10n.analyticsProdOpenOrders), findsOneWidget);
    });

    testWidgets('an inactive product says so', (WidgetTester tester) async {
      final AppLocalizations l10n = await biL10n('en');
      final Map<String, dynamic> json = biProductDetailJson();
      (json['product'] as Map<String, dynamic>)['is_active'] = false;
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()..productDetail = biProductDetail(json);

      await pumpBi(tester, repository: repo, home: screen);

      expect(find.text(l10n.analyticsProdInactive), findsWidgets);
    });

    testWidgets('sales are listed per currency, never summed', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final String prefix =
          l10n.analyticsProdSalesLine('AAA', 'BBB').split('AAA').first;
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..productDetail = biProductDetail(
              biProductDetailJson(
                totals: _totals(
                  sales: <Map<String, dynamic>>[
                    biSalesJson(),
                    biSalesJson(currency: 'USD', value: '20.00', aov: '10.00'),
                  ],
                ),
              ),
            );

      await pumpBi(tester, repository: repo, home: screen);

      // One sales line per currency.
      expect(
        find.textContaining(prefix).evaluate().length,
        greaterThanOrEqualTo(2),
      );
    });

    testWidgets('the funnel overall rate is shown exactly as sent', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final String prefix =
          l10n.biFunnelOverall('XYZ').split('XYZ').first;
      // 3 / 80 would be 3.75%; the backend says 0.5 and the app must show 50.
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..productDetail = biProductDetail(
              biProductDetailJson(
                funnel: biFunnelJson(
                  counts: <int?>[80, 20, 10, 8, 3],
                  rates: <double?>[0.9, 0.9, 0.9, 0.9],
                  overallRate: 0.5,
                ),
              ),
            );

      await pumpBi(tester, repository: repo, home: screen);

      final Finder overall = find.textContaining(prefix);
      expect(overall, findsWidgets);
      final String shown = tester.widget<Text>(overall.first).data ?? '';
      expect(shown, contains('50'));
      expect(shown, isNot(contains('3.7')));
      expect(shown, isNot(contains('3.8')));
    });

    testWidgets('null numbers show a dash', (WidgetTester tester) async {
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..productDetail = biProductDetail(
              biProductDetailJson(
                totals: _totals(
                  views: null,
                  uniqueViews: null,
                  saves: null,
                  conversion: null,
                ),
              ),
            );

      await pumpBi(tester, repository: repo, home: screen);

      expect(find.text(_dash), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('states', () {
    testWidgets('loading keeps a request pending and shows no data', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()..gate = Completer<void>();

      await pumpBi(tester, repository: repo, home: screen, settle: false);
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.count('productDetail'), 1);
      expect(find.text(l10n.analyticsProdTotalsTitle), findsNothing);
      expect(find.text(l10n.analyticsProdLoadError), findsNothing);

      repo.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.text(l10n.analyticsProdTotalsTitle), findsOneWidget);
    });

    testWidgets('error shows the load-error message', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..errors['productDetail'] = const UnknownFailure(message: 'boom');

      await pumpBi(tester, repository: repo, home: screen);

      expect(find.text(l10n.analyticsProdLoadError), findsWidgets);
      expect(find.text(l10n.analyticsProdTotalsTitle), findsNothing);
    });

    testWidgets('no business profile: says so and sends no request', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo = biFullRepository();

      await pumpBi(
        tester,
        repository: repo,
        home: screen,
        hasBusiness: false,
      );

      expect(find.text(l10n.analyticsProdNoBusiness), findsWidgets);
      expect(repo.calls, isEmpty);
    });
  });

  group('language and theme', () {
    for (final String language in <String>['en', 'ar']) {
      for (final Brightness brightness in Brightness.values) {
        testWidgets('renders: $language / ${brightness.name}', (
          WidgetTester tester,
        ) async {
          final AppLocalizations l10n = await biL10n(language);

          await pumpBi(
            tester,
            repository: biFullRepository(),
            home: screen,
            locale: Locale(language),
            brightness: brightness,
          );

          expect(find.text(l10n.analyticsProdTotalsTitle), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}