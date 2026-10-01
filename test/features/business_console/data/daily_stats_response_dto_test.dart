import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/data/dtos/daily_stats_response_dto.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';

/// Part P-085 scope. The JSON below is the literal row shape produced by
/// P-084's `BusinessDailyStatsSerializer` (fields: date, new_followers,
/// total_likes_received, total_comments_received, total_story_views).
void main() {
  Map<String, dynamic> row({
    Object? date = '2026-10-01',
    Object? newFollowers = 3,
    Object? likes = 12,
    Object? comments = 4,
    Object? storyViews = 27,
  }) => {
    'date': date,
    'new_followers': newFollowers,
    'total_likes_received': likes,
    'total_comments_received': comments,
    'total_story_views': storyViews,
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
      expect(entity.toString().toLowerCase(), isNot(contains('product')));
    });

    for (final key in const [
      'date',
      'new_followers',
      'total_likes_received',
      'total_comments_received',
      'total_story_views',
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
