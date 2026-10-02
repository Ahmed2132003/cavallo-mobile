import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_provider.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_screen.dart';

DailyStats _row(int day, int followers, int likes, int comments, int views) {
  return DailyStats(
    date: DateTime(2026, 9, day),
    newFollowers: followers,
    totalLikesReceived: likes,
    totalCommentsReceived: comments,
    totalStoryViews: views,
    newRatingsCount: 0,
    averageRatingSnapshot: 0.0,
    activeProductsCount: 0,
    publishedPostsCount: 0,
    publishedReelsCount: 0,
  );
}

// Known data: followers 1+2+3+4 = 10, likes 10+20+30+40 = 100,
// comments 1+1+2+2 = 6, story views 5+6+7+8 = 26.
final _rows = [
  _row(1, 1, 10, 1, 5),
  _row(2, 2, 20, 1, 6),
  _row(3, 3, 30, 2, 7),
  _row(4, 4, 40, 2, 8),
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
      'analytics-total-new-followers',
      'analytics-total-likes-received',
      'analytics-total-comments-received',
      'analytics-total-story-views',
      'analytics-days-with-data',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('shows exactly the four tracked metrics and nothing about '
      'products', (tester) async {
    await _pump(tester, (ref) async => _rows);
    await tester.pumpAndSettle();

    expect(find.text('New followers'), findsOneWidget);
    expect(find.text('Likes received'), findsOneWidget);
    expect(find.text('Comments received'), findsOneWidget);
    expect(find.text('Story views'), findsOneWidget);

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? t.textSpan?.toPlainText() ?? '').toLowerCase());
    for (final text in texts) {
      expect(text.contains('product'), isFalse, reason: text);
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
