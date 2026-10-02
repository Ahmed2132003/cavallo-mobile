import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_provider.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_screen.dart';

DailyStats _row(
  int day,
  int followers,
  int likes,
  int comments,
  int views, {
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

// Known data: followers 1+2+3+4 = 10, likes 10+20+30+40 = 100,
// comments 1+1+2+2 = 6, story views 5+6+7+8 = 26.
// P-093: new ratings 1+0+2+0 = 3; rating snapshots 4.0, 4.0, 4.5, 4.5
// (latest 4.50); catalog snapshots of the LATEST row: 4 active products,
// 5 posts, 2 reels (never summed across days).
final _rows = [
  _row(1, 1, 10, 1, 5, newRatings: 1, rating: 4.0, products: 3, posts: 2, reels: 1),
  _row(2, 2, 20, 1, 6, newRatings: 0, rating: 4.0, products: 3, posts: 3, reels: 1),
  _row(3, 3, 30, 2, 7, newRatings: 2, rating: 4.5, products: 4, posts: 3, reels: 2),
  _row(4, 4, 40, 2, 8, newRatings: 0, rating: 4.5, products: 4, posts: 5, reels: 2),
];

// Same days, but nothing has ever been rated (snapshot 0 = "not rated yet").
final _unratedRows = [
  _row(1, 1, 10, 1, 5, products: 1, posts: 1, reels: 1),
  _row(2, 2, 20, 1, 6, products: 2, posts: 2, reels: 1),
];

// The first day predates the first rating.
final _lateFirstRatingRows = [
  _row(1, 1, 10, 1, 5),
  _row(2, 2, 20, 1, 6, newRatings: 1, rating: 5.0),
  _row(3, 3, 30, 2, 7, rating: 5.0),
];

Future<void> _pump(
  WidgetTester tester,
  FutureOr<List<DailyStats>> Function(Ref ref) stats,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [analyticsStatsProvider.overrideWith(stats)],
      child: const MaterialApp(home: AnalyticsScreen()),
    ),
  );
}

void _expectTotal(String key, String value) {
  expect(
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(value)),
    findsOneWidget,
    reason: '$key should show $value',
  );
}

void main() {
  testWidgets('shows the loading state while the request is pending', (
    tester,
  ) async {
    final never = Completer<List<DailyStats>>();
    await _pump(tester, (ref) => never.future);
    await tester.pump();

    expect(find.byKey(const ValueKey('analytics-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('analytics-error')), findsNothing);
  });

  testWidgets('error state shows a message and Retry reloads the data', (
    tester,
  ) async {
    var calls = 0;
    await _pump(tester, (ref) async {
      calls++;
      if (calls == 1) throw Exception('boom');
      return _rows;
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('analytics-error')), findsOneWidget);
    expect(find.text('Could not load your analytics.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('analytics-retry-button')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(const ValueKey('analytics-error')), findsNothing);
    _expectTotal('analytics-total-new-followers', '10');
  });

  testWidgets('zero rows is an empty state, not a screen of zeros', (
    tester,
  ) async {
    await _pump(tester, (ref) async => <DailyStats>[]);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('analytics-empty')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('analytics-total-new-followers')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('analytics-chart-new-followers')),
      findsNothing,
    );
    for (final key in const [
      'analytics-chart-rating-trend',
      'analytics-rating-empty',
      'analytics-total-new-ratings',
      'analytics-catalog-active-products',
      'analytics-catalog-published-posts',
      'analytics-catalog-published-reels',
    ]) {
      expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
    }
  });

  testWidgets('data state: totals equal the sum of the mocked rows', (
    tester,
  ) async {
    await _pump(tester, (ref) async => _rows);
    await tester.pumpAndSettle();

    _expectTotal('analytics-total-new-followers', '10');
    _expectTotal('analytics-total-likes-received', '100');
    _expectTotal('analytics-total-comments-received', '6');
    _expectTotal('analytics-total-story-views', '26');

    // Default range is 7 days and 4 rows came back.
    expect(find.text('Days with data: 4 of 7'), findsOneWidget);
  });

  testWidgets('every contract key is present in the data state', (
    tester,
  ) async {
    await _pump(tester, (ref) async => _rows);
    await tester.pumpAndSettle();

    for (final key in const [
      'analytics-range-7',
      'analytics-range-14',
      'analytics-range-30',
      'analytics-chart-new-followers',
      'analytics-chart-total-likes',
      'analytics-chart-rating-trend',
      'analytics-total-new-followers',
      'analytics-total-likes-received',
      'analytics-total-comments-received',
      'analytics-total-story-views',
      'analytics-total-new-ratings',
      'analytics-rating-latest',
      'analytics-catalog-as-of',
      'analytics-catalog-active-products',
      'analytics-catalog-published-posts',
      'analytics-catalog-published-reels',
      'analytics-days-with-data',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('P-093: new ratings are the sum and the average rating is the '
      'latest snapshot', (tester) async {
    await _pump(tester, (ref) async => _rows);
    await tester.pumpAndSettle();

    _expectTotal('analytics-total-new-ratings', '3');
    _expectTotal('analytics-rating-latest', '4.50');
  });

  testWidgets('P-093: catalog counts show the LATEST row, not a sum', (
    tester,
  ) async {
    await _pump(tester, (ref) async => _rows);
    await tester.pumpAndSettle();

    _expectTotal('analytics-catalog-active-products', '4');
    _expectTotal('analytics-catalog-published-posts', '5');
    _expectTotal('analytics-catalog-published-reels', '2');
    expect(find.text('Active products'), findsOneWidget);
    expect(find.text('Published posts'), findsOneWidget);
    expect(find.text('Published reels'), findsOneWidget);
    expect(
      find.textContaining('As of 4/9 (UTC)'),
      findsOneWidget,
    );
  });

  testWidgets('P-093: the rating trend plots the stored snapshots', (
    tester,
  ) async {
    await _pump(tester, (ref) async => _rows);
    await tester.pumpAndSettle();

    final chartFinder = find.descendant(
      of: find.byKey(const ValueKey('analytics-chart-rating-trend')),
      matching: find.byType(LineChart),
    );
    final chart = tester.widget<LineChart>(chartFinder);
    expect(chart.data.lineBarsData.single.spots.map((s) => s.y), [
      4.0,
      4.0,
      4.5,
      4.5,
    ]);
    expect(chart.data.minY, 0);
    expect(chart.data.maxY, 5);
    expect(find.byKey(const ValueKey('analytics-rating-empty')), findsNothing);
  });

  testWidgets('P-093: never rated shows a note and a dash, not a zero rating '
      'or a flat line', (tester) async {
    await _pump(tester, (ref) async => _unratedRows);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('analytics-rating-empty')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('analytics-chart-rating-trend')),
      findsNothing,
    );
    _expectTotal('analytics-rating-latest', '\u2014');
    _expectTotal('analytics-total-new-ratings', '0');
    // The catalog snapshots are still real data and still shown.
    _expectTotal('analytics-catalog-active-products', '2');
  });

  testWidgets('P-093: days before the first rating are not plotted as 0', (
    tester,
  ) async {
    await _pump(tester, (ref) async => _lateFirstRatingRows);
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(
      find.descendant(
        of: find.byKey(const ValueKey('analytics-chart-rating-trend')),
        matching: find.byType(LineChart),
      ),
    );
    expect(chart.data.lineBarsData.single.spots.map((s) => s.y), [5.0, 5.0]);
    _expectTotal('analytics-rating-latest', '5.00');
  });

  testWidgets('shows only tracked metrics and no product-views or '
      'placeholder content', (tester) async {
    await _pump(tester, (ref) async => _rows);
    await tester.pumpAndSettle();

    for (final label in const [
      'New followers',
      'Likes received',
      'Comments received',
      'Story views',
      'New ratings',
      'Average rating',
      'Active products',
      'Published posts',
      'Published reels',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final label in const [
      'Product views',
      'Profile views',
      'Shares',
      'Saves',
      'Messages',
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? t.textSpan?.toPlainText() ?? '').toLowerCase());
    for (final text in texts) {
      expect(text.contains('product view'), isFalse, reason: text);
      expect(text.contains('productview'), isFalse, reason: text);
      expect(text.contains('placeholder'), isFalse, reason: text);
    }
  });

  testWidgets('tapping 14 days changes the range provider', (tester) async {
    await _pump(tester, (ref) async => _rows);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AnalyticsScreen)),
    );
    expect(container.read(analyticsRangeDaysProvider), 7);

    await tester.tap(find.byKey(const ValueKey('analytics-range-14')));
    await tester.pumpAndSettle();

    expect(container.read(analyticsRangeDaysProvider), 14);
    expect(find.text('Days with data: 4 of 14'), findsOneWidget);
  });
}