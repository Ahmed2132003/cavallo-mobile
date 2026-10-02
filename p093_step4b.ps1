# p093_step4b.ps1  --  run from D:\Cavallo\social_commerce_app  (branch part-083)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path .\pubspec.yaml) -or -not (Test-Path .\lib\features\business_console\domain\daily_stats_entity.dart)) {
    throw 'Run this script from D:\Cavallo\social_commerce_app (pubspec.yaml / business_console not found).'
}
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'part-083') {
    throw "Current branch is '$branch' but the P-085 analytics code lives on 'part-083'. Run: git checkout part-083"
}
$entText = [IO.File]::ReadAllText((Join-Path (Get-Location).Path 'lib\features\business_console\domain\daily_stats_entity.dart'))
if (-not $entText.Contains('required this.newRatingsCount')) {
    throw 'STEP 3 is not applied (the entity has no P-093 fields). Apply p093_step3a.ps1 first.'
}

$utf8 = New-Object System.Text.UTF8Encoding($false)

function ConvertTo-Eol([string]$s, [string]$eol) {
    $lf = $s -replace "`r?`n", "`n"
    if ($eol -eq 'CRLF') { return $lf -replace "`n", "`r`n" }
    return $lf
}

# Replaces a WHOLE file with the content below. Refuses to run if the file
# has local uncommitted changes (so nothing of yours is overwritten).
function Write-WholeFile {
    param([string]$Path, [string]$Content)
    git diff --quiet -- $Path
    if ($LASTEXITCODE -ne 0) {
        throw "$Path has uncommitted local changes. Commit or stash them first."
    }
    $full = Join-Path (Get-Location).Path $Path
    [IO.File]::WriteAllText($full, (ConvertTo-Eol $Content 'CRLF'), $utf8)
    Write-Host "WROTE: $Path"
}

function Edit-File {
    param(
        [string]$Path,
        [string]$Old,
        [string]$New,
        [string]$SkipIfContains,
        [string]$Eol = 'CRLF'
    )
    $full = Join-Path (Get-Location).Path $Path
    $text = [IO.File]::ReadAllText($full)
    if ($text.Contains($SkipIfContains)) {
        Write-Host "SKIP (already applied): $Path  [$SkipIfContains]"
        return
    }
    $oldC = ConvertTo-Eol $Old $Eol
    $newC = ConvertTo-Eol $New $Eol
    $count = ([regex]::Matches($text, [regex]::Escape($oldC))).Count
    if ($count -ne 1) {
        throw "Anchor found $count time(s) (expected exactly 1) in $Path :: $($Old.Substring(0, [Math]::Min(70, $Old.Length)))"
    }
    $text = $text.Replace($oldC, $newC)
    [IO.File]::WriteAllText($full, $text, $utf8)
    Write-Host "EDITED: $Path"
}

Write-WholeFile -Path 'test\features\business_console\presentation\analytics_screen_test.dart' -Content @'
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
'@

Write-WholeFile -Path 'test\features\business_console\presentation\analytics_line_chart_test.dart' -Content @'
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_line_chart.dart';

DailyStats _row(DateTime date, int followers, {double rating = 0.0}) {
  return DailyStats(
    date: date,
    newFollowers: followers,
    totalLikesReceived: 0,
    totalCommentsReceived: 0,
    totalStoryViews: 0,
    newRatingsCount: 0,
    averageRatingSnapshot: rating,
    activeProductsCount: 0,
    publishedPostsCount: 0,
    publishedReelsCount: 0,
  );
}

Widget _host(List<DailyStats> rows) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: AnalyticsLineChart(
          title: 'New followers by day',
          semanticsLabel: 'New followers: 15 total over 7 days',
          rows: rows,
          valueOf: (row) => row.newFollowers,
        ),
      ),
    ),
  );
}

List<FlSpot> _spots(WidgetTester tester) {
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  return chart.data.lineBarsData.single.spots;
}

void main() {
  final increasing = [
    for (var i = 0; i < 7; i++) _row(DateTime(2026, 9, 1 + i), i + 1),
  ];

  testWidgets('one spot per row, rising trend, ascending X', (tester) async {
    await tester.pumpWidget(_host(increasing));
    await tester.pumpAndSettle();

    final spots = _spots(tester);
    expect(spots.length, increasing.length);
    expect(spots.last.y, greaterThan(spots.first.y));
    for (var i = 1; i < spots.length; i++) {
      expect(spots[i].x, greaterThan(spots[i - 1].x));
    }
  });

  testWidgets('a missing day is a gap, never a zero point', (tester) async {
    final gappy = [
      _row(DateTime(2026, 9, 1), 2),
      _row(DateTime(2026, 9, 4), 5),
    ];
    await tester.pumpWidget(_host(gappy));
    await tester.pumpAndSettle();

    final spots = _spots(tester);
    expect(spots.length, 2);
    expect(spots.map((s) => s.x), [0, 3]);
    expect(spots.map((s) => s.y), [2, 5]);
  });

  testWidgets('a single row renders one point and a 0-based Y axis', (
    tester,
  ) async {
    await tester.pumpWidget(_host([_row(DateTime(2026, 9, 1), 3)]));
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.spots.length, 1);
    expect(chart.data.minY, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('30 rows render without layout errors', (tester) async {
    final month = [
      for (var i = 0; i < 30; i++) _row(DateTime(2026, 8, 1 + i), i % 5),
    ];
    await tester.pumpWidget(_host(month));
    await tester.pumpAndSettle();

    expect(_spots(tester).length, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes a text summary to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(increasing));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('New followers: 15 total over 7 days'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('P-093: a decimal metric with a pinned 0-5 axis', (tester) async {
    final rated = [
      _row(DateTime(2026, 9, 1), 0, rating: 4.0),
      _row(DateTime(2026, 9, 2), 0, rating: 4.5),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnalyticsLineChart(
              title: 'Average rating by day',
              semanticsLabel: 'Average rating: latest 4.50 over 7 days',
              rows: rated,
              valueOf: (row) => row.averageRatingSnapshot,
              fixedMaxY: 5,
              yInterval: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.spots.map((s) => s.y), [4.0, 4.5]);
    expect(chart.data.minY, 0);
    expect(chart.data.maxY, 5);
    expect(chart.data.gridData.horizontalInterval, 1);
    expect(tester.takeException(), isNull);
  });

  test('spotsFor keeps decimal values', () {
    final spots = AnalyticsLineChart.spotsFor([
      _row(DateTime(2026, 9, 1), 0, rating: 3.25),
    ], (row) => row.averageRatingSnapshot);
    expect(spots.single.y, 3.25);
  });

  test('dayOffset ignores time of day', () {
    expect(
      AnalyticsLineChart.dayOffset(
        DateTime(2026, 9, 1, 23, 59),
        DateTime(2026, 9, 2, 0, 1),
      ),
      1,
    );
  });
}
'@

Write-WholeFile -Path 'test\features\business_console\presentation\analytics_summary_test.dart' -Content @'
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
'@

$int = 'test\features\business_console\analytics_integration_test.dart'

Edit-File -Path $int -SkipIfContains '''Published reels'',' -Old @'
  'Story views',
];

/// Metrics
'@ -New @'
  'Story views',
  'New ratings',
  'Average rating',
  'Active products',
  'Published posts',
  'Published reels',
];

/// Metrics
'@

Edit-File -Path $int -SkipIfContains 'only tracked metrics are labelled' -Old @'
    testWidgets('only the four tracked metrics are labelled, and nothing about '
        'products or placeholders exists inside the screen', (tester) async {
'@ -New @'
    testWidgets('only tracked metrics are labelled, and no product-views or '
        'placeholder content exists inside the screen', (tester) async {
'@

Edit-File -Path $int -SkipIfContains 'text.contains(''product view'')' -Old @'
        expect(text.contains('product'), isFalse, reason: 'text: "$text"');

'@ -New @'
        expect(
          text.contains('product view'),
          isFalse,
          reason: 'text: "$text"',
        );
        expect(text.contains('productview'), isFalse, reason: 'text: "$text"');

'@

Edit-File -Path $int -SkipIfContains 'text.contains(''product-view'')' -Old @'
                    return text.contains('product') ||
                        text.contains('placeholder');
'@ -New @'
                    return text.contains('productview') ||
                        text.contains('product-view') ||
                        text.contains('placeholder');
'@

Edit-File -Path $int -SkipIfContains '''analytics-total-new-ratings'': ''3'',' -Old @'
        expect(
          find.byKey(const Key('analytics-days-with-data')),
          findsOneWidget,
        );

'@ -New @'
        expect(
          find.byKey(const Key('analytics-days-with-data')),
          findsOneWidget,
        );

        // P-093 (knownTrendStats): new ratings 1+0+2 = 3, latest rating
        // snapshot 4.5, and the LATEST row's catalog snapshot (4 active
        // products, 3 posts, 2 reels).
        expect(
          find.byKey(const Key('analytics-chart-rating-trend')),
          findsOneWidget,
        );
        const expectedP093 = <String, String>{
          'analytics-total-new-ratings': '3',
          'analytics-rating-latest': '4.50',
          'analytics-catalog-active-products': '4',
          'analytics-catalog-published-posts': '3',
          'analytics-catalog-published-reels': '2',
        };
        for (final entry in expectedP093.entries) {
          expect(
            find.descendant(
              of: find.byKey(Key(entry.key)),
              matching: find.text(entry.value),
              matchRoot: true,
            ),
            findsOneWidget,
            reason: '${entry.key} should show ${entry.value}',
          );
        }

'@

Write-Host ''
Write-Host 'P-093 STEP4B script finished.'