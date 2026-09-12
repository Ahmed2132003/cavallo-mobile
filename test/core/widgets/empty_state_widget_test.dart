import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/widgets/empty_state_widget.dart';

void main() {
  testWidgets('shows the message with no icon by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EmptyStateWidget(message: 'Nothing here yet.')),
      ),
    );

    expect(find.text('Nothing here yet.'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('shows the given icon when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            message: 'No products yet.',
            icon: Icons.inventory_2_outlined,
          ),
        ),
      ),
    );

    expect(find.text('No products yet.'), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });
}