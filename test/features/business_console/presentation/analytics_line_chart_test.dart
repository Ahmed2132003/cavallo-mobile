import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_line_chart.dart';

DailyStats _row(DateTime date, int followers) {
  return DailyStats(
    date: date,
    newFollowers: followers,
    totalLikesReceived: 0,
    totalCommentsReceived: 0,
    totalStoryViews: 0,
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
