import '../domain/daily_stats_entity.dart';

/// Part P-085 scope: pure (Flutter-free) helpers that turn the rows the
/// backend returned into the numbers the Analytics screen shows.
///
/// Decision E3: these helpers only ever look at the rows they are given.
/// A day the backend returned no row for is NOT counted as a zero here —
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

/// How many distinct calendar days [rows] covers — the "X" in
/// "Days with data: X of N". Duplicated dates count once.
int daysWithData(List<DailyStats> rows) {
  final days = <(int, int, int)>{
    for (final row in rows) (row.date.year, row.date.month, row.date.day),
  };
  return days.length;
}
