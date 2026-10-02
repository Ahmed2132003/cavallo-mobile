import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/data/dtos/daily_stats_response_dto.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';

/// Part P-085 scope. The JSON below is the literal row shape produced by
/// P-084's `BusinessDailyStatsSerializer` (fields: date, new_followers,
/// total_likes_received, total_comments_received, total_story_views,
/// new_ratings_count, average_rating_snapshot, active_products_count,
/// published_posts_count, published_reels_count).
void main() {
  Map<String, dynamic> row({
    Object? date = '2026-10-01',
    Object? newFollowers = 3,
    Object? likes = 12,
    Object? comments = 4,
    Object? storyViews = 27,
    Object? newRatings = 2,
    Object? averageRating = '4.50',
    Object? activeProducts = 8,
    Object? publishedPosts = 5,
    Object? publishedReels = 3,
  }) => {
    'date': date,
    'new_followers': newFollowers,
    'total_likes_received': likes,
    'total_comments_received': comments,
    'total_story_views': storyViews,
    'new_ratings_count': newRatings,
    'average_rating_snapshot': averageRating,
    'active_products_count': activeProducts,
    'published_posts_count': publishedPosts,
    'published_reels_count': publishedReels,
  };

  group('DailyStatsResponseDto.fromJson / toEntity', () {
    test('parses a full row and maps every field to the entity', () {
      final entity = DailyStatsResponseDto.fromJson(row()).toEntity();

      expect(
        entity,
        DailyStats(
          date: DateTime.utc(2026, 10, 1),
          newFollowers: 3,
          totalLikesReceived: 12,
          totalCommentsReceived: 4,
          totalStoryViews: 27,
          newRatingsCount: 2,
          averageRatingSnapshot: 4.5,
          activeProductsCount: 8,
          publishedPostsCount: 5,
          publishedReelsCount: 3,
        ),
      );
    });

    test('the date is a UTC midnight with no time component', () {
      final entity =
          DailyStatsResponseDto.fromJson(row(date: '2026-01-05')).toEntity();

      expect(entity.date.isUtc, isTrue);
      expect(entity.date, DateTime.utc(2026, 1, 5));
      expect(entity.date.hour, 0);
      expect(entity.date.minute, 0);
    });

    test('a genuine zero is parsed as 0 (a rolled-up quiet day)', () {
      final entity =
          DailyStatsResponseDto.fromJson(
            row(newFollowers: 0, likes: 0, comments: 0, storyViews: 0),
          ).toEntity();

      expect(entity.newFollowers, 0);
      expect(entity.totalLikesReceived, 0);
      expect(entity.totalCommentsReceived, 0);
      expect(entity.totalStoryViews, 0);
    });

    test('unknown extra keys are ignored, not surfaced', () {
      final json = row()..['product_views'] = 999;

      final entity = DailyStatsResponseDto.fromJson(json).toEntity();

      expect(entity.toString(), isNot(contains('999')));
      expect(entity.toString().toLowerCase(), isNot(contains('productview')));
    });

    for (final key in const [
      'date',
      'new_followers',
      'total_likes_received',
      'total_comments_received',
      'total_story_views',
      'new_ratings_count',
      'average_rating_snapshot',
      'active_products_count',
      'published_posts_count',
      'published_reels_count',
    ]) {
      test('missing "$key" throws FormatException (never defaults to 0)', () {
        final json = row()..remove(key);

        expect(
          () => DailyStatsResponseDto.fromJson(json),
          throwsFormatException,
        );
      });

      test('null "$key" throws FormatException', () {
        final json = row()..[key] = null;

        expect(
          () => DailyStatsResponseDto.fromJson(json),
          throwsFormatException,
        );
      });
    }

    test('the rating snapshot is parsed from the DRF decimal string', () {
      final entity =
          DailyStatsResponseDto.fromJson(
            row(averageRating: '4.25'),
          ).toEntity();
      final unrated =
          DailyStatsResponseDto.fromJson(
            row(averageRating: '0.00'),
          ).toEntity();

      expect(entity.averageRatingSnapshot, 4.25);
      expect(unrated.averageRatingSnapshot, 0.0);
    });

    test('the rating snapshot also accepts a plain JSON number', () {
      expect(
        DailyStatsResponseDto.fromJson(
          row(averageRating: 4.5),
        ).toEntity().averageRatingSnapshot,
        4.5,
      );
      expect(
        DailyStatsResponseDto.fromJson(
          row(averageRating: 4),
        ).toEntity().averageRatingSnapshot,
        4.0,
      );
    });

    test('an invalid rating snapshot throws FormatException', () {
      for (final bad in const <Object>['abc', 'NaN', '5.01', '-1.00', '', true]) {
        expect(
          () => DailyStatsResponseDto.fromJson(row(averageRating: bad)),
          throwsFormatException,
          reason: 'rating "$bad" must be rejected',
        );
      }
    });

    test('a P-093 count sent as a string throws FormatException', () {
      expect(
        () => DailyStatsResponseDto.fromJson(row(publishedPosts: '5')),
        throwsFormatException,
      );
      expect(
        () => DailyStatsResponseDto.fromJson(row(newRatings: '2')),
        throwsFormatException,
      );
    });

    test('a metric sent as a string throws FormatException', () {
      expect(
        () => DailyStatsResponseDto.fromJson(row(likes: '12')),
        throwsFormatException,
      );
    });

    test('a date that is not strict YYYY-MM-DD throws FormatException', () {
      for (final bad in const [
        '2026-10-01T00:00:00Z',
        '01/10/2026',
        '2026-1-1',
        '',
      ]) {
        expect(
          () => DailyStatsResponseDto.fromJson(row(date: bad)).toEntity(),
          throwsFormatException,
          reason: 'date "$bad" must be rejected',
        );
      }
    });

    test('an impossible calendar date throws FormatException', () {
      expect(
        () =>
            DailyStatsResponseDto.fromJson(row(date: '2026-02-30')).toEntity(),
        throwsFormatException,
      );
    });
  });
}
