/// Part BI-04: the ONE period shared by every Analytics dashboard section.
///
/// ### Rules (from api_contract_BI02.md)
/// * Dates are UTC calendar dates, inclusive on both ends.
/// * The backend accepts `period=` only for 7d/30d/90d, so the app ALWAYS
///   sends `date_from` + `date_to` (date_from wins on the server). One code
///   path for every preset, and every section (overview, products, content,
///   orders-summary) reads exactly the same window.
/// * `orders-summary` defaults `date_to` to the server's local "today", so an
///   explicit `date_to` is mandatory; sending it everywhere keeps all
///   sections aligned.
/// * Maximum range is 366 days; `from > to` is a 400 on the server, so it is
///   rejected here before any request.
///
/// ### Which day is "the last day"
/// Rolling presets (7/14/30/90) end YESTERDAY (UTC). Today has no rollup yet:
/// ending on today would make `views_complete` false (conversion and
/// previous-period would always be null). "This month" runs from the 1st
/// to yesterday (on the 1st itself it is just that day). "Previous month" is
/// the whole previous calendar month.
///
/// ### Egypt (UTC+2/+3)
/// The backend counts days in UTC. Between 00:00 and 02:00/03:00 in Cairo the
/// UTC date is still the previous day. All "today" maths below uses the UTC
/// date of the injected clock, never the device's local date. A custom range
/// picked on the device is taken as the picked year/month/day, read as UTC
/// dates (no hour shifting).
library;

import 'package:flutter/foundation.dart' show immutable;

enum AnalyticsPreset {
  last7,
  last14,
  last30,
  last90,
  thisMonth,
  previousMonth,
  custom;

  /// Number of days for the rolling presets, null for the others.
  int? get rollingDays => switch (this) {
    AnalyticsPreset.last7 => 7,
    AnalyticsPreset.last14 => 14,
    AnalyticsPreset.last30 => 30,
    AnalyticsPreset.last90 => 90,
    AnalyticsPreset.thisMonth => null,
    AnalyticsPreset.previousMonth => null,
    AnalyticsPreset.custom => null,
  };
}

@immutable
class AnalyticsPeriod {
  const AnalyticsPeriod._(this.preset, this.from, this.to);

  /// Maximum span the backend accepts.
  static const int maxDays = 366;

  final AnalyticsPreset preset;

  /// First day, UTC midnight.
  final DateTime from;

  /// Last day (inclusive), UTC midnight.
  final DateTime to;

  /// Number of calendar days, both ends included.
  int get days => to.difference(from).inDays + 1;

  /// Builds the period of [preset] as seen from [now].
  ///
  /// For [AnalyticsPreset.custom], [customFrom] and [customTo] are required
  /// and only their year/month/day are used.
  factory AnalyticsPeriod.resolve(
    AnalyticsPreset preset, {
    required DateTime now,
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    final DateTime nowUtc = now.toUtc();
    final DateTime today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final DateTime yesterday = DateTime.utc(
      today.year,
      today.month,
      today.day - 1,
    );

    final int? rolling = preset.rollingDays;
    if (rolling != null) {
      return AnalyticsPeriod._validated(
        preset,
        DateTime.utc(
          yesterday.year,
          yesterday.month,
          yesterday.day - (rolling - 1),
        ),
        yesterday,
      );
    }

    switch (preset) {
      case AnalyticsPreset.thisMonth:
        final DateTime first = DateTime.utc(today.year, today.month, 1);
        final DateTime end = yesterday.isBefore(first) ? first : yesterday;
        return AnalyticsPeriod._validated(preset, first, end);
      case AnalyticsPreset.previousMonth:
        return AnalyticsPeriod._validated(
          preset,
          DateTime.utc(today.year, today.month - 1, 1),
          DateTime.utc(today.year, today.month, 0),
        );
      case AnalyticsPreset.custom:
        if (customFrom == null || customTo == null) {
          throw ArgumentError('A custom period needs customFrom and customTo.');
        }
        return AnalyticsPeriod._validated(
          preset,
          DateTime.utc(customFrom.year, customFrom.month, customFrom.day),
          DateTime.utc(customTo.year, customTo.month, customTo.day),
        );
      case AnalyticsPreset.last7:
      case AnalyticsPreset.last14:
      case AnalyticsPreset.last30:
      case AnalyticsPreset.last90:
        throw StateError('Rolling presets are handled above.');
    }
  }

  factory AnalyticsPeriod._validated(
    AnalyticsPreset preset,
    DateTime from,
    DateTime to,
  ) {
    if (from.isAfter(to)) {
      throw ArgumentError.value(from, 'from', 'must be on or before $to.');
    }
    final AnalyticsPeriod period = AnalyticsPeriod._(preset, from, to);
    if (period.days > maxDays) {
      throw ArgumentError.value(
        period.days,
        'days',
        'must be at most $maxDays.',
      );
    }
    return period;
  }

  /// `YYYY-MM-DD` of a date's own year/month/day.
  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The query parameters every analytics endpoint of the dashboard takes.
  Map<String, String> get queryParameters => <String, String>{
    'date_from': formatDate(from),
    'date_to': formatDate(to),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalyticsPeriod &&
          other.preset == preset &&
          other.from == from &&
          other.to == to);

  @override
  int get hashCode => Object.hash(preset, from, to);

  @override
  String toString() =>
      'AnalyticsPeriod(${preset.name}, ${formatDate(from)}..${formatDate(to)})';
}
