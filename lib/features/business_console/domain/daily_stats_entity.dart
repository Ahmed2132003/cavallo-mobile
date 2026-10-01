/// Part P-085 scope: one day of a Business account's engagement rollup —
/// the clean domain representation of a single `BusinessDailyStats` row
/// served by P-084's `GET /api/v1/analytics/business/{id}/daily/`.
///
/// ### Exactly four metrics — by design
///
/// P-084 only tracks followers, likes, comments and story views. Product
/// views and profile views are NOT tracked anywhere in the system, so
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
library;

class DailyStats {
  const DailyStats({
    required this.date,
    required this.newFollowers,
    required this.totalLikesReceived,
    required this.totalCommentsReceived,
    required this.totalStoryViews,
  });

  final DateTime date;
  final int newFollowers;
  final int totalLikesReceived;
  final int totalCommentsReceived;
  final int totalStoryViews;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStats &&
          other.date == date &&
          other.newFollowers == newFollowers &&
          other.totalLikesReceived == totalLikesReceived &&
          other.totalCommentsReceived == totalCommentsReceived &&
          other.totalStoryViews == totalStoryViews);

  @override
  int get hashCode => Object.hash(
    date,
    newFollowers,
    totalLikesReceived,
    totalCommentsReceived,
    totalStoryViews,
  );

  @override
  String toString() =>
      'DailyStats(date: ${date.toIso8601String()}, '
      'newFollowers: $newFollowers, '
      'totalLikesReceived: $totalLikesReceived, '
      'totalCommentsReceived: $totalCommentsReceived, '
      'totalStoryViews: $totalStoryViews)';
}