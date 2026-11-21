import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/orders/domain/order_formatters.dart';

void main() {
  group('OrderMoney.parseUnitPriceMinor', () {
    test('valid amounts become integer minor units', () {
      expect(OrderMoney.parseUnitPriceMinor('199.5'), 19950);
      expect(OrderMoney.parseUnitPriceMinor('199'), 19900);
      expect(OrderMoney.parseUnitPriceMinor('0.01'), 1);
      expect(OrderMoney.parseUnitPriceMinor(' 12 '), 1200);
      expect(
        OrderMoney.parseUnitPriceMinor('99999999.99'),
        OrderMoney.maxMinorUnits,
      );
    });

    test('Arabic digits and separators are normalized', () {
      expect(OrderMoney.parseUnitPriceMinor('١٢٫٥٠'), 1250);
      expect(OrderMoney.parseUnitPriceMinor('1,5'), 150);
    });

    test('invalid input is null', () {
      expect(OrderMoney.parseUnitPriceMinor(null), isNull);
      expect(OrderMoney.parseUnitPriceMinor(''), isNull);
      expect(OrderMoney.parseUnitPriceMinor('0'), isNull);
      expect(OrderMoney.parseUnitPriceMinor('0.00'), isNull);
      expect(OrderMoney.parseUnitPriceMinor('-5'), isNull);
      expect(OrderMoney.parseUnitPriceMinor('abc'), isNull);
      expect(OrderMoney.parseUnitPriceMinor('12.345'), isNull);
      expect(OrderMoney.parseUnitPriceMinor('123456789'), isNull);
      // "1,000" must be rejected, not misread as 1.00.
      expect(OrderMoney.parseUnitPriceMinor('1,000'), isNull);
    });
  });

  group('OrderMoney.parseQuantity', () {
    test('accepts 1..maxQuantity, including Arabic digits', () {
      expect(OrderMoney.parseQuantity('1'), 1);
      expect(OrderMoney.parseQuantity('100000'), OrderMoney.maxQuantity);
      expect(OrderMoney.parseQuantity('٣'), 3);
    });

    test('rejects everything else', () {
      expect(OrderMoney.parseQuantity(null), isNull);
      expect(OrderMoney.parseQuantity(''), isNull);
      expect(OrderMoney.parseQuantity('0'), isNull);
      expect(OrderMoney.parseQuantity('100001'), isNull);
      expect(OrderMoney.parseQuantity('1.5'), isNull);
      expect(OrderMoney.parseQuantity('1234567'), isNull);
    });
  });

  group('OrderMoney formatting', () {
    test('totalMinor multiplies in integers', () {
      expect(OrderMoney.totalMinor(3, 19950), 59850);
    });

    test('formatMinor', () {
      expect(OrderMoney.formatMinor(125000), '1250.00');
      expect(OrderMoney.formatMinor(125000, grouped: true), '1,250.00');
      expect(OrderMoney.formatMinor(5), '0.05');
      expect(OrderMoney.formatMinor(0), '0.00');
      expect(OrderMoney.formatMinor(-150), '-1.50');
      expect(OrderMoney.formatMinor(99999999, grouped: true), '999,999.99');
    });

    test('display groups thousands and pads/truncates to two decimals', () {
      expect(OrderMoney.display('1250.5'), '1,250.50');
      expect(OrderMoney.display('12'), '12.00');
      expect(OrderMoney.display('1234567.891'), '1,234,567.89');
      expect(OrderMoney.display(' 3.5 '), '3.50');
      expect(OrderMoney.display('abc'), 'abc');
    });

    test('withCurrency', () {
      expect(OrderMoney.withCurrency('1250', 'EGP'), '1,250.00 EGP');
      expect(OrderMoney.withCurrency('1250', ''), '1,250.00');
    });

    test('formatOrderDateTime uses a fixed, locale-free layout', () {
      expect(
        formatOrderDateTime(DateTime(2026, 11, 18, 14, 5)),
        '2026-11-18 14:05',
      );
    });
  });
}
