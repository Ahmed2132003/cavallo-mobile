import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-112: proves the generated l10n pipeline works end to end â€”
/// Arabic plural forms for 0, 1, 2, 3, 11 and 100, Western digits, and the
/// real text direction produced by MaterialApp for each language.
void main() {
  group('Arabic plural forms (0, 1, 2, 3, 11, 100)', () {
    late AppLocalizations ar;

    setUpAll(() async {
      ar = await AppLocalizations.delegate.load(const Locale('ar'));
    });

    test('minutes', () {
      expect(ar.relativeMinutesAgo(0), 'Ù…Ù†Ø° 0 Ø¯Ù‚ÙŠÙ‚Ø©');
      expect(ar.relativeMinutesAgo(1), 'Ù…Ù†Ø° Ø¯Ù‚ÙŠÙ‚Ø©');
      expect(ar.relativeMinutesAgo(2), 'Ù…Ù†Ø° Ø¯Ù‚ÙŠÙ‚ØªÙŠÙ†');
      expect(ar.relativeMinutesAgo(3), 'Ù…Ù†Ø° 3 Ø¯Ù‚Ø§Ø¦Ù‚');
      expect(ar.relativeMinutesAgo(11), 'Ù…Ù†Ø° 11 Ø¯Ù‚ÙŠÙ‚Ø©');
      expect(ar.relativeMinutesAgo(100), 'Ù…Ù†Ø° 100 Ø¯Ù‚ÙŠÙ‚Ø©');
    });

    test('hours', () {
      expect(ar.relativeHoursAgo(0), 'Ù…Ù†Ø° 0 Ø³Ø§Ø¹Ø©');
      expect(ar.relativeHoursAgo(1), 'Ù…Ù†Ø° Ø³Ø§Ø¹Ø©');
      expect(ar.relativeHoursAgo(2), 'Ù…Ù†Ø° Ø³Ø§Ø¹ØªÙŠÙ†');
      expect(ar.relativeHoursAgo(3), 'Ù…Ù†Ø° 3 Ø³Ø§Ø¹Ø§Øª');
      expect(ar.relativeHoursAgo(11), 'Ù…Ù†Ø° 11 Ø³Ø§Ø¹Ø©');
      expect(ar.relativeHoursAgo(100), 'Ù…Ù†Ø° 100 Ø³Ø§Ø¹Ø©');
    });

    test('days', () {
      expect(ar.relativeDaysAgo(0), 'Ù…Ù†Ø° 0 ÙŠÙˆÙ…');
      expect(ar.relativeDaysAgo(1), 'Ù…Ù†Ø° ÙŠÙˆÙ…');
      expect(ar.relativeDaysAgo(2), 'Ù…Ù†Ø° ÙŠÙˆÙ…ÙŠÙ†');
      expect(ar.relativeDaysAgo(3), 'Ù…Ù†Ø° 3 Ø£ÙŠØ§Ù…');
      expect(ar.relativeDaysAgo(11), 'Ù…Ù†Ø° 11 ÙŠÙˆÙ…Ù‹Ø§');
      expect(ar.relativeDaysAgo(100), 'Ù…Ù†Ø° 100 ÙŠÙˆÙ…');
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
      expect(find.text('Ù…Ù†ØµØ© Ø§ÙƒØªØ´Ø§Ù Ø§Ù„ØªØ¬Ø§Ø± ÙˆØ§Ù„Ù…ØµØ§Ù†Ø¹'), findsOneWidget);
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