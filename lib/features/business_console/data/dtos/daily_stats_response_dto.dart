/// Part P-085 scope: wire shape of ONE row of P-084's
/// `GET /api/v1/analytics/business/{id}/daily/` response
/// (`analytics.serializers.BusinessDailyStatsSerializer`), mirrored
/// literally:
///
/// ```json
/// {
///   "date": "2026-10-01",
///   "new_followers": 3,
///   "total_likes_received": 12,
///   "total_comments_received": 4,
///   "total_story_views": 27,
///   "new_ratings_count": 2,
///   "average_rating_snapshot": "4.50",
///   "active_products_count": 8,
///   "published_posts_count": 5,
///   "published_reels_count": 3
/// }
/// ```
///
/// ### Strict parsing, no defaults
///
/// The backend serializer always emits all ten fields (date plus nine
/// non-null metrics: eight `PositiveIntegerField`s and one `DecimalField`).
/// A missing or null field
/// therefore means a contract break, and silently substituting `0` would
/// fabricate a metric — exactly what P-085's Architecture Rule forbids.
/// So every field is required and a violation throws [FormatException];
/// the repository turns that into a visible failure instead of a chart.
///
/// ### average_rating_snapshot (P-093)
///
/// DRF serializes a `DecimalField` as a STRING by default (`"4.50"`), so
/// the value is parsed from that string; a plain JSON number is accepted
/// too. Anything else, a non-finite number, or a value outside 0..5 is a
/// contract break and throws [FormatException] (never a silent 0).
library;

import '../../domain/daily_stats_entity.dart';

class DailyStatsResponseDto {
  const DailyStatsResponseDto({
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

  factory DailyStatsResponseDto.fromJson(Map<String, dynamic> json) {
    return DailyStatsResponseDto(
      date: _requireString(json, 'date'),
      newFollowers: _requireInt(json, 'new_followers'),
      totalLikesReceived: _requireInt(json, 'total_likes_received'),
      totalCommentsReceived: _requireInt(json, 'total_comments_received'),
      totalStoryViews: _requireInt(json, 'total_story_views'),
      newRatingsCount: _requireInt(json, 'new_ratings_count'),
      averageRatingSnapshot: _requireRating(json, 'average_rating_snapshot'),
      activeProductsCount: _requireInt(json, 'active_products_count'),
      publishedPostsCount: _requireInt(json, 'published_posts_count'),
      publishedReelsCount: _requireInt(json, 'published_reels_count'),
    );
  }

  /// ISO `YYYY-MM-DD`, as sent by the backend.
  final String date;
  final int newFollowers;
  final int totalLikesReceived;
  final int totalCommentsReceived;
  final int totalStoryViews;
  final int newRatingsCount;
  final double averageRatingSnapshot;
  final int activeProductsCount;
  final int publishedPostsCount;
  final int publishedReelsCount;

  DailyStats toEntity() {
    return DailyStats(
      date: _parseDate(date),
      newFollowers: newFollowers,
      totalLikesReceived: totalLikesReceived,
      totalCommentsReceived: totalCommentsReceived,
      totalStoryViews: totalStoryViews,
      newRatingsCount: newRatingsCount,
      averageRatingSnapshot: averageRatingSnapshot,
      activeProductsCount: activeProductsCount,
      publishedPostsCount: publishedPostsCount,
      publishedReelsCount: publishedReelsCount,
    );
  }

  static final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Parses a strict `YYYY-MM-DD` into a UTC-midnight [DateTime] (no time
  /// zone shifting, no DST drift). Rejects anything else, including
  /// impossible calendar dates such as `2026-02-30`.
  static DateTime _parseDate(String raw) {
    final match = _datePattern.firstMatch(raw);
    if (match == null) {
      throw FormatException('Expected date as YYYY-MM-DD, got "$raw".');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw FormatException('Not a real calendar date: "$raw".');
    }
    return parsed;
  }

  static String _requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException(
      'Daily stats row: "$key" must be a string, got ${value.runtimeType}.',
    );
  }

  static int _requireInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw FormatException(
      'Daily stats row: "$key" must be an integer, got ${value.runtimeType}.',
    );
  }

  /// A rating average: a DRF decimal string ("4.50") or a JSON number,
  /// finite and within 0..5.
  static double _requireRating(Map<String, dynamic> json, String key) {
    final value = json[key];
    double? parsed;
    if (value is String) {
      parsed = double.tryParse(value);
    } else if (value is num) {
      parsed = value.toDouble();
    }
    if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 5) {
      throw FormatException(
        'Daily stats row: "$key" must be a decimal between 0 and 5, '
        'got ${value.runtimeType} $value.',
      );
    }
    return parsed;
  }
}
