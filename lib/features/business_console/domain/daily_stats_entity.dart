/// Part P-085 scope: one day of a Business account's engagement rollup —
/// the clean domain representation of a single `BusinessDailyStats` row
/// served by P-084's `GET /api/v1/analytics/business/{id}/daily/`.
///
/// ### The tracked metrics — by design
///
/// P-084 tracks followers, likes, comments and story views; P-093 adds new
/// ratings, an average-rating snapshot and three catalog-size snapshots.
/// Product views and profile views are NOT tracked anywhere in the system, so
/// there is deliberately no field for them here (Architecture Rule of
/// P-085). Do not add one without first building a real tracking
/// mechanism on the backend.
///
/// ### [date]
///
/// A calendar date with no time component, built as a UTC midnight
/// (`DateTime.utc(y, m, d)`) because the backend's rollup day is a UTC
/// calendar date. UTC midnights are used on purpose: day arithmetic on
/// them is exact, whereas local-midnight arithmetic can drift by an hour
/// across a DST change.
///
/// ### P-093 fields
///
/// * [newRatingsCount]: ratings first created that day (a customer
///   re-rating a business edits their row and is not counted again).
/// * [averageRatingSnapshot]: the business's average rating as of the
///   rollup run - a stored POINT-IN-TIME SNAPSHOT, not a live value. A
///   business with no ratings yet snapshots 0.0; the backend never
///   produces a real average below 1, so 0.0 means "not rated yet".
/// * [activeProductsCount], [publishedPostsCount], [publishedReelsCount]:
///   catalog totals as of the rollup run (snapshots, not daily deltas).
library;

class DailyStats {
  const DailyStats({
    required this.date,
    required this.newFollowers,
    required this.totalLikesReceived,
    required this.totalCommentsReceived,
    required this.totalStoryViews,
    required this.newRatingsCount,
    required this.averageRatingSnapshot,
    required this.activeProductsCount,
    required this.publishedPostsCount,
    required this.publishedReelsCount,
  });

  final DateTime date;
  final int newFollowers;
  final int totalLikesReceived;
  final int totalCommentsReceived;
  final int totalStoryViews;
  final int newRatingsCount;
  final double averageRatingSnapshot;
  final int activeProductsCount;
  final int publishedPostsCount;
  final int publishedReelsCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStats &&
          other.date == date &&
          other.newFollowers == newFollowers &&
          other.totalLikesReceived == totalLikesReceived &&
          other.totalCommentsReceived == totalCommentsReceived &&
          other.totalStoryViews == totalStoryViews &&
          other.newRatingsCount == newRatingsCount &&
          other.averageRatingSnapshot == averageRatingSnapshot &&
          other.activeProductsCount == activeProductsCount &&
          other.publishedPostsCount == publishedPostsCount &&
          other.publishedReelsCount == publishedReelsCount);

  @override
  int get hashCode => Object.hash(
    date,
    newFollowers,
    totalLikesReceived,
    totalCommentsReceived,
    totalStoryViews,
    newRatingsCount,
    averageRatingSnapshot,
    activeProductsCount,
    publishedPostsCount,
    publishedReelsCount,
  );

  @override
  String toString() =>
      'DailyStats(date: ${date.toIso8601String()}, '
      'newFollowers: $newFollowers, '
      'totalLikesReceived: $totalLikesReceived, '
      'totalCommentsReceived: $totalCommentsReceived, '
      'totalStoryViews: $totalStoryViews, '
      'newRatingsCount: $newRatingsCount, '
      'averageRatingSnapshot: $averageRatingSnapshot, '
      'activeProductsCount: $activeProductsCount, '
      'publishedPostsCount: $publishedPostsCount, '
      'publishedReelsCount: $publishedReelsCount)';
}