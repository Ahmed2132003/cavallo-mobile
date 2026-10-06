import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-112: proves the generated l10n pipeline works end to end -
/// Arabic plural forms for 0, 1, 2, 3, 11 and 100, Western digits, and the
/// real text direction produced by MaterialApp for each language.
void main() {
  group('Arabic plural forms (0, 1, 2, 3, 11, 100)', () {
    late AppLocalizations ar;

    setUpAll(() async {
      ar = await AppLocalizations.delegate.load(const Locale('ar'));
    });

    test('minutes', () {
      expect(ar.relativeMinutesAgo(0), '\u0645\u0646\u0630 0 \u062f\u0642\u064a\u0642\u0629');
      expect(ar.relativeMinutesAgo(1), '\u0645\u0646\u0630 \u062f\u0642\u064a\u0642\u0629');
      expect(ar.relativeMinutesAgo(2), '\u0645\u0646\u0630 \u062f\u0642\u064a\u0642\u062a\u064a\u0646');
      expect(ar.relativeMinutesAgo(3), '\u0645\u0646\u0630 3 \u062f\u0642\u0627\u0626\u0642');
      expect(ar.relativeMinutesAgo(11), '\u0645\u0646\u0630 11 \u062f\u0642\u064a\u0642\u0629');
      expect(ar.relativeMinutesAgo(100), '\u0645\u0646\u0630 100 \u062f\u0642\u064a\u0642\u0629');
    });

    test('hours', () {
      expect(ar.relativeHoursAgo(0), '\u0645\u0646\u0630 0 \u0633\u0627\u0639\u0629');
      expect(ar.relativeHoursAgo(1), '\u0645\u0646\u0630 \u0633\u0627\u0639\u0629');
      expect(ar.relativeHoursAgo(2), '\u0645\u0646\u0630 \u0633\u0627\u0639\u062a\u064a\u0646');
      expect(ar.relativeHoursAgo(3), '\u0645\u0646\u0630 3 \u0633\u0627\u0639\u0627\u062a');
      expect(ar.relativeHoursAgo(11), '\u0645\u0646\u0630 11 \u0633\u0627\u0639\u0629');
      expect(ar.relativeHoursAgo(100), '\u0645\u0646\u0630 100 \u0633\u0627\u0639\u0629');
    });

    test('days', () {
      expect(ar.relativeDaysAgo(0), '\u0645\u0646\u0630 0 \u064a\u0648\u0645');
      expect(ar.relativeDaysAgo(1), '\u0645\u0646\u0630 \u064a\u0648\u0645');
      expect(ar.relativeDaysAgo(2), '\u0645\u0646\u0630 \u064a\u0648\u0645\u064a\u0646');
      expect(ar.relativeDaysAgo(3), '\u0645\u0646\u0630 3 \u0623\u064a\u0627\u0645');
      expect(ar.relativeDaysAgo(11), '\u0645\u0646\u0630 11 \u064a\u0648\u0645\u064b\u0627');
      expect(ar.relativeDaysAgo(100), '\u0645\u0646\u0630 100 \u064a\u0648\u0645');
    });

    test('digits are Western (0-9), never Arabic-Indic', () {
      final RegExp arabicIndic = RegExp('[\u0660-\u0669\u06F0-\u06F9]');
      expect(arabicIndic.hasMatch(ar.relativeMinutesAgo(25)), isFalse);
      expect(ar.relativeMinutesAgo(25), contains('25'));
    });
  });

  group('English plural forms', () {
    late AppLocalizations en;

    setUpAll(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('minutes / hours / days', () {
      expect(en.relativeMinutesAgo(1), '1 minute ago');
      expect(en.relativeMinutesAgo(5), '5 minutes ago');
      expect(en.relativeHoursAgo(1), '1 hour ago');
      expect(en.relativeHoursAgo(3), '3 hours ago');
      expect(en.relativeDaysAgo(1), '1 day ago');
      expect(en.relativeDaysAgo(6), '6 days ago');
      expect(en.relativeJustNow, 'just now');
    });
  });

  group('supported locales', () {
    test('exactly Arabic and English, Arabic first', () {
      final List<String> codes = AppLocalizations.supportedLocales
          .map((Locale l) => l.languageCode)
          .toList();
      expect(codes, <String>['ar', 'en']);
    });
  });

  group('text direction through MaterialApp', () {
    Future<TextDirection> pumpWith(WidgetTester tester, Locale locale) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              captured = context;
              return Text(AppLocalizations.of(context).appTitle);
            },
          ),
        ),
      );
      return Directionality.of(captured);
    }

    testWidgets('Arabic is right-to-left and shows the Arabic title',
        (WidgetTester tester) async {
      final TextDirection direction =
          await pumpWith(tester, const Locale('ar'));
      expect(direction, TextDirection.rtl);
      expect(find.text('\u0645\u0646\u0635\u0629 \u0627\u0643\u062a\u0634\u0627\u0641 \u0627\u0644\u062a\u062c\u0627\u0631 \u0648\u0627\u0644\u0645\u0635\u0627\u0646\u0639'), findsOneWidget);
    });

    testWidgets('English is left-to-right and shows the English title',
        (WidgetTester tester) async {
      final TextDirection direction =
          await pumpWith(tester, const Locale('en'));
      expect(direction, TextDirection.ltr);
      expect(find.text('Social Commerce Discovery Platform'), findsOneWidget);
    });
  });
}
