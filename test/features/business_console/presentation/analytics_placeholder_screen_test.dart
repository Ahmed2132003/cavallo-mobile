import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/widgets/empty_state_widget.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_placeholder_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  // Deliberately NO ProviderScope: the placeholder must not depend on any
  // provider, so pumping it bare also proves that.
  await tester.pumpWidget(
    const MaterialApp(home: AnalyticsPlaceholderScreen()),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders the empty-state with the contract key and message', (
    tester,
  ) async {
    await _pump(tester);

    final placeholder = find.byKey(
      const ValueKey('business-analytics-placeholder'),
    );
    expect(placeholder, findsOneWidget);
    expect(tester.widget(placeholder), isA<EmptyStateWidget>());
    expect(find.text('Analytics coming soon'), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart), findsOneWidget);
  });

  testWidgets('has its own AppBar titled "Analytics"', (tester) async {
    await _pump(tester);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Analytics'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows no loading indicator and no action buttons', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  test('is const-constructible with no parameters (P-083 contract)', () {
    // Compile-time check: this declaration only compiles if
    // `AnalyticsPlaceholderScreen`'s constructor is `const`.
    //
    // NOT `identical(const A(), const A())`: `flutter test` runs with
    // widget-creation tracking, which gives every `const` widget call
    // site a hidden location argument, so two const instances created
    // at different lines are legitimately not identical.
    const screen = AnalyticsPlaceholderScreen();

    expect(screen, isA<Widget>());
    expect(screen.key, isNull);
  });
}
