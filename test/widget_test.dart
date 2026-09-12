import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_commerce_app/main.dart';

void main() {
  testWidgets('App boots at the splash route', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SocialCommerceApp()));
    await tester.pumpAndSettle();

    expect(find.text('Route: splash'), findsOneWidget);
  });
}
