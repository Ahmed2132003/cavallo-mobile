// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Ù…Ù†ØµØ© Ø§ÙƒØªØ´Ø§Ù Ø§Ù„ØªØ¬Ø§Ø± ÙˆØ§Ù„Ù…ØµØ§Ù†Ø¹';

  @override
  String get relativeJustNow => 'Ø§Ù„Ø¢Ù†';

  @override
  String relativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ù…Ù†Ø° $count Ø¯Ù‚ÙŠÙ‚Ø©',
      many: 'Ù…Ù†Ø° $count Ø¯Ù‚ÙŠÙ‚Ø©',
      few: 'Ù…Ù†Ø° $count Ø¯Ù‚Ø§Ø¦Ù‚',
      two: 'Ù…Ù†Ø° Ø¯Ù‚ÙŠÙ‚ØªÙŠÙ†',
      one: 'Ù…Ù†Ø° Ø¯Ù‚ÙŠÙ‚Ø©',
      zero: 'Ù…Ù†Ø° $count Ø¯Ù‚ÙŠÙ‚Ø©',
    );
    return '$_temp0';
  }

  @override
  String relativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ù…Ù†Ø° $count Ø³Ø§Ø¹Ø©',
      many: 'Ù…Ù†Ø° $count Ø³Ø§Ø¹Ø©',
      few: 'Ù…Ù†Ø° $count Ø³Ø§Ø¹Ø§Øª',
      two: 'Ù…Ù†Ø° Ø³Ø§Ø¹ØªÙŠÙ†',
      one: 'Ù…Ù†Ø° Ø³Ø§Ø¹Ø©',
      zero: 'Ù…Ù†Ø° $count Ø³Ø§Ø¹Ø©',
    );
    return '$_temp0';
  }

  @override
  String relativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ù…Ù†Ø° $count ÙŠÙˆÙ…',
      many: 'Ù…Ù†Ø° $count ÙŠÙˆÙ…Ù‹Ø§',
      few: 'Ù…Ù†Ø° $count Ø£ÙŠØ§Ù…',
      two: 'Ù…Ù†Ø° ÙŠÙˆÙ…ÙŠÙ†',
      one: 'Ù…Ù†Ø° ÙŠÙˆÙ…',
      zero: 'Ù…Ù†Ø° $count ÙŠÙˆÙ…',
    );
    return '$_temp0';
  }
}
