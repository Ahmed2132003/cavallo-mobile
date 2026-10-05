import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_avatar.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/core/widgets/app_text_field.dart';
import 'package:social_commerce_app/core/widgets/empty_state_widget.dart';
import 'package:social_commerce_app/core/widgets/error_state_widget.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
import 'package:social_commerce_app/core/widgets/loading_indicator.dart';

void main() {
  final List<({String name, ThemeData theme, AppColors colors})> variants =
      <({String name, ThemeData theme, AppColors colors})>[
        (name: 'light', theme: AppTheme.light, colors: AppColors.light),
        (name: 'dark', theme: AppTheme.dark, colors: AppColors.dark),
      ];

  for (final v in variants) {
    testWidgets('P-111 STEP 2: core widgets render in ${v.name} theme', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: v.theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  AppButton(label: 'Go', onPressed: () {}),
                  AppTextField(label: 'Email', controller: controller),
                  const FeaturedBadge(),
                  const AppAvatar(name: 'Elegance Store'),
                  const EmptyStateWidget(
                    message: 'Nothing here',
                    icon: Icons.inbox_outlined,
                  ),
                  SizedBox(
                    height: 200,
                    child: ErrorStateWidget(message: 'Oops', onRetry: () {}),
                  ),
                  const SizedBox(height: 80, child: LoadingIndicator()),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Go'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Featured'), findsOneWidget);
      expect(find.text('ES'), findsOneWidget);
    });

    testWidgets('P-111 STEP 2: FeaturedBadge uses amber tokens in ${v.name}', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: v.theme,
          home: const Scaffold(body: Center(child: FeaturedBadge())),
        ),
      );

      final Container box = tester.widget<Container>(
        find.descendant(
          of: find.byType(FeaturedBadge),
          matching: find.byType(Container),
        ),
      );
      expect((box.decoration! as BoxDecoration).color, v.colors.featured);
      expect(
        tester.widget<Text>(find.text('Featured')).style?.color,
        v.colors.onFeatured,
      );
    });
  }

  testWidgets(
    'P-111 STEP 2: AppTextField takes its look from the theme (12 px)',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppTextField(label: 'Email', controller: controller),
          ),
        ),
      );

      final InputBorder? border =
          tester.widget<TextField>(find.byType(TextField)).decoration?.border;
      expect(border, isA<OutlineInputBorder>());
      expect(
        (border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(12),
      );
    },
  );
}
