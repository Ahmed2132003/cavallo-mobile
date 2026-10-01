import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_summary.dart';

DailyStats _row(
  int day, {
  int followers = 0,
  int likes = 0,
  int comments = 0,
  int views = 0,
}) {
  return DailyStats(
    date: DateTime(2026, 9, day),
    newFollowers: followers,
    totalLikesReceived: likes,
    totalCommentsReceived: comments,
    totalStoryViews: views,
  );
}

void main() {
  group('sumDailyStats', () {
    test('sums each of the four metrics independently', () {
      final totals = sumDailyStats([
        _row(1, followers: 1, likes: 10, comments: 2, views: 100),
        _row(2, followers: 2, likes: 20, comments: 3, views: 200),
        _row(3, followers: 4, likes: 30, comments: 5, views: 300),
      ]);

      expect(totals.newFollowers, 7);
      expect(totals.likesReceived, 60);
      expect(totals.commentsReceived, 10);
      expect(totals.storyViews, 600);
    });

    test('empty list sums to zeros', () {
      const zero = AnalyticsTotals(
        newFollowers: 0,
        likesReceived: 0,
        commentsReceived: 0,
        storyViews: 0,
      );
      expect(sumDailyStats(const []), zero);
    });

    test('a single row is returned as-is', () {
      final totals = sumDailyStats([
        _row(5, followers: 3, likes: 4, comments: 5, views: 6),
      ]);
      expect(totals.newFollowers, 3);
      expect(totals.likesReceived, 4);
      expect(totals.commentsReceived, 5);
      expect(totals.storyViews, 6);
    });
  });

  group('daysWithData', () {
    test('counts returned rows only — gaps are not filled', () {
      // Days 1, 2 and 6 returned; days 3-5 have no row.
      expect(daysWithData([_row(1), _row(2), _row(6)]), 3);
    });

    test('empty list is 0 and a single row is 1', () {
      expect(daysWithData(const []), 0);
      expect(daysWithData([_row(1)]), 1);
    });

    test('a duplicated date counts once', () {
      expect(daysWithData([_row(1), _row(1)]), 1);
    });
  });
}
