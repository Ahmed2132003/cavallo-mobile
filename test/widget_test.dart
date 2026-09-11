import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_commerce_app/main.dart';

void main() {
  testWidgets('Placeholder screen shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SocialCommerceApp()));

    expect(find.text('Social Commerce Discovery Platform'), findsOneWidget);
  });
}
