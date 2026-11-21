import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_overview.dart';

import '../bi_fixtures.dart';

/// Part BI-04: what a KPI card shows next to its number. The client never
/// computes a percentage: it only reads the backend's `change_pct`.
void main() {
  AnalyticsOverview withDeltas(Map<String, dynamic> deltas) => biOverview(
    biOverviewJson(previousPeriod: biPreviousPeriodJson(deltas: deltas)),
  );

  group('MetricComparison.forMetric', () {
    test('previous_period = null -> noPreviousData for every key', () {
      final AnalyticsOverview o = biOverview();

      expect(o.previous, isNull);
      for (final String key in OverviewMetricKeys.withDelta) {
        final MetricComparison c = MetricComparison.forMetric(o, key);
        expect(c.kind, ComparisonKind.noPreviousData, reason: key);
        expect(c.fraction, isNull, reason: key);
      }
    });

    test('change_pct = null -> noPreviousData (previous value was 0)', () {
      final AnalyticsOverview o = withDeltas(<String, dynamic>{
        'likes': biDeltaJson(
          current: 40,
          previous: 0,
          change: 40,
          changePct: null,
        ),
      });

      final MetricComparison c = MetricComparison.forMetric(
        o,
        OverviewMetricKeys.likes,
      );

      expect(o.previous, isNotNull);
      expect(c.kind, ComparisonKind.noPreviousData);
      expect(c.fraction, isNull);
    });

    test('a positive fraction -> up, the backend value untouched', () {
      final AnalyticsOverview o = withDeltas(<String, dynamic>{
        'orders': biDeltaJson(
          current: 10,
          previous: 8,
          change: 2,
          changePct: 0.25,
        ),
      });

      final MetricComparison c = MetricComparison.forMetric(
        o,
        OverviewMetricKeys.orders,
      );

      expect(c.kind, ComparisonKind.up);
      expect(c.fraction, 0.25);
    });

    test('a negative fraction -> down', () {
      final AnalyticsOverview o = withDeltas(<String, dynamic>{
        'units': biDeltaJson(
          current: 9,
          previous: 10,
          change: -1,
          changePct: -0.1,
        ),
      });

      final MetricComparison c = MetricComparison.forMetric(
        o,
        OverviewMetricKeys.units,
      );

      expect(c.kind, ComparisonKind.down);
      expect(c.fraction, -0.1);
    });

    test('a zero fraction -> unchanged', () {
      final AnalyticsOverview o = withDeltas(<String, dynamic>{
        'saves': biDeltaJson(
          current: 5,
          previous: 5,
          change: 0,
          changePct: 0.0,
        ),
      });

      final MetricComparison c = MetricComparison.forMetric(
        o,
        OverviewMetricKeys.saves,
      );

      expect(c.kind, ComparisonKind.unchanged);
      expect(c.fraction, 0.0);
    });

    test(
      'a key without a delta (sales, aov, absent key) -> noPreviousData',
      () {
        final AnalyticsOverview o = withDeltas(<String, dynamic>{
          'orders': biDeltaJson(
            current: 10,
            previous: 8,
            change: 2,
            changePct: 0.25,
          ),
        });

        expect(
          MetricComparison.forMetric(o, 'sales').kind,
          ComparisonKind.noPreviousData,
        );
        expect(
          MetricComparison.forMetric(o, 'aov').kind,
          ComparisonKind.noPreviousData,
        );
        expect(
          MetricComparison.forMetric(o, OverviewMetricKeys.comments).kind,
          ComparisonKind.noPreviousData,
        );
      },
    );

    test('the none constant carries no fraction', () {
      expect(MetricComparison.none.kind, ComparisonKind.noPreviousData);
      expect(MetricComparison.none.fraction, isNull);
    });
  });

  group('OverviewMetricKeys', () {
    test('has the 16 delta keys of the contract and none for sales / aov', () {
      expect(OverviewMetricKeys.withDelta, hasLength(16));
      expect(OverviewMetricKeys.withDelta, isNot(contains('sales')));
      expect(OverviewMetricKeys.withDelta, isNot(contains('aov')));
      expect(
        OverviewMetricKeys.withDelta,
        containsAll(<String>[
          'product_views',
          'product_unique_views',
          'interests',
          'interested_customers',
          'orders',
          'pending_orders',
          'confirmed_orders',
          'completed_orders',
          'cancelled_orders',
          'units',
          'content_views',
          'content_unique_views',
          'likes',
          'comments',
          'saves',
          'in_app_shares',
        ]),
      );
    });
  });
}
