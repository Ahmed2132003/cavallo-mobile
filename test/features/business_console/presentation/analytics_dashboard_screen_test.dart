import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_content.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_period.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_products.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_dashboard_screen.dart';
import 'package:social_commerce_app/features/business_console/presentation/widgets/products/products_ordering_bar.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import '../bi_fixtures.dart';
import '../fake_business_analytics_repository.dart';
import 'bi_test_harness.dart';

/// Part BI-04: the five-section Analytics dashboard, driven through the real
/// screen and real providers over [FakeBusinessAnalyticsRepository].
const String _dash = '—';

bool _showsLoading() =>
    find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
    find
        .byWidgetPredicate(
          (Widget w) =>
              w.runtimeType.toString().toLowerCase().contains('shimmer'),
        )
        .evaluate()
        .isNotEmpty;

void _expectTabLabels(AppLocalizations l10n) {
  final Map<String, String> labels = <String, String>{
    'overview': l10n.biTabOverview,
    'products': l10n.biTabProducts,
    'orders': l10n.biTabOrders,
    'content': l10n.biTabContent,
    'external': l10n.biTabExternal,
  };
  labels.forEach((String key, String label) {
    expect(
      find.descendant(
        of: find.byKey(ValueKey<String>('bi-tab-$key')),
        matching: find.text(label),
      ),
      findsOneWidget,
      reason: 'tab $key',
    );
  });
}

void main() {
  const Widget dashboard = AnalyticsDashboardScreen();

  group('language and theme', () {
    testWidgets('English: five tabs with the English labels', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      await pumpBi(tester, repository: biFullRepository(), home: dashboard);

      _expectTabLabels(l10n);
      expect(l10n.biTabOverview, 'Overview');
      expect(
        Directionality.of(
          tester.element(find.byType(AnalyticsDashboardScreen)),
        ),
        TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Arabic: five tabs with the Arabic labels, RTL', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('ar');
      await pumpBi(
        tester,
        repository: biFullRepository(),
        home: dashboard,
        locale: const Locale('ar'),
      );

      _expectTabLabels(l10n);
      expect(l10n.biTabOverview, 'نظرة عامة');
      expect(
        Directionality.of(
          tester.element(find.byType(AnalyticsDashboardScreen)),
        ),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });

    for (final String language in <String>['en', 'ar']) {
      for (final Brightness brightness in Brightness.values) {
        testWidgets('renders every tab: $language / ${brightness.name}', (
          WidgetTester tester,
        ) async {
          await pumpBi(
            tester,
            repository: biFullRepository(),
            home: dashboard,
            locale: Locale(language),
            brightness: brightness,
          );

          for (final String tab in <String>[
            'overview',
            'products',
            'orders',
            'content',
            'external',
          ]) {
            await openBiTab(tester, tab);
            // An overflow or a build error is reported as an exception.
            expect(tester.takeException(), isNull, reason: 'tab $tab');
          }
        });
      }
    }
  });

  group('overview: loading, error, empty-ish states', () {
    testWidgets('loading: a request is in flight, nothing else is shown', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()..gate = Completer<void>();

      await pumpBi(tester, repository: repo, home: dashboard, settle: false);
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.count('overview'), 1);
      expect(_showsLoading(), isTrue);
      expect(find.text(l10n.biLoadFailed), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('bi-data-updated-at')),
        findsNothing,
      );

      repo.gate!.complete();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('bi-data-updated-at')),
        findsWidgets,
      );
      expect(find.text(l10n.biLoadFailed), findsNothing);
    });

    testWidgets('error: the typed failure shows the load-failed message', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..errors['overview'] = const UnknownFailure(message: 'boom');

      await pumpBi(tester, repository: repo, home: dashboard);

      expect(find.text(l10n.biLoadFailed), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('bi-data-updated-at')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no business profile: says so and sends no request', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo = biFullRepository();

      await pumpBi(
        tester,
        repository: repo,
        home: dashboard,
        hasBusiness: false,
      );

      expect(find.text(l10n.biNoBusiness), findsWidgets);
      expect(repo.calls, isEmpty);
    });
  });

  group('null is a dash, never 0', () {
    testWidgets('overview: null numbers show a dash', (
      WidgetTester tester,
    ) async {
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..overview = biOverview(
              biOverviewJson(
                overview: biOverviewMetricsJson(
                  productViews: null,
                  productUniqueViews: null,
                  contentViews: null,
                  contentUniqueViews: null,
                  likes: null,
                  comments: null,
                  saves: null,
                  inAppShares: null,
                ),
              ),
            );

      await pumpBi(tester, repository: repo, home: dashboard);

      expect(find.text(_dash), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overview: previous_period null -> "No previous data"', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');

      await pumpBi(tester, repository: biFullRepository(), home: dashboard);

      expect(find.text(l10n.biNoPreviousData), findsWidgets);
    });

    testWidgets(
      'overview: previous_period present but every change_pct null -> still '
      '"No previous data"',
      (WidgetTester tester) async {
        final AppLocalizations l10n = await biL10n('en');
        final FakeBusinessAnalyticsRepository repo =
            biFullRepository()
              ..overview = biOverview(
                biOverviewJson(
                  previousPeriod: biPreviousPeriodJson(
                    deltas: <String, dynamic>{
                      'orders': biDeltaJson(
                        current: 10,
                        previous: 0,
                        change: 10,
                        changePct: null,
                      ),
                    },
                  ),
                ),
              );

        await pumpBi(tester, repository: repo, home: dashboard);

        expect(find.text(l10n.biNoPreviousData), findsWidgets);
      },
    );

    testWidgets('overview: views unavailable / incomplete are explained', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');

      final FakeBusinessAnalyticsRepository unavailable =
          biFullRepository()
            ..overview = biOverview(
              biOverviewJson(
                coverage: biCoverageJson(
                  viewsAvailable: false,
                  viewsComplete: false,
                ),
              ),
            );
      await pumpBi(tester, repository: unavailable, home: dashboard);
      expect(find.text(l10n.biViewsUnavailable), findsWidgets);

      final FakeBusinessAnalyticsRepository incomplete =
          biFullRepository()
            ..overview = biOverview(
              biOverviewJson(coverage: biCoverageJson(viewsComplete: false)),
            );
      await pumpBi(tester, repository: incomplete, home: dashboard);
      expect(find.text(l10n.biViewsIncomplete), findsWidgets);
    });

    testWidgets('products: null views and conversion show a dash', (
      WidgetTester tester,
    ) async {
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..productsPages = <ProductsPage>[
              biProductsPage(
                biProductsPageJson(
                  results: <Map<String, dynamic>>[
                    biProductRowJson(
                      views: null,
                      uniqueViews: null,
                      saves: null,
                      conversion: null,
                    ),
                  ],
                  coverage: biCoverageJson(viewsComplete: false),
                ),
              ),
            ];

      await pumpBi(tester, repository: repo, home: dashboard);
      await openBiTab(tester, 'products');

      expect(find.text('Leather belt'), findsOneWidget);
      expect(find.text(_dash), findsWidgets);
    });

    testWidgets('content: null numbers show a dash', (
      WidgetTester tester,
    ) async {
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..contentPages = <ContentPage>[
              biContentPage(
                biContentPageJson(
                  results: <Map<String, dynamic>>[
                    biContentRowJson(
                      views: null,
                      uniqueViews: null,
                      likes: null,
                      comments: null,
                      saves: null,
                      inAppShares: null,
                      engagementRate: null,
                    ),
                  ],
                ),
              ),
            ];

      await pumpBi(tester, repository: repo, home: dashboard);
      await openBiTab(tester, 'content');

      expect(find.text('Summer sale'), findsOneWidget);
      expect(find.text(_dash), findsWidgets);
    });
  });

  group('empty states', () {
    testWidgets('orders: no orders in the period', (WidgetTester tester) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..ordersSummary = biOrdersSummary(
              biOrdersSummaryJson(
                orders: 0,
                units: 0,
                byStatus: biZeroStatuses(),
                sales: <Map<String, dynamic>>[],
                trend: <Map<String, dynamic>>[],
                topProducts: <Map<String, dynamic>>[],
              ),
            );

      await pumpBi(tester, repository: repo, home: dashboard);
      await openBiTab(tester, 'orders');

      expect(find.text(l10n.biOrdersEmpty), findsWidgets);
    });

    testWidgets('products: empty list', (WidgetTester tester) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..productsPages = <ProductsPage>[
              biProductsPage(
                biProductsPageJson(
                  results: <Map<String, dynamic>>[],
                  count: 0,
                  totalPages: 0,
                ),
              ),
            ];

      await pumpBi(tester, repository: repo, home: dashboard);
      await openBiTab(tester, 'products');

      expect(find.text(l10n.analyticsProdEmpty), findsOneWidget);
    });

    testWidgets('content: empty list', (WidgetTester tester) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..contentPages = <ContentPage>[
              biContentPage(
                biContentPageJson(
                  results: <Map<String, dynamic>>[],
                  count: 0,
                  totalPages: 0,
                ),
              ),
            ];

      await pumpBi(tester, repository: repo, home: dashboard);
      await openBiTab(tester, 'content');

      expect(find.text(l10n.analyticsContentEmpty), findsOneWidget);
    });

    testWidgets('products error shows the load-failed message', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..errors['products'] = const UnknownFailure(message: 'boom');

      await pumpBi(tester, repository: repo, home: dashboard);
      await openBiTab(tester, 'products');

      // The Products tab has its own section-specific failure message
      // (analyticsProdLoadError), not the shared biLoadFailed text.
      expect(find.text(l10n.analyticsProdLoadError), findsWidgets);
    });

    testWidgets('external tab shows its manual-entry introduction', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');

      await pumpBi(tester, repository: biFullRepository(), home: dashboard);
      await openBiTab(tester, 'external');

      expect(find.text(l10n.analyticsExternalIntro), findsOneWidget);
    });
  });

  group('switching tabs does not reload', () {
    testWidgets('a second visit to every tab sends no new request', (
      WidgetTester tester,
    ) async {
      final FakeBusinessAnalyticsRepository repo = biFullRepository();
      await pumpBi(tester, repository: repo, home: dashboard);
      expect(repo.count('overview'), 1);

      const List<String> tabs = <String>[
        'products',
        'orders',
        'content',
        'external',
        'overview',
      ];
      for (final String tab in tabs) {
        await openBiTab(tester, tab);
      }
      final List<String> afterFirstRound = List<String>.of(repo.calls);
      expect(repo.count('overview'), 1);
      expect(repo.count('products'), greaterThanOrEqualTo(1));
      expect(repo.count('orders'), greaterThanOrEqualTo(1));
      expect(repo.count('content'), greaterThanOrEqualTo(1));

      for (final String tab in tabs) {
        await openBiTab(tester, tab);
      }

      expect(repo.calls, afterFirstRound);
    });
  });

  group('shared period', () {
    testWidgets(
      'picking 14 days refetches with that period, and every section uses it',
      (WidgetTester tester) async {
        final AppLocalizations l10n = await biL10n('en');
        final FakeBusinessAnalyticsRepository repo = biFullRepository();
        await pumpBi(tester, repository: repo, home: dashboard);
        final int before = repo.overviewCalls.length;

        await tester.tap(find.text(l10n.biPresetLast14));
        await tester.pumpAndSettle();

        expect(repo.overviewCalls.length, before + 1);
        final AnalyticsPeriod picked = repo.overviewCalls.last.period;
        expect(picked.preset, AnalyticsPreset.last14);
        expect(picked.days, 14);

        await openBiTab(tester, 'products');
        await openBiTab(tester, 'orders');
        await openBiTab(tester, 'content');

        expect(repo.productsCalls.last.period, picked);
        expect(repo.ordersCalls.last.period, picked);
        expect(repo.contentCalls.last.period, picked);
      },
    );

    testWidgets('the period bar shows the range', (WidgetTester tester) async {
      await pumpBi(tester, repository: biFullRepository(), home: dashboard);

      expect(
        find.byKey(const ValueKey<String>('bi-period-range')),
        findsOneWidget,
      );
    });
  });

  group('sorting, filtering and pagination', () {
    testWidgets('products: "Load more" fetches page 2 and appends it', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..productsPages = <ProductsPage>[
              biProductsPage(
                biProductsPageJson(
                  results: <Map<String, dynamic>>[biProductRowJson()],
                  count: 2,
                  totalPages: 2,
                ),
              ),
              biProductsPage(
                biProductsPageJson(
                  results: <Map<String, dynamic>>[
                    biProductRowJson(productId: 2, name: 'Wallet'),
                  ],
                  count: 2,
                  page: 2,
                  totalPages: 2,
                ),
              ),
            ];
      await pumpBi(tester, repository: repo, home: dashboard);
      await openBiTab(tester, 'products');
      expect(find.text('Leather belt'), findsOneWidget);
      expect(find.text('Wallet'), findsNothing);

      await tester.ensureVisible(find.text(l10n.analyticsProdLoadMore));
      await tester.tap(find.text(l10n.analyticsProdLoadMore));
      await tester.pumpAndSettle();

      expect(repo.productsCalls.map((c) => c.page).toList(), <int>[1, 2]);
      expect(find.text('Leather belt'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text(l10n.analyticsProdLoadMore), findsNothing);
    });

    testWidgets(
      'products: choosing "Lowest conversion" refetches page 1 with that sort',
      (WidgetTester tester) async {
        final FakeBusinessAnalyticsRepository repo = biFullRepository();
        await pumpBi(tester, repository: repo, home: dashboard);
        await openBiTab(tester, 'products');
        final int before = repo.productsCalls.length;

        final Finder lowestConversionChip = find.byKey(
          const Key('analytics-products-order-lowestConversion'),
        );
        // The ordering bar is a lazy horizontal ListView: the last chip is
        // not built until the list is scrolled to it. Anchor the Scrollable
        // on the bar itself (always built), not on a chip, because chips
        // that scroll out of range are disposed.
        final Finder orderingScrollable = find.descendant(
          of: find.byType(ProductsOrderingBar),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          lowestConversionChip,
          100,
          scrollable: orderingScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(lowestConversionChip);
        await tester.pumpAndSettle();

        expect(repo.productsCalls.length, greaterThan(before));
        expect(repo.productsCalls.last.sort, ProductSort.lowestConversion);
        expect(repo.productsCalls.last.sort.ordering, 'conversion');
        expect(repo.productsCalls.last.page, 1);
      },
    );

    testWidgets('content: choosing "Reels" refetches with type=reel', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo = biFullRepository();
      await pumpBi(tester, repository: repo, home: dashboard);
      await openBiTab(tester, 'content');
      final int before = repo.contentCalls.length;

      await tester.tap(find.text(l10n.analyticsContentTypeReels));
      await tester.pumpAndSettle();

      expect(repo.contentCalls.length, greaterThan(before));
      expect(repo.contentCalls.last.type, ContentTypeFilter.reel);
      expect(repo.contentCalls.last.page, 1);
    });

    testWidgets('content: "Load more" fetches page 2', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..contentPages = <ContentPage>[
              biContentPage(
                biContentPageJson(
                  results: <Map<String, dynamic>>[biContentRowJson()],
                  count: 2,
                  totalPages: 2,
                ),
              ),
              biContentPage(
                biContentPageJson(
                  results: <Map<String, dynamic>>[
                    biContentRowJson(
                      contentType: 'reel',
                      contentId: 9,
                      caption: 'New reel',
                    ),
                  ],
                  count: 2,
                  page: 2,
                  totalPages: 2,
                ),
              ),
            ];
      await pumpBi(tester, repository: repo, home: dashboard);
      await openBiTab(tester, 'content');

      await tester.ensureVisible(find.text(l10n.analyticsProdLoadMore));
      await tester.tap(find.text(l10n.analyticsProdLoadMore));
      await tester.pumpAndSettle();

      expect(repo.contentCalls.map((c) => c.page).toList(), <int>[1, 2]);
      expect(find.text('Summer sale'), findsOneWidget);
      expect(find.text('New reel'), findsOneWidget);
    });
  });
}
