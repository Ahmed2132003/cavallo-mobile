/// Part BI-04: the ONE period shared by all five dashboard sections, and the
/// refresh signal.
///
/// * [analyticsPeriodProvider] holds the selected [AnalyticsPeriod]. Every
///   section provider watches it, so changing the filter re-requests every
///   section against the same window and nothing else does.
/// * [analyticsRefreshEpochProvider] is bumped by the Refresh button and by
///   pull-to-refresh. Every section provider watches it, so a bump re-runs
///   the sections that are on screen immediately; the others reload the next
///   time they are shown. Switching a Tab never changes either provider, so
///   it never causes a request.
///
/// "Now" comes from `analyticsNowProvider` (P-085) so tests can pin the clock.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analytics_period.dart';
import '../analytics_provider.dart' show analyticsNowProvider;

class AnalyticsPeriodNotifier extends Notifier<AnalyticsPeriod> {
  /// The default period of the dashboard.
  static const AnalyticsPreset defaultPreset = AnalyticsPreset.last30;

  @override
  AnalyticsPeriod build() => AnalyticsPeriod.resolve(
    defaultPreset,
    now: ref.read(analyticsNowProvider)(),
  );

  /// Selects any preset except custom (see [selectCustom]).
  void selectPreset(AnalyticsPreset preset) {
    if (preset == AnalyticsPreset.custom) {
      throw ArgumentError.value(
        preset,
        'preset',
        'use selectCustom(from, to) for a custom range.',
      );
    }
    state = AnalyticsPeriod.resolve(
      preset,
      now: ref.read(analyticsNowProvider)(),
    );
  }

  /// Custom range. Throws [ArgumentError] if from > to or the span is over
  /// 366 days (the UI validates first; this is the last line of defence).
  void selectCustom(DateTime from, DateTime to) {
    state = AnalyticsPeriod.resolve(
      AnalyticsPreset.custom,
      now: ref.read(analyticsNowProvider)(),
      customFrom: from,
      customTo: to,
    );
  }

  /// Recomputes a rolling / month preset against the current clock (so an app
  /// left open past midnight UTC moves its window). A custom range is kept.
  void reresolve() {
    final AnalyticsPeriod current = state;
    if (current.preset == AnalyticsPreset.custom) return;
    state = AnalyticsPeriod.resolve(
      current.preset,
      now: ref.read(analyticsNowProvider)(),
    );
  }
}

final analyticsPeriodProvider =
    NotifierProvider<AnalyticsPeriodNotifier, AnalyticsPeriod>(
      AnalyticsPeriodNotifier.new,
    );

class AnalyticsRefreshEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final analyticsRefreshEpochProvider =
    NotifierProvider<AnalyticsRefreshEpochNotifier, int>(
      AnalyticsRefreshEpochNotifier.new,
    );
