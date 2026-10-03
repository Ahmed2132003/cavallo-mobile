import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_summary.dart';

DailyStats _row(
  int day, {
  int followers = 0,
  int likes = 0,
  int comments = 0,
  int views = 0,
  int newRatings = 0,
  double rating = 0.0,
  int products = 0,
  int posts = 0,
  int reels = 0,
}) {
  return DailyStats(
    date: DateTime(2026, 9, day),
    newFollowers: followers,
    totalLikesReceived: likes,
    totalCommentsReceived: comments,
    totalStoryViews: views,
    newRatingsCount: newRatings,
    averageRatingSnapshot: rating,
    activeProductsCount: products,
    publishedPostsCount: posts,
    publishedReelsCount: reels,
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
    test('counts returned rows only - gaps are not filled', () {
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

  group('summarizeRatings (P-093)', () {
    test('sums new ratings and takes the latest real snapshot', () {
      final summary = summarizeRatings([
        _row(1, newRatings: 1, rating: 4.0),
        _row(2, newRatings: 0, rating: 4.0),
        _row(3, newRatings: 2, rating: 4.5),
      ]);
      expect(summary.newRatings, 3);
      expect(summary.latestAverage, 4.5);
      expect(summary.latestAverageDate, DateTime(2026, 9, 3));
    });

    test('a snapshot of 0 (not rated yet) is never the latest average', () {
      final summary = summarizeRatings([
        _row(1, newRatings: 1, rating: 4.0),
        _row(2),
      ]);
      expect(summary.latestAverage, 4.0);
      expect(summary.latestAverageDate, DateTime(2026, 9, 1));
    });

    test('no rated row means no average, and empty means zero', () {
      final unrated = summarizeRatings([_row(1), _row(2)]);
      expect(unrated.latestAverage, isNull);
      expect(unrated.latestAverageDate, isNull);
      expect(unrated.newRatings, 0);
      expect(summarizeRatings(const []).latestAverage, isNull);
    });

    test('does not rely on the rows being sorted', () {
      final summary = summarizeRatings([
        _row(3, rating: 4.5),
        _row(1, rating: 4.0),
      ]);
      expect(summary.latestAverage, 4.5);
    });
  });

  group('ratedRows (P-093)', () {
    test('keeps only rows with a real snapshot, in order', () {
      final rows = [_row(1), _row(2, rating: 4.0), _row(3, rating: 4.5)];
      final rated = ratedRows(rows);
      expect(rated.map((r) => r.date.day), [2, 3]);
    });

    test('nothing rated gives an empty list', () {
      expect(ratedRows([_row(1), _row(2)]), isEmpty);
    });
  });

  group('latestCatalogSnapshot (P-093)', () {
    test('reads the latest row and never sums across days', () {
      final snapshot = latestCatalogSnapshot([
        _row(1, products: 3, posts: 2, reels: 1),
        _row(2, products: 4, posts: 5, reels: 2),
      ]);
      expect(snapshot, isNotNull);
      expect(snapshot!.asOf, DateTime(2026, 9, 2));
      expect(snapshot.activeProducts, 4);
      expect(snapshot.publishedPosts, 5);
      expect(snapshot.publishedReels, 2);
    });

    test('picks the latest date even when rows are unsorted', () {
      final snapshot = latestCatalogSnapshot([
        _row(5, products: 9),
        _row(1, products: 1),
      ]);
      expect(snapshot!.activeProducts, 9);
    });

    test('a genuine zero in the latest row is returned as 0', () {
      final snapshot = latestCatalogSnapshot([
        _row(1, products: 3),
        _row(2),
      ]);
      expect(snapshot!.activeProducts, 0);
    });

    test('no rows means no snapshot', () {
      expect(latestCatalogSnapshot(const []), isNull);
    });
  });
}