import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_period.dart';

/// Part BI-04: the ONE period shared by every section. Rolling presets end
/// YESTERDAY (UTC); all "today" maths uses the UTC date of the injected clock;
/// the app always sends date_from + date_to (never `period=`).
void main() {
  // 2026-10-15 12:00 UTC.
  final DateTime now = DateTime.utc(2026, 10, 15, 12);

  AnalyticsPeriod resolve(AnalyticsPreset preset, {DateTime? at}) =>
      AnalyticsPeriod.resolve(preset, now: at ?? now);

  group('rolling presets end yesterday (UTC)', () {
    test('last 7 days', () {
      final AnalyticsPeriod p = resolve(AnalyticsPreset.last7);

      expect(p.from, DateTime.utc(2026, 10, 8));
      expect(p.to, DateTime.utc(2026, 10, 14));
      expect(p.days, 7);
    });

    test('last 14 days', () {
      final AnalyticsPeriod p = resolve(AnalyticsPreset.last14);

      expect(p.from, DateTime.utc(2026, 10, 1));
      expect(p.to, DateTime.utc(2026, 10, 14));
      expect(p.days, 14);
    });

    test('last 30 days', () {
      final AnalyticsPeriod p = resolve(AnalyticsPreset.last30);

      expect(p.from, DateTime.utc(2026, 9, 15));
      expect(p.to, DateTime.utc(2026, 10, 14));
      expect(p.days, 30);
    });

    test('last 90 days', () {
      final AnalyticsPeriod p = resolve(AnalyticsPreset.last90);

      expect(p.from, DateTime.utc(2026, 7, 17));
      expect(p.to, DateTime.utc(2026, 10, 14));
      expect(p.days, 90);
    });

    test('rollingDays of every preset', () {
      expect(AnalyticsPreset.last7.rollingDays, 7);
      expect(AnalyticsPreset.last14.rollingDays, 14);
      expect(AnalyticsPreset.last30.rollingDays, 30);
      expect(AnalyticsPreset.last90.rollingDays, 90);
      expect(AnalyticsPreset.thisMonth.rollingDays, isNull);
      expect(AnalyticsPreset.previousMonth.rollingDays, isNull);
      expect(AnalyticsPreset.custom.rollingDays, isNull);
    });

    test('crossing a month and a year boundary', () {
      final AnalyticsPeriod p = resolve(
        AnalyticsPreset.last7,
        at: DateTime.utc(2026, 1, 3, 8),
      );

      expect(p.from, DateTime.utc(2025, 12, 27));
      expect(p.to, DateTime.utc(2026, 1, 2));
      expect(p.days, 7);
    });
  });

  group('UTC conversion (Egypt is UTC+2/+3)', () {
    test('00:30 in Cairo is still the PREVIOUS day in UTC', () {
      // 2026-10-15 00:30 at +02:00 == 2026-10-14 22:30 UTC.
      final DateTime cairoAfterMidnight = DateTime.parse(
        '2026-10-15T00:30:00+02:00',
      );

      final AnalyticsPeriod p = resolve(
        AnalyticsPreset.last7,
        at: cairoAfterMidnight,
      );

      // UTC today = Oct 14, so yesterday (the last day) = Oct 13. Using the
      // device-local date would wrongly end on Oct 14.
      expect(p.to, DateTime.utc(2026, 10, 13));
      expect(p.from, DateTime.utc(2026, 10, 7));
    });

    test('exactly 00:00 UTC is already the new day', () {
      final AnalyticsPeriod p = resolve(
        AnalyticsPreset.last7,
        at: DateTime.utc(2026, 10, 15),
      );

      expect(p.to, DateTime.utc(2026, 10, 14));
    });

    test('a late-evening local time that is already tomorrow in UTC', () {
      // 2026-10-14 23:30 at -02:00 == 2026-10-15 01:30 UTC.
      final AnalyticsPeriod p = resolve(
        AnalyticsPreset.last7,
        at: DateTime.parse('2026-10-14T23:30:00-02:00'),
      );

      expect(p.to, DateTime.utc(2026, 10, 14));
    });

    test('from and to are always UTC midnights', () {
      for (final AnalyticsPreset preset in <AnalyticsPreset>[
        AnalyticsPreset.last7,
        AnalyticsPreset.last14,
        AnalyticsPreset.last30,
        AnalyticsPreset.last90,
        AnalyticsPreset.thisMonth,
        AnalyticsPreset.previousMonth,
      ]) {
        final AnalyticsPeriod p = resolve(preset);
        expect(p.from.isUtc, isTrue, reason: preset.name);
        expect(p.to.isUtc, isTrue, reason: preset.name);
        expect(p.from.hour, 0, reason: preset.name);
        expect(p.to.hour, 0, reason: preset.name);
      }
    });
  });

  group('this month / previous month', () {
    test('this month runs from the 1st to yesterday', () {
      final AnalyticsPeriod p = resolve(AnalyticsPreset.thisMonth);

      expect(p.from, DateTime.utc(2026, 10, 1));
      expect(p.to, DateTime.utc(2026, 10, 14));
      expect(p.days, 14);
    });

    test('on the 1st, this month is just that day', () {
      final AnalyticsPeriod p = resolve(
        AnalyticsPreset.thisMonth,
        at: DateTime.utc(2026, 10, 1, 5),
      );

      expect(p.from, DateTime.utc(2026, 10, 1));
      expect(p.to, DateTime.utc(2026, 10, 1));
      expect(p.days, 1);
    });

    test('previous month is the whole previous calendar month', () {
      final AnalyticsPeriod p = resolve(AnalyticsPreset.previousMonth);

      expect(p.from, DateTime.utc(2026, 9, 1));
      expect(p.to, DateTime.utc(2026, 9, 30));
      expect(p.days, 30);
    });

    test('previous month of January is December of the previous year', () {
      final AnalyticsPeriod p = resolve(
        AnalyticsPreset.previousMonth,
        at: DateTime.utc(2026, 1, 10),
      );

      expect(p.from, DateTime.utc(2025, 12, 1));
      expect(p.to, DateTime.utc(2025, 12, 31));
      expect(p.days, 31);
    });

    test('previous month of March counts February of a leap year', () {
      final AnalyticsPeriod p = resolve(
        AnalyticsPreset.previousMonth,
        at: DateTime.utc(2028, 3, 5),
      );

      expect(p.from, DateTime.utc(2028, 2, 1));
      expect(p.to, DateTime.utc(2028, 2, 29));
      expect(p.days, 29);
    });
  });

  group('custom range', () {
    test('uses only the picked year/month/day (no hour shifting)', () {
      final AnalyticsPeriod p = AnalyticsPeriod.resolve(
        AnalyticsPreset.custom,
        now: now,
        customFrom: DateTime(2026, 10, 3, 23, 59),
        customTo: DateTime(2026, 10, 9, 1),
      );

      expect(p.preset, AnalyticsPreset.custom);
      expect(p.from, DateTime.utc(2026, 10, 3));
      expect(p.to, DateTime.utc(2026, 10, 9));
      expect(p.days, 7);
    });

    test('a single day is valid', () {
      final AnalyticsPeriod p = AnalyticsPeriod.resolve(
        AnalyticsPreset.custom,
        now: now,
        customFrom: DateTime.utc(2026, 10, 3),
        customTo: DateTime.utc(2026, 10, 3),
      );

      expect(p.days, 1);
    });

    test('custom without its dates is an ArgumentError', () {
      expect(
        () => AnalyticsPeriod.resolve(AnalyticsPreset.custom, now: now),
        throwsArgumentError,
      );
      expect(
        () => AnalyticsPeriod.resolve(
          AnalyticsPreset.custom,
          now: now,
          customFrom: DateTime.utc(2026, 10, 3),
        ),
        throwsArgumentError,
      );
    });

    test('from after to is rejected before any request', () {
      expect(
        () => AnalyticsPeriod.resolve(
          AnalyticsPreset.custom,
          now: now,
          customFrom: DateTime.utc(2026, 10, 9),
          customTo: DateTime.utc(2026, 10, 3),
        ),
        throwsArgumentError,
      );
    });

    test('366 days is the maximum; 367 is rejected', () {
      expect(AnalyticsPeriod.maxDays, 366);

      final AnalyticsPeriod ok = AnalyticsPeriod.resolve(
        AnalyticsPreset.custom,
        now: now,
        customFrom: DateTime.utc(2025, 1, 1),
        customTo: DateTime.utc(2026, 1, 1),
      );
      expect(ok.days, 366);

      expect(
        () => AnalyticsPeriod.resolve(
          AnalyticsPreset.custom,
          now: now,
          customFrom: DateTime.utc(2025, 1, 1),
          customTo: DateTime.utc(2026, 1, 2),
        ),
        throwsArgumentError,
      );
    });
  });

  group('query parameters and equality', () {
    test('always date_from + date_to, never `period`', () {
      for (final AnalyticsPreset preset in <AnalyticsPreset>[
        AnalyticsPreset.last7,
        AnalyticsPreset.last14,
        AnalyticsPreset.last30,
        AnalyticsPreset.last90,
        AnalyticsPreset.thisMonth,
        AnalyticsPreset.previousMonth,
      ]) {
        final Map<String, String> q = resolve(preset).queryParameters;
        expect(q.keys.toSet(), <String>{'date_from', 'date_to'},
            reason: preset.name);
      }
    });

    test('dates are formatted YYYY-MM-DD with zero padding', () {
      final Map<String, String> q = resolve(AnalyticsPreset.last7).queryParameters;

      expect(q['date_from'], '2026-10-08');
      expect(q['date_to'], '2026-10-14');
      expect(AnalyticsPeriod.formatDate(DateTime.utc(2026, 1, 5)), '2026-01-05');
    });

    test('equal periods are equal and hash the same', () {
      final AnalyticsPeriod a = resolve(AnalyticsPreset.last7);
      final AnalyticsPeriod b = resolve(AnalyticsPreset.last7);
      final AnalyticsPeriod c = resolve(AnalyticsPreset.last14);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
