import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/config/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/core/widgets/app_text_field.dart';
import 'package:social_commerce_app/core/widgets/empty_state_widget.dart';
import 'package:social_commerce_app/core/widgets/loading_indicator.dart';
import 'package:social_commerce_app/core/widgets/widget_gallery_demo.dart';

void main() {
  testWidgets(
    'renders all five shared widgets together under AppTheme without error',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.theme, home: const WidgetGalleryDemo()),
      );

      expect(find.byType(AppButton), findsOneWidget);
      expect(find.byType(AppTextField), findsOneWidget);
      expect(find.byType(LoadingIndicator), findsOneWidget);
      // The empty state is the default toggle position.
      expect(find.byType(EmptyStateWidget), findsOneWidget);

      // Toggle to the error state and confirm the screen swaps correctly.
      await tester.tap(find.text('Show error state'));
      await tester.pump();

      expect(find.text('Something went wrong.'), findsOneWidget);
    },
  );
}