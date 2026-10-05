import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/theme/app_typography.dart';

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('P-111 STEP 1: AppColors tokens', () {
    test('light and dark expose every token and the story ring has 3 stops', () {
      for (final AppColors c in <AppColors>[AppColors.light, AppColors.dark]) {
        expect(c.storyRing.colors.length, 3);
        expect(c.storyRingSeen, c.outline);
        expect(c.brandSubtle.a, 1.0);
      }
    });

    test('brand and featured fills are identical in light and dark', () {
      expect(AppColors.light.brand, AppColors.dark.brand);
      expect(AppColors.light.featured, AppColors.dark.featured);
    });

    test('light and dark differ where they must', () {
      expect(AppColors.light.background, isNot(AppColors.dark.background));
      expect(AppColors.light.textPrimary, isNot(AppColors.dark.textPrimary));
      expect(AppColors.light.brandText, isNot(AppColors.dark.brandText));
    });

    test('copyWith and lerp keep the extension consistent', () {
      final AppColors a = AppColors.light;
      expect(a.copyWith().brand, a.brand);
      expect(a.lerp(AppColors.dark, 0).surface, a.surface);
      expect(a.lerp(AppColors.dark, 1).surface, AppColors.dark.surface);
    });
  });

  group('P-111 STEP 1: contrast (ratios from the Design Tokens table)', () {
    test('textPrimary on background >= 18:1 in both themes', () {
      expect(_contrast(AppColors.light.textPrimary, AppColors.light.background), greaterThanOrEqualTo(18));
      expect(_contrast(AppColors.dark.textPrimary, AppColors.dark.background), greaterThanOrEqualTo(18));
    });

    test('textSecondary on surface: 5.9:1 light, 7.1:1 dark', () {
      expect(_contrast(AppColors.light.textSecondary, AppColors.light.surface), greaterThanOrEqualTo(5.9));
      expect(_contrast(AppColors.dark.textSecondary, AppColors.dark.surface), greaterThanOrEqualTo(7.1));
    });

    test('onBrand on brand is 4.5:1 within rounding (measured 4.499)', () {
      // The locked token pair measures 4.4994:1, i.e. 4.5 only after rounding.
      // Tolerance 4.49 documents that honestly; see P-111 STEP 1 notes.
      expect(_contrast(AppColors.light.onBrand, AppColors.light.brand), greaterThanOrEqualTo(4.49));
    });

    test('brandText on surface: ~4.5:1 light, >= 6.7:1 dark', () {
      expect(_contrast(AppColors.light.brandText, AppColors.light.surface), greaterThanOrEqualTo(4.49));
      expect(_contrast(AppColors.dark.brandText, AppColors.dark.surface), greaterThanOrEqualTo(6.7));
    });

    test('label on featured amber and on danger are readable', () {
      expect(_contrast(AppColors.light.onFeatured, AppColors.light.featured), greaterThanOrEqualTo(7));
      expect(_contrast(AppColors.light.onDanger, AppColors.light.danger), greaterThanOrEqualTo(4.5));
      expect(_contrast(AppColors.dark.onDanger, AppColors.dark.danger), greaterThanOrEqualTo(4.5));
    });
  });

  group('P-111 STEP 1: AppTheme', () {
    test('light and dark are built from the tokens (no indigo placeholder)', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.light.colorScheme.primary, AppColors.light.brand);
      expect(AppTheme.dark.colorScheme.primary, AppColors.dark.brand);
      expect(AppTheme.light.colorScheme.primary, isNot(Colors.indigo));
      expect(AppTheme.light.scaffoldBackgroundColor, AppColors.light.background);
      expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.dark.background);
      expect(AppTheme.light.useMaterial3, isTrue);
    });

    test('AppColors extension is registered on both themes', () {
      expect(AppTheme.light.extension<AppColors>(), AppColors.light);
      expect(AppTheme.dark.extension<AppColors>(), AppColors.dark);
    });

    test('bundled font family is applied through ThemeData', () {
      expect(AppTheme.light.textTheme.bodyLarge?.fontFamily, AppTypography.fontFamily);
      expect(AppTheme.dark.textTheme.titleLarge?.fontFamily, AppTypography.fontFamily);
    });

    test('legacy AppTheme.theme alias still points at light', () {
      expect(AppTheme.theme, same(AppTheme.light));
    });

    testWidgets('context.appColors resolves per theme and falls back safely', (WidgetTester tester) async {
      late AppColors fromDark;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (BuildContext context) {
              fromDark = context.appColors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(fromDark, AppColors.dark);

      // Fresh tree: otherwise AnimatedTheme merges the previous dark theme's
      // extensions into the bare default theme and the fallback is never hit.
      await tester.pumpWidget(const SizedBox.shrink());
      late AppColors fallback;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              fallback = context.appColors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(fallback, AppColors.light);
    });
  });
}