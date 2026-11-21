/// Part BI-03 — money and date helpers shared by the Orders feature.
///
/// The backend sends and expects amounts as decimal STRINGS with at most two
/// decimals ("1250.00"). No decimal package is added, so every calculation
/// here is done in integer minor units (1250.00 -> 125000), which is exact.
abstract final class OrderMoney {
  /// Backend `MAX_ORDER_QUANTITY`.
  static const int maxQuantity = 100000;

  /// Backend unit price is `max_digits=10, decimal_places=2` -> 99,999,999.99.
  static const int maxMinorUnits = 9999999999;

  static final RegExp _priceInput = RegExp(r'^(\d{1,8})(?:\.(\d{1,2}))?$');
  static final RegExp _quantityInput = RegExp(r'^\d{1,6}$');
  static final RegExp _serverAmount = RegExp(r'^(\d+)(?:\.(\d+))?$');

  /// Arabic-Indic / Eastern Arabic digits -> ASCII, Arabic decimal separator
  /// and a single comma -> '.'. Anything else is left for the regex to reject
  /// (so "1,000" is rejected instead of being misread as 1.00).
  static String _normalize(String raw) {
    final StringBuffer out = StringBuffer();
    for (final int unit in raw.trim().runes) {
      if (unit >= 0x0660 && unit <= 0x0669) {
        out.writeCharCode(0x30 + (unit - 0x0660));
      } else if (unit >= 0x06F0 && unit <= 0x06F9) {
        out.writeCharCode(0x30 + (unit - 0x06F0));
      } else if (unit == 0x066B || unit == 0x002C) {
        out.write('.');
      } else {
        out.writeCharCode(unit);
      }
    }
    return out.toString();
  }

  /// "199.5" -> 19950. `null` when not a positive amount with at most two
  /// decimals and at most 8 integer digits.
  static int? parseUnitPriceMinor(String? raw) {
    if (raw == null) return null;
    final RegExpMatch? match = _priceInput.firstMatch(_normalize(raw));
    if (match == null) return null;
    final int whole = int.parse(match.group(1)!);
    final int fraction = int.parse((match.group(2) ?? '').padRight(2, '0'));
    final int minor = whole * 100 + fraction;
    return minor >= 1 ? minor : null;
  }

  /// A whole number in 1..[maxQuantity], or `null`.
  static int? parseQuantity(String? raw) {
    if (raw == null) return null;
    final String text = _normalize(raw);
    if (!_quantityInput.hasMatch(text)) return null;
    final int value = int.parse(text);
    return (value >= 1 && value <= maxQuantity) ? value : null;
  }

  static int totalMinor(int quantity, int unitPriceMinor) =>
      quantity * unitPriceMinor;

  /// 125000 -> "1250.00" (or "1,250.00" when [grouped]).
  static String formatMinor(int minor, {bool grouped = false}) {
    final bool negative = minor < 0;
    final int abs = minor.abs();
    final String whole = (abs ~/ 100).toString();
    final String fraction = (abs % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}${grouped ? _group(whole) : whole}.$fraction';
  }

  /// Server amount string -> display text ("1250.5" -> "1,250.50").
  /// Unparseable input is returned unchanged.
  static String display(String raw) {
    final RegExpMatch? match = _serverAmount.firstMatch(raw.trim());
    if (match == null) return raw;
    final String fraction = (match.group(2) ?? '').padRight(2, '0');
    return '${_group(match.group(1)!)}.${fraction.substring(0, 2)}';
  }

  /// "1,250.00 EGP" (just the amount when [currency] is empty).
  static String withCurrency(String amount, String currency) {
    final String text = display(amount);
    return currency.isEmpty ? text : '$text $currency';
  }

  static String _group(String digits) {
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}

/// "2026-11-18 14:05" in the device's local time (same manual convention as
/// the chat bubble's time label; no intl date symbols needed).
String formatOrderDateTime(DateTime value) {
  final DateTime local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
