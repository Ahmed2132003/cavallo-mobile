import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/presentation/product_price_framing.dart';

/// Part P-034 scope. The price-framing copy (architecture Section 20) is
/// a real functional requirement, so these tests assert on the actual
/// rendered text in the widget tree — not on how it looks.
Future<void> _pump(
  WidgetTester tester, {
  required String price,
  required Currency currency,
  bool compact = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProductPriceFraming(
          price: price,
          currency: currency,
          compact: compact,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the headline and the mandatory framing note', (
    tester,
  ) async {
    await _pump(tester, price: '199.99', currency: Currency.egp);

    expect(find.text('Starting from 199.99 EGP'), findsOneWidget);
    expect(
      find.text(
        'Approximate price, negotiable directly with the business. '
        'Message the business to confirm.',
      ),
      findsOneWidget,
    );
    // Key words the requirement is about, asserted independently so a
    // future copy edit cannot silently drop them.
    expect(find.textContaining('Approximate'), findsOneWidget);
    expect(find.textContaining('negotiable'), findsOneWidget);
    expect(find.textContaining('Message the business'), findsOneWidget);
  });

  testWidgets('the compact variant carries exactly the same copy', (
    tester,
  ) async {
    await _pump(tester, price: '50.00', currency: Currency.sar, compact: true);

    expect(find.text('Starting from 50.00 SAR'), findsOneWidget);
    expect(find.text(ProductPriceCopy.note), findsOneWidget);
  });

  testWidgets('shows the right currency code for every supported currency', (
    tester,
  ) async {
    for (final currency in Currency.values) {
      await _pump(tester, price: '10.00', currency: currency);
      expect(
        find.text('Starting from 10.00 ${currency.toWire()}'),
        findsOneWidget,
        reason: 'currency ${currency.toWire()}',
      );
    }
  });

  testWidgets('contains no button, icon or input — text only', (tester) async {
    await _pump(tester, price: '199.99', currency: Currency.egp);

    // `find.bySubtype`, NOT `find.byType`: `byType` matches the exact
    // runtime type only, so `byType(ButtonStyleButton)` matches nothing
    // even when a FilledButton/ElevatedButton is present (this
    // assertion was vacuous before it was corrected).
    expect(find.bySubtype<ButtonStyleButton>(), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
