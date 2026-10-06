import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// Part P-112: the ONE place that turns numbers, times, dates and prices into
/// text for the user.
///
/// Rules (Phase 23 overview + P-112):
///  * Digits are ALWAYS Western (0-9), in Arabic and in English. Nothing here
///    ever produces Arabic-Indic digits, so changing the digit style later is
///    a change to this file only.
///  * Every word and every word order comes from the ARB files (so Arabic and
///    English can differ in grammar and ordering). This class only decides
///    WHICH message to use and passes it plain strings.
///  * No locale data of `package:intl` is needed, so it works the same in the
///    app, in widget tests and in plain unit tests.
///  * Time is injectable ([now]) so relative times are testable.
///
/// Screens create it with [AppFormatters.of] (reads the active language from
/// the widget tree) and never format a count, date or price by hand.
class AppFormatters {
  AppFormatters(this._l10n, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Formatters for the language the widget tree is currently showing.
  factory AppFormatters.of(BuildContext context, {DateTime Function()? now}) {
    return AppFormatters(AppLocalizations.of(context), now: now);
  }

  final AppLocalizations _l10n;
  final DateTime Function() _now;

  static const int _thousand = 1000;
  static const int _million = 1000000;
  static const int _billion = 1000000000;

  /// Relative time switches to an absolute date after this many days.
  static const int relativeDaysLimit = 7;

  static const List<String> _monthKeys = <String>[
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ];

  static const Set<String> _knownCurrencies = <String>{
    'egp',
    'sar',
    'aed',
    'jod',
  };

  // ---------------------------------------------------------------------
  // Counts
  // ---------------------------------------------------------------------

  /// Compact count for followers, likes, views: `950`, `1.2K`, `12.4K`,
  /// `3M`, `2.5B` (Arabic: `12.4` followed by the Arabic word for thousand,
  /// and so on).
  ///
  /// The value is TRUNCATED to one decimal, never rounded up, so `999999`
  /// reads `999.9K` and never the misleading `1000K`. A trailing `.0` is
  /// dropped (`12000` reads `12K`). Integer math only, so there is no
  /// floating-point drift.
  String compactCount(int count) {
    if (count < _thousand) {
      return count.toString();
    }
    if (count < _million) {
      return _l10n.compactThousands(_oneDecimal(count, _thousand));
    }
    if (count < _billion) {
      return _l10n.compactMillions(_oneDecimal(count, _million));
    }
    return _l10n.compactBillions(_oneDecimal(count, _billion));
  }

  /// `count / unit` truncated to one decimal, as plain Western-digit text.
  static String _oneDecimal(int count, int unit) {
    final int tenths = count ~/ (unit ~/ 10);
    final int whole = tenths ~/ 10;
    final int fraction = tenths % 10;
    return fraction == 0 ? '$whole' : '$whole.$fraction';
  }

  // ---------------------------------------------------------------------
  // Dates and times
  // ---------------------------------------------------------------------

  /// `just now`, `5 minutes ago`, `3 hours ago`, `2 days ago`; from
  /// [relativeDaysLimit] days on, the absolute date.
  ///
  /// A time in the future (small clock difference with the server) reads
  /// `just now`.
  String relativeTime(DateTime value) {
    final Duration age = _now().difference(value);
    if (age.inSeconds < 60) {
      return _l10n.relativeJustNow;
    }
    if (age.inMinutes < 60) {
      return _l10n.relativeMinutesAgo(age.inMinutes);
    }
    if (age.inHours < 24) {
      return _l10n.relativeHoursAgo(age.inHours);
    }
    if (age.inDays < relativeDaysLimit) {
      return _l10n.relativeDaysAgo(age.inDays);
    }
    return absoluteDate(value);
  }

  /// `October 5, 2026` in English, day first in Arabic, in the device's
  /// local time zone.
  String absoluteDate(DateTime date) {
    final DateTime local = date.toLocal();
    return _l10n.dateFull(
      '${local.day}',
      _l10n.monthName(_monthKeys[local.month - 1]),
      '${local.year}',
    );
  }

  /// 24-hour clock `15:07` (same in both languages), device local time.
  String time(DateTime value) {
    final DateTime local = value.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Date and time together, e.g. `October 5, 2026, 15:07`.
  String absoluteDateTime(DateTime value) {
    return _l10n.dateAndTime(absoluteDate(value), time(value));
  }

  // ---------------------------------------------------------------------
  // Prices
  // ---------------------------------------------------------------------

  /// Price for DISCOVERY display (never a checkout total): `1,234.50 EGP`,
  /// Arabic with the Arabic currency abbreviation.
  ///
  /// [amount] is the backend's raw decimal string (`"199.99"`); it is never
  /// parsed to a double, so no precision is lost. Thousands are grouped with
  /// a comma, an all-zero fraction is dropped (`"200.00"` reads `200`), and
  /// anything that is not a plain decimal is shown as it came. An unknown
  /// currency code is shown as given, upper case.
  String price(String amount, String currencyCode) {
    final String code = currencyCode.trim();
    final String lower = code.toLowerCase();
    final String currency = _knownCurrencies.contains(lower)
        ? _l10n.currencyLabel(lower)
        : code.toUpperCase();
    return _l10n.priceDisplay(_groupAmount(amount), currency);
  }

  static final RegExp _plainDecimal = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$');

  static String _groupAmount(String raw) {
    final String text = raw.trim();
    final RegExpMatch? match = _plainDecimal.firstMatch(text);
    if (match == null) {
      return text;
    }
    final String sign = match.group(1)!;
    final String integer = match.group(2)!;
    final String fraction = match.group(3) ?? '';

    final StringBuffer grouped = StringBuffer();
    for (int i = 0; i < integer.length; i++) {
      if (i > 0 && (integer.length - i) % 3 == 0) {
        grouped.write(',');
      }
      grouped.write(integer[i]);
    }

    final bool hasFraction = fraction.replaceAll('0', '').isNotEmpty;
    return hasFraction ? '$sign$grouped.$fraction' : '$sign$grouped';
  }
}
