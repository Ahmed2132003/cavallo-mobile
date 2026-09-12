import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/widgets/loading_indicator.dart';

void main() {
  testWidgets('renders a centered CircularProgressIndicator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LoadingIndicator())),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(Center),
      ),
      findsOneWidget,
    );
  });
}