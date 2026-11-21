import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/data/dtos/content_dto.dart';
import 'package:social_commerce_app/features/business_console/data/dtos/orders_summary_dto.dart';
import 'package:social_commerce_app/features/business_console/data/dtos/overview_dto.dart';
import 'package:social_commerce_app/features/business_console/data/dtos/products_dto.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_content.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_common.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_orders_summary.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_overview.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_products.dart';
import 'package:social_commerce_app/features/orders/domain/order_status.dart';

import '../bi_fixtures.dart';

/// Part BI-04: wire parsing of the five analytics responses
/// (api_contract_BI02.md). Rules under test: missing data is null (never 0),
/// real counts keep their 0, money is a String, the funnel is kept exactly as
/// the backend sent it, and any contract break is a FormatException.
void main() {
  group('OverviewDto.parse', () {
    test('maps every field of a full response', () {
      final AnalyticsOverview o = OverviewDto.parse(biOverviewJson());

      expect(o.businessId, 42);
      expect(o.period.dateFrom, DateTime.utc(2026, 10, 1));
      expect(o.period.dateTo, DateTime.utc(2026, 10, 7));
      expect(o.period.days, 7);
      expect(o.period.label, '7d');
      expect(o.metrics.productViews, 100);
      expect(o.metrics.productUniqueViews, 80);
      expect(o.metrics.interests, 20);
      expect(o.metrics.interestedCustomers, 15);
      expect(o.metrics.orders, 10);
      expect(o.metrics.pendingOrders, 2);
      expect(o.metrics.confirmedOrders, 5);
      expect(o.metrics.completedOrders, 3);
      expect(o.metrics.cancelledOrders, 0);
      expect(o.metrics.units, 12);
      expect(o.metrics.contentViews, 500);
      expect(o.metrics.likes, 40);
      expect(o.metrics.inAppShares, 4);
      expect(o.metrics.sales.single.currency, 'EGP');
      expect(o.metrics.sales.single.salesValue, '300.00');
      expect(o.metrics.sales.single.soldOrders, 2);
      expect(o.metrics.sales.single.units, 4);
      expect(o.metrics.sales.single.aov, '150.00');
      expect(o.coverage.viewsAvailable, isTrue);
      expect(o.coverage.viewsComplete, isTrue);
      expect(o.dataUpdatedAt, DateTime.utc(2026, 10, 8, 2));
      expect(o.dataUpdatedAt!.isUtc, isTrue);
      expect(o.ordersDataUpdatedAt, DateTime.utc(2026, 10, 8, 9, 30));
    });

    test('a null view / engagement number stays null, a real 0 stays 0', () {
      final AnalyticsOverview o = OverviewDto.parse(
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
            interests: 0,
            orders: 0,
            sales: <Map<String, dynamic>>[],
          ),
          coverage: biCoverageJson(viewsAvailable: false, viewsComplete: false),
        ),
      );

      expect(o.metrics.productViews, isNull);
      expect(o.metrics.productUniqueViews, isNull);
      expect(o.metrics.contentViews, isNull);
      expect(o.metrics.contentUniqueViews, isNull);
      expect(o.metrics.likes, isNull);
      expect(o.metrics.comments, isNull);
      expect(o.metrics.saves, isNull);
      expect(o.metrics.inAppShares, isNull);
      expect(o.metrics.interests, 0);
      expect(o.metrics.orders, 0);
      expect(o.metrics.sales, isEmpty);
      expect(o.coverage.viewsAvailable, isFalse);
      expect(o.coverage.viewsComplete, isFalse);
    });

    test('previous_period null -> previous is null', () {
      final AnalyticsOverview o = OverviewDto.parse(biOverviewJson());

      expect(o.previous, isNull);
    });

    test(
      'previous_period present -> deltas keep a null change_pct as null',
      () {
        final AnalyticsOverview o = OverviewDto.parse(
          biOverviewJson(previousPeriod: biPreviousPeriodJson()),
        );

        final PreviousPeriod previous = o.previous!;
        expect(previous.period.dateFrom, DateTime.utc(2026, 9, 24));
        expect(previous.period.label, isNull);
        expect(previous.metrics.orders, 8);
        expect(previous.coverage.viewsComplete, isTrue);
        expect(previous.deltas['orders']!.changePct, 0.25);
        expect(previous.deltas['orders']!.change, 2);
        expect(previous.deltas['likes']!.previous, 0);
        expect(previous.deltas['likes']!.changePct, isNull);
        expect(previous.deltas.containsKey('sales'), isFalse);
      },
    );

    test('the funnel is kept exactly as sent: nothing is recomputed', () {
      // Deliberately inconsistent with the counts (3 / 80 would be 3.75%):
      // the app must show the backend's numbers, not its own arithmetic.
      final AnalyticsOverview o = OverviewDto.parse(
        biOverviewJson(
          funnel: biFunnelJson(
            counts: <int?>[80, 20, 10, 8, 3],
            rates: <double?>[0.9, 0.9, 0.9, 0.9],
            overallRate: 0.5,
            unitNote: 'note from server',
          ),
        ),
      );

      expect(o.funnel.stages.map((FunnelStage s) => s.key).toList(), <String>[
        'views',
        'interests',
        'orders',
        'confirmed',
        'completed',
      ]);
      expect(o.funnel.stages.map((FunnelStage s) => s.count).toList(), <int?>[
        80,
        20,
        10,
        8,
        3,
      ]);
      expect(
        o.funnel.conversions.map((FunnelConversion c) => c.rate).toList(),
        <double?>[0.9, 0.9, 0.9, 0.9],
      );
      expect(o.funnel.conversions.first.from, 'views');
      expect(o.funnel.conversions.first.to, 'interests');
      expect(o.funnel.overallRate, 0.5);
      expect(o.funnel.unitNote, 'note from server');
      expect(o.funnel.stage('orders')!.count, 10);
      expect(o.funnel.stage('nope'), isNull);
    });

    test('null funnel counts and rates stay null', () {
      final AnalyticsOverview o = OverviewDto.parse(
        biOverviewJson(
          funnel: biFunnelJson(
            counts: <int?>[null, 20, 10, 8, 3],
            rates: <double?>[null, 0.5, 0.8, 0.375],
            overallRate: null,
          ),
        ),
      );

      expect(o.funnel.stage('views')!.count, isNull);
      expect(o.funnel.conversions.first.rate, isNull);
      expect(o.funnel.overallRate, isNull);
    });

    test('money stays a String; a JSON number is rendered with 2 decimals', () {
      final AnalyticsOverview o = OverviewDto.parse(
        biOverviewJson(
          overview: biOverviewMetricsJson(
            sales: <Map<String, dynamic>>[
              <String, dynamic>{'currency': 'EGP', 'sales_value': 300},
              <String, dynamic>{'currency': 'USD', 'sales_value': '12.5'},
            ],
          ),
        ),
      );

      expect(o.metrics.sales, hasLength(2));
      expect(o.metrics.sales[0].salesValue, '300.00');
      expect(o.metrics.sales[1].salesValue, '12.5');
      expect(o.metrics.sales[0].aov, isNull);
    });

    test('a timestamp with an offset is converted to UTC', () {
      final AnalyticsOverview o = OverviewDto.parse(
        biOverviewJson(dataUpdatedAt: '2026-10-08T04:00:00+02:00'),
      );

      expect(o.dataUpdatedAt, DateTime.utc(2026, 10, 8, 2));
      expect(o.dataUpdatedAt!.isUtc, isTrue);
    });

    test('null timestamps stay null', () {
      final AnalyticsOverview o = OverviewDto.parse(
        biOverviewJson(dataUpdatedAt: null, ordersDataUpdatedAt: null),
      );

      expect(o.dataUpdatedAt, isNull);
      expect(o.ordersDataUpdatedAt, isNull);
    });

    test('a wrong type is a FormatException (never a silent 0)', () {
      expect(
        () => OverviewDto.parse(
          biOverviewJson(
            overview: (biOverviewMetricsJson()..['interests'] = '20'),
          ),
        ),
        throwsFormatException,
      );
    });

    test('a missing required count is a FormatException', () {
      final Map<String, dynamic> metrics =
          biOverviewMetricsJson()..remove('orders');

      expect(
        () => OverviewDto.parse(biOverviewJson(overview: metrics)),
        throwsFormatException,
      );
    });

    test('an impossible calendar date is a FormatException', () {
      final Map<String, dynamic> json = biOverviewJson();
      (json['period'] as Map<String, dynamic>)['date_from'] = '2026-02-30';

      expect(() => OverviewDto.parse(json), throwsFormatException);
    });
  });

  group('ProductsDto', () {
    test('parsePage maps rows, nulls and page metadata', () {
      final ProductsPage page = ProductsDto.parsePage(
        biProductsPageJson(
          results: <Map<String, dynamic>>[
            biProductRowJson(),
            biProductRowJson(
              productId: 2,
              name: 'Wallet',
              isActive: false,
              views: null,
              uniqueViews: null,
              saves: null,
              conversion: null,
              sales: <Map<String, dynamic>>[],
            ),
          ],
          count: 45,
          page: 1,
          pageSize: 20,
          totalPages: 3,
          coverage: biCoverageJson(viewsComplete: false),
        ),
      );

      expect(page.businessId, 42);
      expect(page.meta.count, 45);
      expect(page.meta.page, 1);
      expect(page.meta.pageSize, 20);
      expect(page.meta.totalPages, 3);
      expect(page.meta.hasMore, isTrue);
      expect(page.results, hasLength(2));
      expect(page.coverage.viewsComplete, isFalse);

      final ProductAnalyticsRow a = page.results[0];
      expect(a.productId, 1);
      expect(a.name, 'Leather belt');
      expect(a.isActive, isTrue);
      expect(a.views, 100);
      expect(a.interests, 10);
      expect(a.orders, 4);
      expect(a.soldOrders, 3);
      expect(a.units, 6);
      expect(a.conversion, 0.0375);
      expect(a.sales.single.salesValue, '450.00');
      // The list row has only currency + sales_value.
      expect(a.sales.single.soldOrders, isNull);
      expect(a.sales.single.units, isNull);
      expect(a.sales.single.aov, isNull);

      final ProductAnalyticsRow b = page.results[1];
      expect(b.isActive, isFalse);
      expect(b.views, isNull);
      expect(b.uniqueViews, isNull);
      expect(b.saves, isNull);
      expect(b.conversion, isNull);
      expect(b.sales, isEmpty);
    });

    test('hasMore is false on the last page', () {
      final ProductsPage page = ProductsDto.parsePage(
        biProductsPageJson(page: 3, totalPages: 3),
      );

      expect(page.meta.hasMore, isFalse);
    });

    test('an empty page is valid', () {
      final ProductsPage page = ProductsDto.parsePage(
        biProductsPageJson(
          results: <Map<String, dynamic>>[],
          count: 0,
          totalPages: 0,
        ),
      );

      expect(page.results, isEmpty);
      expect(page.meta.hasMore, isFalse);
    });

    test('a row without product_id is a FormatException', () {
      final Map<String, dynamic> row = biProductRowJson()..remove('product_id');

      expect(
        () => ProductsDto.parsePage(
          biProductsPageJson(results: <Map<String, dynamic>>[row]),
        ),
        throwsFormatException,
      );
    });

    test('parseDetail maps totals, funnel and the daily trend', () {
      final ProductAnalyticsDetail d = ProductsDto.parseDetail(
        biProductDetailJson(),
      );

      expect(d.product.productId, 1);
      expect(d.product.name, 'Leather belt');
      expect(d.product.isActive, isTrue);
      expect(d.totals.views, 100);
      expect(d.totals.saves, 5);
      expect(d.totals.sales.single.aov, '150.00');
      expect(d.totals.conversion, 0.0375);
      expect(d.interestedCustomers, 9);
      expect(d.funnel.stage('views')!.count, 80);
      expect(d.coverage.daysInRange, 7);
      expect(d.dataUpdatedAt, DateTime.utc(2026, 10, 8, 2));
      expect(d.ordersDataUpdatedAt, DateTime.utc(2026, 10, 8, 9, 30));

      expect(d.trend, hasLength(2));
      expect(d.trend[0].date, DateTime.utc(2026, 10, 1));
      expect(d.trend[0].views, 10);
      expect(d.trend[0].sales, <String, String>{'EGP': '150.00'});
      // An uncovered day: views / interests are null, orders is a real 0.
      expect(d.trend[1].views, isNull);
      expect(d.trend[1].uniqueViews, isNull);
      expect(d.trend[1].interests, isNull);
      expect(d.trend[1].orders, 0);
      expect(d.trend[1].sales, isEmpty);
    });

    test('parseDetail keeps a null totals conversion', () {
      final ProductAnalyticsDetail d = ProductsDto.parseDetail(
        biProductDetailJson(
          totals: <String, dynamic>{
            'views': null,
            'unique_views': null,
            'saves': null,
            'interests': 0,
            'orders': 0,
            'sold_orders': 0,
            'units': 0,
            'sales': <Map<String, dynamic>>[],
            'conversion': null,
          },
        ),
      );

      expect(d.totals.views, isNull);
      expect(d.totals.conversion, isNull);
      expect(d.totals.interests, 0);
      expect(d.totals.sales, isEmpty);
    });
  });

  group('ContentDto', () {
    test('parsePage maps rows and keeps null engagement numbers null', () {
      final ContentPage page = ContentDto.parsePage(
        biContentPageJson(
          type: 'reel',
          results: <Map<String, dynamic>>[
            biContentRowJson(),
            biContentRowJson(
              contentType: 'reel',
              contentId: 9,
              caption: '',
              createdAt: null,
              views: null,
              uniqueViews: null,
              likes: null,
              comments: null,
              saves: null,
              inAppShares: null,
              engagementRate: null,
            ),
          ],
          totalPages: 2,
        ),
      );

      expect(page.type, 'reel');
      expect(page.meta.hasMore, isTrue);
      expect(page.results, hasLength(2));

      final ContentAnalyticsRow a = page.results[0];
      expect(a.contentType, 'post');
      expect(a.contentId, 5);
      expect(a.captionPreview, 'Summer sale');
      expect(a.createdAt, DateTime.utc(2026, 9, 30, 10));
      expect(a.likes, 30);
      expect(a.engagementRate, 0.28);

      final ContentAnalyticsRow b = page.results[1];
      expect(b.contentType, 'reel');
      expect(b.captionPreview, '');
      expect(b.createdAt, isNull);
      expect(b.views, isNull);
      expect(b.likes, isNull);
      expect(b.inAppShares, isNull);
      expect(b.engagementRate, isNull);
    });

    test('parseDetail keeps the internal and external blocks separate', () {
      final ContentDetail d = ContentDto.parseDetail(biContentDetailJson());

      expect(d.content.contentType, 'post');
      expect(d.content.contentId, 5);
      expect(d.internal.source, 'internal_events');
      expect(d.internal.totals.views, 200);
      expect(d.internal.totals.inAppShares, 2);
      expect(d.internal.totals.engagementRate, 0.28);
      expect(d.internal.trend.single.date, DateTime.utc(2026, 10, 1));
      expect(d.internal.trend.single.metrics.likes, 30);
      expect(
        d.internal.notes.keys,
        containsAll(<String>['in_app_shares', 'reach']),
      );
      expect(d.external.metrics.single.platform, 'instagram');
      expect(d.external.metrics.single.value, 1200);
      expect(d.external.metrics.single.isManual, isTrue);
      expect(d.external.note, isNotNull);
      // The external value is NOT folded into the internal totals.
      expect(d.internal.totals.views, isNot(200 + 1200));
    });

    test('parseDetail with no external numbers and null internal numbers', () {
      final ContentDetail d = ContentDto.parseDetail(
        biContentDetailJson(
          totals: biContentMetricsJson(
            views: null,
            uniqueViews: null,
            likes: null,
            comments: null,
            saves: null,
            inAppShares: null,
            engagementRate: null,
          ),
          trend: <Map<String, dynamic>>[],
          externalMetrics: <Map<String, dynamic>>[],
          externalNote: null,
        ),
      );

      expect(d.internal.totals.views, isNull);
      expect(d.internal.totals.engagementRate, isNull);
      expect(d.internal.trend, isEmpty);
      expect(d.external.metrics, isEmpty);
      expect(d.external.note, isNull);
    });

    test(
      'parseExternalMetrics: providers_registered [] means nothing synced',
      () {
        final ExternalMetricsResponse r = ContentDto.parseExternalMetrics(
          biExternalMetricsJson(
            metrics: <Map<String, dynamic>>[
              biExternalMetricJson(),
              biExternalMetricJson(
                platform: 'tiktok',
                metricType: 'likes',
                value: 0,
                externalReference: 'ref-1',
              ),
            ],
          ),
        );

        expect(r.providersRegistered, isEmpty);
        expect(r.metrics, hasLength(2));
        expect(r.metrics[1].platform, 'tiktok');
        expect(r.metrics[1].value, 0);
        expect(r.metrics[1].externalReference, 'ref-1');
        expect(r.metrics.every((ExternalMetric m) => m.isManual), isTrue);
      },
    );

    test('isManual is true for anything that is not explicitly synced', () {
      ExternalMetric withSource(String source) => ExternalMetric(
        platform: 'instagram',
        metricType: 'views',
        value: 1,
        source: source,
        lastUpdated: null,
        externalReference: '',
      );

      expect(withSource('manual').isManual, isTrue);
      expect(withSource('synced').isManual, isFalse);
      expect(withSource('something-else').isManual, isTrue);
    });

    test('inputToJson never sends source and trims the reference', () {
      final Map<String, Object> json = ContentDto.inputToJson(
        ExternalMetricInput(
          platform: 'instagram',
          metricType: 'views',
          metricValue: 1200,
          capturedAt: DateTime.parse('2026-10-05T14:00:00+02:00'),
          externalReference: '  post-1  ',
        ),
      );

      expect(json, <String, Object>{
        'platform': 'instagram',
        'metric_type': 'views',
        'metric_value': 1200,
        'captured_at': '2026-10-05T12:00:00.000Z',
        'external_reference': 'post-1',
      });
      expect(json.containsKey('source'), isFalse);
    });

    test('inputToJson omits an absent timestamp and a blank reference', () {
      final Map<String, Object> json = ContentDto.inputToJson(
        ExternalMetricInput(
          platform: 'facebook',
          metricType: 'saves',
          metricValue: 0,
          externalReference: '   ',
        ),
      );

      expect(json, <String, Object>{
        'platform': 'facebook',
        'metric_type': 'saves',
        'metric_value': 0,
      });
    });

    test('ExternalMetricInput rejects values outside the contract', () {
      expect(
        () => ExternalMetricInput(
          platform: 'youtube',
          metricType: 'views',
          metricValue: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExternalMetricInput(
          platform: 'instagram',
          metricType: 'engagement',
          metricValue: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExternalMetricInput(
          platform: 'instagram',
          metricType: 'views',
          metricValue: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('OrdersSummaryDto.parse', () {
    test('maps statuses in lifecycle order, sales, trend and top products', () {
      final OrdersSummary s = OrdersSummaryDto.parse(biOrdersSummaryJson());

      expect(s.businessId, 42);
      expect(s.orders, 10);
      expect(s.units, 12);
      expect(
        s.byStatus.map((OrderStatusCount c) => c.status).toList(),
        <OrderStatus>[
          OrderStatus.pending,
          OrderStatus.confirmed,
          OrderStatus.processing,
          OrderStatus.shipped,
          OrderStatus.delivered,
          OrderStatus.cancelled,
        ],
      );
      expect(s.byStatus.map((OrderStatusCount c) => c.orders).toList(), <int>[
        2,
        3,
        1,
        1,
        3,
        0,
      ]);
      expect(s.sales.single.salesValue, '300.00');
      expect(s.salesDefinition, isNotNull);
      expect(s.trend, hasLength(2));
      expect(s.trend[0].date, DateTime.utc(2026, 10, 1));
      expect(s.trend[0].sales, <String, String>{'EGP': '300.00'});
      expect(s.trend[1].sales, isEmpty);
      expect(s.topProducts.single.productId, 1);
      expect(s.topProducts.single.salesValue, '450.00');
      expect(s.topProducts.single.soldOrders, 3);
      expect(s.dataUpdatedAt, DateTime.utc(2026, 10, 8, 9, 30));
    });

    test('an unknown status becomes OrderStatus.unknown', () {
      final OrdersSummary s = OrdersSummaryDto.parse(
        biOrdersSummaryJson(
          byStatus: <Map<String, dynamic>>[
            <String, dynamic>{'status': 'weird', 'orders': 1},
          ],
        ),
      );

      expect(s.byStatus.single.status, OrderStatus.unknown);
      expect(s.byStatus.single.orders, 1);
    });

    test('no sales: an empty list and a real 0 orders', () {
      final OrdersSummary s = OrdersSummaryDto.parse(
        biOrdersSummaryJson(
          orders: 0,
          units: 0,
          sales: <Map<String, dynamic>>[],
          topProducts: <Map<String, dynamic>>[],
        ),
      );

      expect(s.orders, 0);
      expect(s.units, 0);
      expect(s.sales, isEmpty);
      expect(s.topProducts, isEmpty);
    });

    test('several currencies stay separate (never summed)', () {
      final OrdersSummary s = OrdersSummaryDto.parse(
        biOrdersSummaryJson(
          sales: <Map<String, dynamic>>[
            biSalesJson(),
            biSalesJson(currency: 'USD', value: '20.00', aov: '10.00'),
          ],
        ),
      );

      expect(
        s.sales.map((SalesEntry e) => '${e.currency}:${e.salesValue}').toList(),
        <String>['EGP:300.00', 'USD:20.00'],
      );
    });

    test('a missing trend is a FormatException', () {
      final Map<String, dynamic> json = biOrdersSummaryJson()..remove('trend');

      expect(() => OrdersSummaryDto.parse(json), throwsFormatException);
    });
  });

  group('ordering keys and pagination metadata', () {
    test('product ordering keys are contract fields', () {
      const Set<String> contractFields = <String>{
        'views',
        'unique_views',
        'interests',
        'orders',
        'sales',
        'conversion',
      };
      for (final ProductSort sort in ProductSort.values) {
        final String field = sort.ordering.replaceFirst('-', '');
        expect(contractFields, contains(field), reason: sort.name);
      }
    });

    test('lowest conversion is plain `conversion` (ascending)', () {
      expect(ProductSort.lowestConversion.ordering, 'conversion');
      expect(ProductSort.highestConversion.ordering, '-conversion');
      expect(ProductSort.mostViewed.ordering, '-views');
      expect(ProductSort.highestSales.ordering, '-sales');
    });

    test('content ordering keys are contract fields', () {
      const Set<String> contractFields = <String>{
        'created_at',
        'views',
        'unique_views',
        'likes',
        'comments',
        'saves',
        'in_app_shares',
        'engagement_rate',
      };
      for (final ContentSort sort in ContentSort.values) {
        final String field = sort.ordering.replaceFirst('-', '');
        expect(contractFields, contains(field), reason: sort.name);
      }
      expect(ContentSort.newest.ordering, '-created_at');
      expect(ContentSort.highestEngagement.ordering, '-engagement_rate');
    });

    test('content type filter wire values', () {
      expect(ContentTypeFilter.all.wire, 'all');
      expect(ContentTypeFilter.post.wire, 'post');
      expect(ContentTypeFilter.reel.wire, 'reel');
    });
  });
}
