# =====================================================================
# P-115 STEP 6A - Analytics charts themed from AppColors tokens
# Run from PowerShell (Windows PowerShell 5.1 or PowerShell 7).
# Repo: D:\Cavallo\social_commerce_app  (branch part-111)
#
# What it does:
#   REPLACE lib\features\business_console\presentation\analytics_line_chart.dart
#   EDIT    lib\features\business_console\presentation\analytics_screen.dart
#           (3 colour lines + 1 import + dash patterns; NO string changes)
#   CREATE  test\features\business_console\presentation\analytics_theme_test.dart
#   RUN     dart format on the touched files
#
# Rules kept: presentation only, no provider / data / string change.
# Strings stay as they are on purpose: the P-085 tests pump a bare
# MaterialApp (no localization delegates), so localizing this screen is
# STEP 8 (together with updating those test harnesses).
# Safe to run twice (guards) - backups in $env:TEMP\p115_step6a_backup.
# This file is ASCII only.
# =====================================================================
param(
  [string]$Repo = 'D:\Cavallo\social_commerce_app'
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path (Join-Path $Repo 'pubspec.yaml'))) {
  throw "pubspec.yaml not found in $Repo - pass -Repo with the right path."
}
Set-Location $Repo

$branch = (git branch --show-current).Trim()
Write-Host "Branch: $branch"
if ($branch -ne 'part-111') {
  throw "Expected branch part-111, found '$branch'. Run: git checkout part-111"
}

$chartRel  = 'lib\features\business_console\presentation\analytics_line_chart.dart'
$screenRel = 'lib\features\business_console\presentation\analytics_screen.dart'
$testRel   = 'test\features\business_console\presentation\analytics_theme_test.dart'
$chartPath  = Join-Path $Repo $chartRel
$screenPath = Join-Path $Repo $screenRel
$testPath   = Join-Path $Repo $testRel
foreach ($must in @($chartPath, $screenPath, (Join-Path $Repo 'lib\core\theme\app_colors.dart'))) {
  if (-not (Test-Path $must)) { throw "Missing prerequisite file: $must" }
}

$backup = Join-Path $env:TEMP 'p115_step6a_backup'
New-Item -ItemType Directory -Force -Path $backup | Out-Null
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-DartFile([string]$FullPath, [string]$Content) {
  $dir = Split-Path $FullPath -Parent
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  if (Test-Path $FullPath) {
    $bak = Join-Path $backup ((Split-Path $FullPath -Leaf) + '.bak')
    if (-not (Test-Path $bak)) { Copy-Item $FullPath $bak -Force }
  }
  $text = ($Content -replace "`r`n", "`n") -replace "`n", "`r`n"
  [System.IO.File]::WriteAllText($FullPath, $text, $utf8NoBom)
  Write-Host "  wrote $FullPath"
}

# ---------------------------------------------------------------------
# 1) The line chart: tokens for line, grid, labels, title, card border.
# ---------------------------------------------------------------------
$chart = @'
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/daily_stats_entity.dart';

/// Part P-085 scope: one single-metric line chart over the rows the
/// backend returned. P-093 generalises it so the same widget also draws the
/// average-rating trend.
///
/// * **No zero-fill (E3).** One point per returned row. The X position is
///   the real calendar offset from the first row, so a missing day shows
///   up as a visible gap in the line, not as a fabricated 0.
/// * **Y starts at 0.** By default the top follows the data and ticks are
///   whole numbers (counts). A caller can pin the top with [fixedMaxY] and
///   the tick spacing with [yInterval] (the rating trend uses 5 and 1).
/// * **Readable X axis.** At most ~5 date labels (`d/M`), whatever the
///   period, so 30 days never crowd.
/// * **A single row** is drawn as one visible dot.
///
/// Part P-115 (STEP 6A) restyle, presentation only:
/// * every colour comes from `context.appColors` (line = [color] or the
///   brand token, grid and card border = outline, labels = textSecondary,
///   title = textPrimary), so the chart is readable in Light and Dark;
/// * meaning never rides on colour alone: each chart has its own titled card
///   and a semantics summary, and [dashArray] gives a chart its own line
///   pattern (solid / dashed / dotted) on top of its colour.
///
/// [rows] must be sorted ascending by date (the data layer guarantees it).
class AnalyticsLineChart extends StatelessWidget {
  const AnalyticsLineChart({
    super.key,
    required this.title,
    required this.semanticsLabel,
    required this.rows,
    required this.valueOf,
    this.color,
    this.fixedMaxY,
    this.yInterval,
    this.dashArray,
  });

  /// Heading shown above the chart.
  final String title;

  /// Text summary read by screen readers instead of the drawing, e.g.
  /// "New followers: 14 total over 7 days".
  final String semanticsLabel;

  final List<DailyStats> rows;

  /// Picks the single metric this chart plots from a row (a count or a
  /// decimal such as a rating).
  final num Function(DailyStats row) valueOf;

  /// Line colour. Null = the brand token. Callers pass a token colour.
  final Color? color;

  /// Pins the top of the Y axis (e.g. 5 for a 1-5 star rating). When null
  /// the top is derived from the data.
  final double? fixedMaxY;

  /// Pins the Y tick spacing. Only used together with [fixedMaxY]; when
  /// null it defaults to 1.
  final double? yInterval;

  /// Line pattern (dash, gap, dash, gap...). Null = a solid line. Gives a
  /// chart a second visual identity besides its colour.
  final List<int>? dashArray;

  /// Whole days between the calendar dates of [a] and [b], DST-safe.
  static int dayOffset(DateTime a, DateTime b) {
    final first = DateTime.utc(a.year, a.month, a.day);
    final second = DateTime.utc(b.year, b.month, b.day);
    return second.difference(first).inDays;
  }

  /// The plotted points: X = day offset from the first row, Y = metric.
  static List<FlSpot> spotsFor(
    List<DailyStats> rows,
    num Function(DailyStats row) valueOf,
  ) {
    if (rows.isEmpty) return const [];
    final first = rows.first.date;
    return [
      for (final row in rows)
        FlSpot(dayOffset(first, row.date).toDouble(), valueOf(row).toDouble()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final lineColor = color ?? colors.brand;
    final spots = spotsFor(rows, valueOf);

    final span = spots.isEmpty ? 0.0 : spots.last.x;
    final maxX = span == 0 ? 1.0 : span;
    final xInterval = (span / 4).ceil().clamp(1, 1 << 20).toDouble();

    final pinnedMax = fixedMaxY;
    final maxValue = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);
    final double yStep;
    final double maxY;
    if (pinnedMax != null) {
      yStep = yInterval ?? 1.0;
      maxY = pinnedMax;
    } else {
      yStep = maxValue <= 4 ? 1.0 : (maxValue / 4).ceilToDouble();
      maxY = yStep * 4;
    }

    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.textSecondary,
    );

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Card(
          margin: EdgeInsets.zero,
          color: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.outline),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 4,
                    bottom: 12,
                  ),
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: maxX,
                      minY: 0,
                      maxY: maxY,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: yStep,
                        getDrawingHorizontalLine:
                            (value) =>
                                FlLine(color: colors.outline, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            interval: yStep,
                            getTitlesWidget:
                                (value, meta) => Text(
                                  value.round().toString(),
                                  style: labelStyle,
                                ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: xInterval,
                            getTitlesWidget: (value, meta) {
                              if (rows.isEmpty || value > span + 0.001) {
                                return const SizedBox.shrink();
                              }
                              final date = DateTime.utc(
                                rows.first.date.year,
                                rows.first.date.month,
                                rows.first.date.day,
                              ).add(Duration(days: value.round()));
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${date.day}/${date.month}',
                                  style: labelStyle,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: false,
                          barWidth: 3,
                          color: lineColor,
                          dashArray: dashArray,
                          dotData: FlDotData(show: spots.length <= 14),
                          belowBarData: BarAreaData(
                            show: true,
                            color: lineColor.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
'@
Write-DartFile $chartPath $chart

# ---------------------------------------------------------------------
# 2) The screen: token colours + line patterns. Exact one-line edits.
# ---------------------------------------------------------------------
$screen = [System.IO.File]::ReadAllText($screenPath)
if ($screen.Contains('appColors')) {
  Write-Host '  analytics_screen.dart already themed - skipped'
} else {
  $nl = if ($screen.Contains("`r`n")) { "`r`n" } else { "`n" }

  $impAnchor = "import '../../../core/network/api_failure.dart';"
  $tert = 'color: Theme.of(context).colorScheme.tertiary,'
  $sec  = 'color: Theme.of(context).colorScheme.secondary,'
  $icon = 'Icon(icon, size: 20, color: theme.colorScheme.primary),'
  foreach ($pair in @(@($impAnchor, 'import anchor'), @($tert, 'tertiary line'), @($sec, 'secondary line'), @($icon, 'card icon'))) {
    $c = ([regex]::Matches($screen, [regex]::Escape($pair[0]))).Count
    if ($c -ne 1) { throw "Expected exactly 1 '$($pair[1])' in analytics_screen.dart, found $c - stop and send me the file." }
  }

  $bakS = Join-Path $backup 'analytics_screen.dart.bak'
  if (-not (Test-Path $bakS)) { Copy-Item $screenPath $bakS -Force }

  $screen = $screen.Replace($impAnchor, $impAnchor + $nl + "import '../../../core/theme/app_colors.dart';")
  # Likes: amber text token, dashed. Rating: green text token, dotted.
  $screen = $screen.Replace($tert, 'color: context.appColors.warningText,' + $nl + '        dashArray: const [8, 4],')
  $screen = $screen.Replace($sec, 'color: context.appColors.successText,' + $nl + '          dashArray: const [2, 4],')
  $screen = $screen.Replace($icon, 'Icon(icon, size: 20, color: context.appColors.brandText),')

  [System.IO.File]::WriteAllText($screenPath, $screen, $utf8NoBom)
  Write-Host "  edited $screenRel"
}

# ---------------------------------------------------------------------
# 3) Test: tokens reach the chart, in both themes. ASCII only.
# ---------------------------------------------------------------------
$themeTest = @'
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
'@
Write-DartFile $testPath $themeTest

Write-Host ''
Write-Host 'Formatting touched Dart files ...'
dart format $chartPath $screenPath $testPath
if ($LASTEXITCODE -ne 0) { throw 'dart format failed' }

Write-Host ''
Write-Host 'git status:'
git status --short
Write-Host ''
Write-Host "DONE. Backups: $backup"
Write-Host 'Next: flutter analyze, then the analytics tests (see instructions).'