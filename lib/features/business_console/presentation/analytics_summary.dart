import '../domain/daily_stats_entity.dart';

/// Part P-085 scope: pure (Flutter-free) helpers that turn the rows the
/// backend returned into the numbers the Analytics screen shows.
///
/// Decision E3: these helpers only ever look at the rows they are given.
/// A day the backend returned no row for is NOT counted as a zero here -
/// the rollup may simply not have run for it, so a zero would be an
/// unconfirmed claim.
class AnalyticsTotals {
  const AnalyticsTotals({
    required this.newFollowers,
    required this.likesReceived,
    required this.commentsReceived,
    required this.storyViews,
  });

  /// Sum of `new_followers` over the returned rows.
  final int newFollowers;

  /// Sum of `total_likes_received` over the returned rows.
  final int likesReceived;

  /// Sum of `total_comments_received` over the returned rows.
  final int commentsReceived;

  /// Sum of `total_story_views` over the returned rows.
  final int storyViews;

  @override
  bool operator ==(Object other) =>
      other is AnalyticsTotals &&
      other.newFollowers == newFollowers &&
      other.likesReceived == likesReceived &&
      other.commentsReceived == commentsReceived &&
      other.storyViews == storyViews;

  @override
  int get hashCode =>
      Object.hash(newFollowers, likesReceived, commentsReceived, storyViews);

  @override
  String toString() =>
      'AnalyticsTotals(newFollowers: $newFollowers, likesReceived: '
      '$likesReceived, commentsReceived: $commentsReceived, '
      'storyViews: $storyViews)';
}

/// Sums the four tracked metrics across [rows]. An empty list sums to
/// all zeros (the screen shows its empty state instead of these).
AnalyticsTotals sumDailyStats(List<DailyStats> rows) {
  var newFollowers = 0;
  var likes = 0;
  var comments = 0;
  var storyViews = 0;
  for (final row in rows) {
    newFollowers += row.newFollowers;
    likes += row.totalLikesReceived;
    comments += row.totalCommentsReceived;
    storyViews += row.totalStoryViews;
  }
  return AnalyticsTotals(
    newFollowers: newFollowers,
    likesReceived: likes,
    commentsReceived: comments,
    storyViews: storyViews,
  );
}

/// How many distinct calendar days [rows] covers - the "X" in
/// "Days with data: X of N". Duplicated dates count once.
int daysWithData(List<DailyStats> rows) {
  final days = <(int, int, int)>{
    for (final row in rows) (row.date.year, row.date.month, row.date.day),
  };
  return days.length;
}

/// Part P-093: the rating numbers the Analytics screen shows.
///
/// * [newRatings] is the sum of `new_ratings_count` over the returned rows
///   (rows only, like every other total here).
/// * [latestAverage] is the most recent row's rating snapshot that is above
///   zero, or null when no returned row has one. The backend stores 0 for
///   "not rated yet" (a real average is never below 1), so 0 is never shown
///   as a rating.
class RatingSummary {
  const RatingSummary({
    required this.newRatings,
    required this.latestAverage,
    required this.latestAverageDate,
  });

  final int newRatings;
  final double? latestAverage;
  final DateTime? latestAverageDate;
}

/// Sums new ratings and finds the latest real rating snapshot in [rows].
/// Does not rely on [rows] being sorted.
RatingSummary summarizeRatings(List<DailyStats> rows) {
  var newRatings = 0;
  DailyStats? latestRated;
  for (final row in rows) {
    newRatings += row.newRatingsCount;
    if (row.averageRatingSnapshot > 0 &&
        (latestRated == null || row.date.isAfter(latestRated.date))) {
      latestRated = row;
    }
  }
  return RatingSummary(
    newRatings: newRatings,
    latestAverage: latestRated?.averageRatingSnapshot,
    latestAverageDate: latestRated?.date,
  );
}

/// The rows that carry a real rating snapshot (above zero), in their
/// original order. These are the only rows the rating trend plots: a 0
/// snapshot means "not rated yet", never a rating of zero.
List<DailyStats> ratedRows(List<DailyStats> rows) => [
  for (final row in rows)
    if (row.averageRatingSnapshot > 0) row,
];

/// Part P-093: the three catalog-size snapshots of one row, with the date
/// they were recorded for.
class CatalogSnapshot {
  const CatalogSnapshot({
    required this.asOf,
    required this.activeProducts,
    required this.publishedPosts,
    required this.publishedReels,
  });

  final DateTime asOf;
  final int activeProducts;
  final int publishedPosts;
  final int publishedReels;
}

/// The catalog snapshot of the most recent row in [rows], or null for an
/// empty list. These are totals as of the rollup run, so they are read from
/// ONE row (the latest) and never summed across days. Does not rely on
/// [rows] being sorted.
CatalogSnapshot? latestCatalogSnapshot(List<DailyStats> rows) {
  if (rows.isEmpty) return null;
  var latest = rows.first;
  for (final row in rows) {
    if (row.date.isAfter(latest.date)) latest = row;
  }
  return CatalogSnapshot(
    asOf: latest.date,
    activeProducts: latest.activeProductsCount,
    publishedPosts: latest.publishedPostsCount,
    publishedReels: latest.publishedReelsCount,
  );
}