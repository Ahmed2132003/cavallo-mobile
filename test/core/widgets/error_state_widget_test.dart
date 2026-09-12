import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/widgets/error_state_widget.dart';

void main() {
  testWidgets(
    'shows the message and fires onRetry when the retry button is tapped',
    (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget(
              message: 'Could not load products.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Could not load products.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retried, isTrue);
    },
  );
}