import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_line_chart.dart';

/// Part P-115 (STEP 6A): the analytics chart takes its colours from the
/// AppColors tokens (readable in Light and Dark) and can carry a line
/// pattern, so meaning never depends on colour alone. The behaviour tests of
/// the chart stay in analytics_line_chart_test.dart (unchanged).

DailyStats _row(int day, int followers) {
  return DailyStats(
    date: DateTime(2026, 9, day),
    newFollowers: followers,
    totalLikesReceived: 0,
    totalCommentsReceived: 0,
    totalStoryViews: 0,
    newRatingsCount: 0,
    averageRatingSnapshot: 0,
    activeProductsCount: 0,
    publishedPostsCount: 0,
    publishedReelsCount: 0,
  );
}

Widget _host(ThemeData theme, {Color? color, List<int>? dashArray}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: AnalyticsLineChart(
          title: 'New followers by day',
          semanticsLabel: 'New followers: 6 total over 3 days',
          rows: [_row(1, 1), _row(2, 2), _row(3, 3)],
          valueOf: (row) => row.newFollowers,
          color: color,
          dashArray: dashArray,
        ),
      ),
    ),
  );
}

LineChartData _data(WidgetTester tester) {
  return tester.widget<LineChart>(find.byType(LineChart)).data;
}

void main() {
  testWidgets('default line is the brand token, grid is the outline token '
      '(light)', (tester) async {
    await tester.pumpWidget(_host(AppTheme.light));
    await tester.pumpAndSettle();

    final data = _data(tester);
    expect(data.lineBarsData.single.color, AppColors.light.brand);
    expect(
      data.gridData.getDrawingHorizontalLine(1).color,
      AppColors.light.outline,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark theme: the grid follows the dark outline token', (
    tester,
  ) async {
    await tester.pumpWidget(_host(AppTheme.dark));
    await tester.pumpAndSettle();

    final data = _data(tester);
    expect(data.lineBarsData.single.color, AppColors.dark.brand);
    expect(
      data.gridData.getDrawingHorizontalLine(1).color,
      AppColors.dark.outline,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a passed colour and dash pattern reach the line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AppTheme.dark,
        color: AppColors.dark.warningText,
        dashArray: const [8, 4],
      ),
    );
    await tester.pumpAndSettle();

    final bar = _data(tester).lineBarsData.single;
    expect(bar.color, AppColors.dark.warningText);
    expect(bar.dashArray, const [8, 4]);
  });

  testWidgets('no pattern given means a solid line', (tester) async {
    await tester.pumpWidget(_host(AppTheme.light));
    await tester.pumpAndSettle();

    expect(_data(tester).lineBarsData.single.dashArray, isNull);
  });
}
