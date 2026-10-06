// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Social Commerce Discovery Platform';

  @override
  String get relativeJustNow => 'just now';

  @override
  String relativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '$count minute ago',
    );
    return '$_temp0';
  }

  @override
  String relativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '$count hour ago',
    );
    return '$_temp0';
  }

  @override
  String relativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '$count day ago',
    );
    return '$_temp0';
  }

  @override
  String get errorNetwork => 'No connection. Check your internet and try again.';

  @override
  String get errorSecureConnection => 'A secure connection to the server could not be established.';

  @override
  String get errorServer => 'Something went wrong on our end. Please try again later.';

  @override
  String get errorAuthentication => 'We could not verify your identity. Please sign in again.';

  @override
  String get errorNotAuthorized => 'You are not allowed to do that.';

  @override
  String get errorPermissionDenied => 'You do not have permission to do that.';

  @override
  String get errorNotFound => 'We could not find what you were looking for.';

  @override
  String get errorBadRequest => 'That request could not be completed.';

  @override
  String get errorValidation => 'Some of the information you entered could not be accepted. Please check it and try again.';

  @override
  String get errorThrottled => 'Too many attempts in a short time. Please wait a moment and try again.';

  @override
  String get errorConflict => 'This item has already changed. Refresh and try again.';

  @override
  String get errorServiceUnavailable => 'This service is not available right now. Please try again later.';

  @override
  String get errorCancelled => 'The request was cancelled.';

  @override
  String get errorUnknown => 'An unexpected error occurred. Please try again.';

  @override
  String compactThousands(String value) {
    return '${value}K';
  }

  @override
  String compactMillions(String value) {
    return '${value}M';
  }

  @override
  String compactBillions(String value) {
    return '${value}B';
  }

  @override
  String monthName(String month) {
    String _temp0 = intl.Intl.selectLogic(
      month,
      {
        'january': 'January',
        'february': 'February',
        'march': 'March',
        'april': 'April',
        'may': 'May',
        'june': 'June',
        'july': 'July',
        'august': 'August',
        'september': 'September',
        'october': 'October',
        'november': 'November',
        'december': 'December',
        'other': '$month',
      },
    );
    return '$_temp0';
  }

  @override
  String dateFull(String day, String month, String year) {
    return '$month $day, $year';
  }

  @override
  String dateAndTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String currencyLabel(String currency) {
    String _temp0 = intl.Intl.selectLogic(
      currency,
      {
        'egp': 'EGP',
        'sar': 'SAR',
        'aed': 'AED',
        'jod': 'JOD',
        'other': '$currency',
      },
    );
    return '$_temp0';
  }

  @override
  String priceDisplay(String amount, String currency) {
    return '$amount $currency';
  }
}
