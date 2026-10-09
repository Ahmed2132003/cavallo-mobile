/// Part P-085 scope: Riverpod wiring for the Business Analytics screen.
///
/// * `analyticsRepositoryProvider` — declared next to the repository in
///   `data/analytics_repository.dart` (same layout as every other feature).
/// * [analyticsRangeDaysProvider] — the selected period, 7 / 14 / 30 days,
///   default 7.
/// * [analyticsStatsProvider] — the rows for the current Business's own
///   analytics over that period.
///
/// ### What [analyticsStatsProvider] guarantees
///
/// * The business id comes from `businessProfileProvider` (P-028A), never
///   guessed. No profile, or a failed profile load, is an ERROR — not an
///   empty list that the UI could render as "no activity".
/// * The period ends today and starts `days - 1` days earlier, both as
///   UTC calendar dates, because the backend's rollup `date` is a UTC
///   date. Using the device's local date instead would make the last day
///   wrong for a few hours around midnight in non-UTC zones (e.g. Egypt).
/// * Rows are returned ordered oldest -> newest. There is NO zero-filling:
///   a day without a backend row is simply absent, because "no row" means
///   "no rollup recorded", which is not the same thing as "zero activity".
/// * Nothing is derived beyond what the API returned.
///
/// Retry from the UI is `ref.invalidate(analyticsStatsProvider)`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business_profile/presentation/business_profile_provider.dart';
import '../data/analytics_repository.dart';
import '../domain/daily_stats_entity.dart';

/// Thrown by [analyticsStatsProvider] when the signed-in account has no
/// Business profile to read analytics for.
class AnalyticsBusinessUnavailableException implements Exception {
  const AnalyticsBusinessUnavailableException();

  static const message =
      'No business profile found for this account, so there are no '
      'analytics to show.';

  @override
  String toString() => 'AnalyticsBusinessUnavailableException: $message';
}

/// Holds the selected analytics period in days.
class AnalyticsRangeNotifier extends Notifier<int> {
  static const supportedDays = <int>[7, 14, 30];
  static const defaultDays = 7;

  @override
  int build() => defaultDays;

  /// Selects a period. Only 7, 14 and 30 are valid; anything else is a
  /// programming error and throws [ArgumentError].
  void select(int days) {
    if (!supportedDays.contains(days)) {
      throw ArgumentError.value(days, 'days', 'must be one of $supportedDays.');
    }
    state = days;
  }
}

final analyticsRangeDaysProvider =
    NotifierProvider<AnalyticsRangeNotifier, int>(AnalyticsRangeNotifier.new);

/// The clock used to decide "today". A provider only so tests can pin it;
/// production always uses [DateTime.now].
final analyticsNowProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// `retry: null` — Riverpod 3 otherwise silently re-runs a failed provider
/// up to 10 times with backoff (for any non-`Error` throwable, which
/// includes `ApiFailure` and [AnalyticsBusinessUnavailableException]),
/// keeping the screen in "loading" for minutes instead of showing the
/// error + Retry button. Same opt-out as `story_public_provider.dart` and
/// `moderation_provider.dart`; retrying is the user's explicit action.
final analyticsStatsProvider = FutureProvider.autoDispose<List<DailyStats>>((
  ref,
) async {
  final days = ref.watch(analyticsRangeDaysProvider);
  final profile = await ref.watch(businessProfileProvider.future);
  if (profile == null) {
    throw const AnalyticsBusinessUnavailableException();
  }

  final nowUtc = ref.read(analyticsNowProvider)().toUtc();
  final to = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
  final from = to.subtract(Duration(days: days - 1));

  final rows = await ref
      .watch(analyticsRepositoryProvider)
      .fetchDailyStats(businessId: profile.id, from: from, to: to);

  final sorted = List<DailyStats>.of(rows)
    ..sort((a, b) => a.date.compareTo(b.date));
  return sorted;
}, retry: (retryCount, error) => null);
