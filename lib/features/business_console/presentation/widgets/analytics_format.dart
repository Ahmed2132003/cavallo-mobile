/// Part BI-04: display formatting shared by the dashboard widgets.
///
/// Rules:
/// * A missing value (null) is shown as [kAnalyticsDash], never as 0.
/// * Percentages only DISPLAY the backend's fraction (0.1523 -> 15.2%); no
///   rate is ever computed from counts here.
/// * Money stays a decimal string and goes through `AppFormatters.price`
///   (no float round trip). Digits are Western, as everywhere in the app.
library;

import 'package:flutter/widgets.dart';

import '../../../../core/l10n/formatters.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../domain/analytics_common.dart';

/// "Not available".
const String kAnalyticsDash = '\u2014';

const Set<String> _knownCurrencies = <String>{'egp', 'sar', 'aed', 'jod'};

/// Compact count, or a dash when the backend sent null.
String analyticsCount(AppFormatters formatters, int? value) {
  if (value == null) return kAnalyticsDash;
  return formatters.compactCount(value);
}

/// A backend fraction as a percentage with at most one decimal.
String analyticsPercent(double? fraction) {
  if (fraction == null) return kAnalyticsDash;
  return '${_trimmed(fraction * 100)}%';
}

/// A signed change (`+15%`, `-8%`, `0%`) from the backend's `change_pct`.
String analyticsSignedPercent(double fraction) {
  final double percent = fraction * 100;
  final String text = _trimmed(percent.abs());
  if (text == '0') return '0%';
  final String sign = percent > 0 ? '+' : '-';
  return '$sign$text%';
}

String _trimmed(double value) {
  final String fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

/// One text line per currency (sales are never summed across currencies).
/// [aov] true shows the average order value instead of the sales value.
/// An empty list (no sales) gives a single dash.
List<String> analyticsMoneyLines(
  AppFormatters formatters,
  List<SalesEntry> sales, {
  bool aov = false,
}) {
  if (sales.isEmpty) return const <String>[kAnalyticsDash];
  return <String>[
    for (final SalesEntry entry in sales)
      _moneyOrDash(
        formatters,
        aov ? entry.aov : entry.salesValue,
        entry.currency,
      ),
  ];
}

String _moneyOrDash(AppFormatters formatters, String? amount, String currency) {
  if (amount == null) return kAnalyticsDash;
  return formatters.price(amount, currency);
}

/// The localized currency name (`EGP` in English, the Arabic abbreviation in
/// Arabic); an unknown code is shown upper case as given.
String analyticsCurrencyName(BuildContext context, String code) {
  final String trimmed = code.trim();
  final String lower = trimmed.toLowerCase();
  if (_knownCurrencies.contains(lower)) {
    return context.l10n.currencyLabel(lower);
  }
  return trimmed.toUpperCase();
}

/// A validated money string as a number, for PLOTTING only (the DTO layer
/// already guarantees a plain decimal). Displayed amounts never use this.
double analyticsMoneyToDouble(String amount) => double.parse(amount);

/// `d/M` axis label of a UTC calendar date.
String analyticsDateLabel(DateTime date) => '${date.day}/${date.month}';
