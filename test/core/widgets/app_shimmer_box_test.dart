import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('P-111 STEP 2: AppShimmerBox', () {
    testWidgets('takes the requested size (rectangle and circle)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AppShimmerBox(width: 100, height: 20, animate: false)),
      );
      expect(tester.getSize(find.byType(AppShimmerBox)), const Size(100, 20));

      await tester.pumpWidget(
        _wrap(const AppShimmerBox.circle(size: 48, animate: false)),
      );
      expect(tester.getSize(find.byType(AppShimmerBox)), const Size(48, 48));
    });

    testWidgets('animate: false settles (no repeating animation)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AppShimmerBox(width: 100, height: 20, animate: false)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion setting stops the animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder:
                (BuildContext context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: const Scaffold(
                    body: Center(child: AppShimmerBox(width: 100, height: 20)),
                  ),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('animated sweep runs in both themes without errors', (
      WidgetTester tester,
    ) async {
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light,
        AppTheme.dark,
      ]) {
        await tester.pumpWidget(
          _wrap(const AppShimmerBox(width: 100, height: 20), theme: theme),
        );
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
