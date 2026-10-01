import 'package:social_commerce_app/features/business_console/data/analytics_repository.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';

/// Part P-085 (Chat 3): shared hand-rolled fake for the router-level and
/// integration tests (no mockito/mocktail, same convention as the other
/// fakes in this project).
///
/// It sits at the network edge only: the real `AnalyticsScreen`, the real
/// `analyticsStatsProvider` and the real `businessProfileProvider` wiring
/// run above it. It returns exactly the rows it was given (no zero-fill,
/// like the real P-084 endpoint) and records every call so a test can
/// assert which business id and date range the provider asked for.
class FakeAnalyticsRepository implements AnalyticsRepository {
  FakeAnalyticsRepository({this.stats = const <DailyStats>[], this.error});

  /// Rows returned by [fetchDailyStats].
  final List<DailyStats> stats;

  /// When non-null, [fetchDailyStats] throws it instead of returning.
  final Object? error;

  final List<FakeAnalyticsCall> calls = <FakeAnalyticsCall>[];

  @override
  Future<List<DailyStats>> fetchDailyStats({
    required int businessId,
    required DateTime from,
    required DateTime to,
  }) async {
    calls.add(FakeAnalyticsCall(businessId: businessId, from: from, to: to));
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return stats;
  }
}

class FakeAnalyticsCall {
  const FakeAnalyticsCall({
    required this.businessId,
    required this.from,
    required this.to,
  });

  final int businessId;
  final DateTime from;
  final DateTime to;
}

/// Three consecutive days with a known increasing follower trend.
/// Totals: followers 6, likes 12, comments 3, story views 9.
List<DailyStats> knownTrendStats() => <DailyStats>[
  DailyStats(
    date: DateTime(2026, 9, 28),
    newFollowers: 1,
    totalLikesReceived: 2,
    totalCommentsReceived: 0,
    totalStoryViews: 1,
  ),
  DailyStats(
    date: DateTime(2026, 9, 29),
    newFollowers: 2,
    totalLikesReceived: 4,
    totalCommentsReceived: 1,
    totalStoryViews: 3,
  ),
  DailyStats(
    date: DateTime(2026, 9, 30),
    newFollowers: 3,
    totalLikesReceived: 6,
    totalCommentsReceived: 2,
    totalStoryViews: 5,
  ),
];
