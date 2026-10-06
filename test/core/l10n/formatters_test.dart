import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/l10n/formatters.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-112 STEP 5: AppFormatters in both languages.
///
/// ASCII only on purpose: every Arabic text below is a \uXXXX escape.
final DateTime _now = DateTime(2026, 10, 5, 12, 0, 0);

void main() {
  late AppFormatters en;
  late AppFormatters ar;

  setUpAll(() async {
    en = AppFormatters(
      await AppLocalizations.delegate.load(const Locale('en')),
      now: () => _now,
    );
    ar = AppFormatters(
      await AppLocalizations.delegate.load(const Locale('ar')),
      now: () => _now,
    );
  });

  final RegExp arabicIndic = RegExp('[\u0660-\u0669\u06F0-\u06F9]');

  // Arabic words used below.
  const String thousand = '\u0623\u0644\u0641';
  const String million = '\u0645\u0644\u064a\u0648\u0646';
  const String billion = '\u0645\u0644\u064a\u0627\u0631';
  const String since = '\u0645\u0646\u0630';

  group('compactCount', () {
    test('below one thousand is the plain number', () {
      for (final int n in <int>[0, 1, 9, 950, 999]) {
        expect(en.compactCount(n), '$n');
        expect(ar.compactCount(n), '$n');
      }
    });

    test('thousands: one decimal, truncated, trailing .0 dropped', () {
      expect(en.compactCount(1000), '1K');
      expect(en.compactCount(1234), '1.2K');
      expect(en.compactCount(12000), '12K');
      expect(en.compactCount(12400), '12.4K');
      expect(en.compactCount(99999), '99.9K');
      expect(en.compactCount(999999), '999.9K');
    });

    test('never rounds up into a wrong unit', () {
      expect(en.compactCount(999999), isNot('1000K'));
      expect(en.compactCount(999999999), '999.9M');
    });

    test('millions and billions', () {
      expect(en.compactCount(1000000), '1M');
      expect(en.compactCount(1234567), '1.2M');
      expect(en.compactCount(12400000), '12.4M');
      expect(en.compactCount(1000000000), '1B');
      expect(en.compactCount(2500000000), '2.5B');
    });

    test('Arabic uses the Arabic units with Western digits', () {
      expect(ar.compactCount(12400), '12.4 $thousand');
      expect(ar.compactCount(1000), '1 $thousand');
      expect(ar.compactCount(1234567), '1.2 $million');
      expect(ar.compactCount(1000000000), '1 $billion');
    });

    test('a negative number is shown as it is', () {
      expect(en.compactCount(-5), '-5');
    });

    test('digits are never Arabic-Indic', () {
      for (final int n in <int>[7, 12400, 3400000, 5000000000]) {
        expect(arabicIndic.hasMatch(ar.compactCount(n)), isFalse);
      }
    });
  });

  group('relativeTime', () {
    DateTime ago(Duration d) => _now.subtract(d);

    test('under a minute, and the future, read just now', () {
      expect(en.relativeTime(ago(Duration.zero)), 'just now');
      expect(en.relativeTime(ago(const Duration(seconds: 59))), 'just now');
      expect(
        en.relativeTime(_now.add(const Duration(minutes: 5))),
        'just now',
      );
      expect(
        ar.relativeTime(ago(Duration.zero)),
        ar.relativeTime(_now.add(const Duration(hours: 1))),
      );
    });

    test('English minutes, hours, days', () {
      expect(en.relativeTime(ago(const Duration(seconds: 60))), '1 minute ago');
      expect(en.relativeTime(ago(const Duration(minutes: 5))), '5 minutes ago');
      expect(
        en.relativeTime(ago(const Duration(minutes: 59, seconds: 59))),
        '59 minutes ago',
      );
      expect(en.relativeTime(ago(const Duration(minutes: 60))), '1 hour ago');
      expect(en.relativeTime(ago(const Duration(hours: 23))), '23 hours ago');
      expect(en.relativeTime(ago(const Duration(hours: 24))), '1 day ago');
      expect(en.relativeTime(ago(const Duration(days: 6))), '6 days ago');
    });

    test('Arabic plural forms for minutes: 1, 2, 3, 11', () {
      expect(
        ar.relativeTime(ago(const Duration(minutes: 1))),
        '$since \u062f\u0642\u064a\u0642\u0629',
      );
      expect(
        ar.relativeTime(ago(const Duration(minutes: 2))),
        '$since \u062f\u0642\u064a\u0642\u062a\u064a\u0646',
      );
      expect(
        ar.relativeTime(ago(const Duration(minutes: 3))),
        '$since 3 \u062f\u0642\u0627\u0626\u0642',
      );
      expect(
        ar.relativeTime(ago(const Duration(minutes: 11))),
        '$since 11 \u062f\u0642\u064a\u0642\u0629',
      );
    });

    test('Arabic days: 2 days', () {
      expect(
        ar.relativeTime(ago(const Duration(days: 2))),
        '$since \u064a\u0648\u0645\u064a\u0646',
      );
    });

    test('seven days and older switch to the absolute date', () {
      final DateTime sevenDays = _now.subtract(const Duration(days: 7));
      expect(en.relativeTime(sevenDays), 'September 28, 2026');
      expect(
        ar.relativeTime(sevenDays),
        '28 \u0633\u0628\u062a\u0645\u0628\u0631 2026',
      );
    });

    test('a UTC timestamp is compared as the same instant', () {
      final DateTime fiveMinutesAgoUtc = _now
          .subtract(const Duration(minutes: 5))
          .toUtc();
      expect(en.relativeTime(fiveMinutesAgoUtc), '5 minutes ago');
    });

    test('digits are never Arabic-Indic', () {
      for (final Duration d in <Duration>[
        const Duration(minutes: 25),
        const Duration(hours: 13),
        const Duration(days: 4),
        const Duration(days: 40),
      ]) {
        expect(arabicIndic.hasMatch(ar.relativeTime(ago(d))), isFalse);
      }
    });
  });

  group('absolute dates and times', () {
    test('English: month first', () {
      expect(en.absoluteDate(DateTime(2026, 10, 5, 12)), 'October 5, 2026');
      expect(en.absoluteDate(DateTime(2027, 1, 1, 12)), 'January 1, 2027');
      expect(en.absoluteDate(DateTime(2026, 12, 31, 12)), 'December 31, 2026');
    });

    test('Arabic: day first, Arabic month, Western digits', () {
      expect(
        ar.absoluteDate(DateTime(2026, 10, 5, 12)),
        '5 \u0623\u0643\u062a\u0648\u0628\u0631 2026',
      );
      expect(
        ar.absoluteDate(DateTime(2027, 1, 1, 12)),
        '1 \u064a\u0646\u0627\u064a\u0631 2027',
      );
    });

    test('all twelve months resolve in both languages (no raw key leaks)', () {
      const List<String> keys = <String>[
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
      final RegExp arabicLetter = RegExp('[\u0621-\u064A]');
      for (int month = 1; month <= 12; month++) {
        final String english = en.absoluteDate(DateTime(2026, month, 15, 12));
        final String arabic = ar.absoluteDate(DateTime(2026, month, 15, 12));
        expect(english.toLowerCase(), contains(keys[month - 1]));
        expect(arabicLetter.hasMatch(arabic), isTrue, reason: 'month $month');
        expect(arabic.toLowerCase(), isNot(contains(keys[month - 1])));
      }
    });

    test('time is a zero-padded 24-hour clock in both languages', () {
      expect(en.time(DateTime(2026, 10, 5, 3, 7)), '03:07');
      expect(ar.time(DateTime(2026, 10, 5, 15, 7)), '15:07');
      expect(en.time(DateTime(2026, 10, 5, 0, 0)), '00:00');
    });

    test('date and time together', () {
      final DateTime value = DateTime(2026, 10, 5, 15, 7);
      expect(en.absoluteDateTime(value), 'October 5, 2026, 15:07');
      expect(
        ar.absoluteDateTime(value),
        '5 \u0623\u0643\u062a\u0648\u0628\u0631 2026\u060c 15:07',
      );
    });

    test('digits are never Arabic-Indic', () {
      expect(
        arabicIndic.hasMatch(ar.absoluteDateTime(DateTime(2026, 3, 9, 8, 5))),
        isFalse,
      );
    });
  });

  group('price', () {
    const String egpAr = '\u062c.\u0645';
    const String sarAr = '\u0631.\u0633';
    const String aedAr = '\u062f.\u0625';
    const String jodAr = '\u062f.\u0623';

    test('English shows the ISO code after the amount', () {
      expect(en.price('199.99', 'EGP'), '199.99 EGP');
      expect(en.price('50', 'SAR'), '50 SAR');
      expect(en.price('12.5', 'AED'), '12.5 AED');
      expect(en.price('3.250', 'JOD'), '3.250 JOD');
    });

    test('Arabic shows the Arabic abbreviation of each supported currency', () {
      expect(ar.price('199.99', 'EGP'), '199.99 $egpAr');
      expect(ar.price('50', 'SAR'), '50 $sarAr');
      expect(ar.price('12.5', 'AED'), '12.5 $aedAr');
      expect(ar.price('3.250', 'JOD'), '3.250 $jodAr');
    });

    test('thousands are grouped, an all-zero fraction is dropped', () {
      expect(en.price('1234567.5', 'EGP'), '1,234,567.5 EGP');
      expect(en.price('1000', 'EGP'), '1,000 EGP');
      expect(en.price('999', 'EGP'), '999 EGP');
      expect(en.price('200.00', 'EGP'), '200 EGP');
      expect(en.price('0.00', 'EGP'), '0 EGP');
      expect(en.price('1234.50', 'EGP'), '1,234.50 EGP');
    });

    test('the amount string is used as is, never through a double', () {
      expect(en.price('12345678901234567890.12', 'EGP'),
          '12,345,678,901,234,567,890.12 EGP');
    });

    test('negative, padded and non-numeric input is handled', () {
      expect(en.price('-5.50', 'EGP'), '-5.50 EGP');
      expect(en.price(' 12 ', 'EGP'), '12 EGP');
      expect(en.price('abc', 'EGP'), 'abc EGP');
      expect(en.price('', 'EGP'), ' EGP');
    });

    test('currency code is case-insensitive; unknown codes are kept', () {
      expect(en.price('5', 'egp'), '5 EGP');
      expect(ar.price('5', 'egp'), '5 $egpAr');
      expect(en.price('5', 'usd'), '5 USD');
      expect(ar.price('5', 'USD'), '5 USD');
    });

    test('digits are never Arabic-Indic', () {
      expect(arabicIndic.hasMatch(ar.price('1234567.89', 'EGP')), isFalse);
    });
  });

  group('AppFormatters.of(context)', () {
    testWidgets('follows the active language of the widget tree', (
      tester,
    ) async {
      String? result;
      Future<void> pump(Locale locale) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (BuildContext context) {
                result = AppFormatters.of(context).compactCount(12400);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(const Locale('en'));
      expect(result, '12.4K');

      await pump(const Locale('ar'));
      expect(result, '12.4 $thousand');
    });
  });
}
