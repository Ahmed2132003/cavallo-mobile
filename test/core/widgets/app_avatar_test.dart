import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_avatar.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('P-111 STEP 2: AppAvatar.initialsOf', () {
    test('two words, one word, blank, Arabic', () {
      expect(AppAvatar.initialsOf('Elegance Store'), 'ES');
      expect(AppAvatar.initialsOf('cavallo'), 'C');
      expect(AppAvatar.initialsOf('  one   two   three '), 'OT');
      expect(AppAvatar.initialsOf('   '), '');
      expect(AppAvatar.initialsOf(null), '');
      expect(
        AppAvatar.initialsOf(
          '\u0623\u062D\u0645\u062F \u0625\u0628\u0631\u0627\u0647\u064A\u0645',
        ).runes.length,
        2,
      );
    });
  });

  group('P-111 STEP 2: AppAvatar widget', () {
    testWidgets('shows initials, or a person icon when there is no name', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const AppAvatar(name: 'Elegance Store')));
      expect(find.text('ES'), findsOneWidget);

      await tester.pumpWidget(_wrap(const AppAvatar()));
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('no ring: size equals the photo size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const AppAvatar(name: 'A', size: 64)));
      expect(tester.getSize(find.byType(AppAvatar)), const Size(64, 64));
    });

    testWidgets('unseen ring: gradient ring drawn outside the photo', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AppAvatar(name: 'A', size: 64, ring: AppAvatarRing.unseen)),
      );
      const double expected =
          64 + 2 * (AppAvatar.ringWidth + AppAvatar.ringGap);
      expect(
        tester.getSize(find.byType(AppAvatar)),
        const Size(expected, expected),
      );

      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).gradient ==
                  AppColors.light.storyRing,
        ),
        findsOneWidget,
      );
    });

    testWidgets('seen ring: outline-coloured ring, same overall size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AppAvatar(name: 'A', size: 64, ring: AppAvatarRing.seen)),
      );
      const double expected =
          64 + 2 * (AppAvatar.ringWidth + AppAvatar.ringGap);
      expect(
        tester.getSize(find.byType(AppAvatar)),
        const Size(expected, expected),
      );

      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).border ==
                  Border.all(
                    color: AppColors.light.outline,
                    width: AppAvatar.ringWidth,
                  ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('onTap: callback fires and the tap target is at least 44', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(AppAvatar(name: 'A', size: 32, onTap: () => taps++)),
      );

      expect(
        tester.getSize(find.byType(AppAvatar)).shortestSide,
        greaterThanOrEqualTo(AppAvatar.minTapTarget),
      );
      await tester.tap(find.byType(AppAvatar));
      expect(taps, 1);
    });

    testWidgets('renders in the dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppAvatar(name: 'Dark', ring: AppAvatarRing.unseen),
          theme: AppTheme.dark,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('D'), findsOneWidget);
    });
  });
}
