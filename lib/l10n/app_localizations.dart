import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// Application title shown in the OS task switcher.
  ///
  /// In en, this message translates to:
  /// **'Social Commerce Discovery Platform'**
  String get appTitle;

  /// Relative time shown for something that happened less than a minute ago.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get relativeJustNow;

  /// Relative time in minutes (1 to 59).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} minute ago} other{{count} minutes ago}}'**
  String relativeMinutesAgo(int count);

  /// Relative time in hours (1 to 23).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} hour ago} other{{count} hours ago}}'**
  String relativeHoursAgo(int count);

  /// Relative time in days (1 to 6).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day ago} other{{count} days ago}}'**
  String relativeDaysAgo(int count);

  /// Shown when the request could not reach the server (offline, timeout, DNS).
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get errorNetwork;

  /// Shown when the TLS certificate check fails.
  ///
  /// In en, this message translates to:
  /// **'A secure connection to the server could not be established.'**
  String get errorSecureConnection;

  /// Shown for server-side failures (HTTP 5xx).
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our end. Please try again later.'**
  String get errorServer;

  /// Backend code AUTHENTICATION_FAILED (missing, expired or invalid credentials).
  ///
  /// In en, this message translates to:
  /// **'We could not verify your identity. Please sign in again.'**
  String get errorAuthentication;

  /// Generic 401/403 without a backend code.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to do that.'**
  String get errorNotAuthorized;

  /// Backend code PERMISSION_DENIED.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do that.'**
  String get errorPermissionDenied;

  /// Backend code NOT_FOUND.
  ///
  /// In en, this message translates to:
  /// **'We could not find what you were looking for.'**
  String get errorNotFound;

  /// Backend codes METHOD_NOT_ALLOWED, NOT_ACCEPTABLE, UNSUPPORTED_MEDIA_TYPE, PARSE_ERROR.
  ///
  /// In en, this message translates to:
  /// **'That request could not be completed.'**
  String get errorBadRequest;

  /// Backend code VALIDATION_ERROR when no field-level text is shown.
  ///
  /// In en, this message translates to:
  /// **'Some of the information you entered could not be accepted. Please check it and try again.'**
  String get errorValidation;

  /// Backend code THROTTLED (rate limit).
  ///
  /// In en, this message translates to:
  /// **'Too many attempts in a short time. Please wait a moment and try again.'**
  String get errorThrottled;

  /// Backend code CONFLICT (state conflict, e.g. already moderated).
  ///
  /// In en, this message translates to:
  /// **'This item has already changed. Refresh and try again.'**
  String get errorConflict;

  /// Backend code SERVICE_UNAVAILABLE.
  ///
  /// In en, this message translates to:
  /// **'This service is not available right now. Please try again later.'**
  String get errorServiceUnavailable;

  /// The request was cancelled on the device.
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled.'**
  String get errorCancelled;

  /// Fallback when nothing more specific is known.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errorUnknown;

  /// Compact count in thousands, e.g. 12.4K followers. {value} is already formatted text with Western digits.
  ///
  /// In en, this message translates to:
  /// **'{value}K'**
  String compactThousands(String value);

  /// Compact count in millions, e.g. 1.2M.
  ///
  /// In en, this message translates to:
  /// **'{value}M'**
  String compactMillions(String value);

  /// Compact count in billions, e.g. 2.5B.
  ///
  /// In en, this message translates to:
  /// **'{value}B'**
  String compactBillions(String value);

  /// Full month name. The argument is a lower-case English month key (january ... december).
  ///
  /// In en, this message translates to:
  /// **'{month, select, january{January} february{February} march{March} april{April} may{May} june{June} july{July} august{August} september{September} october{October} november{November} december{December} other{{month}}}'**
  String monthName(String month);

  /// Absolute date. day and year are plain Western-digit text, month is the localized month name.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}'**
  String dateFull(String day, String month, String year);

  /// A date and a clock time written together.
  ///
  /// In en, this message translates to:
  /// **'{date}, {time}'**
  String dateAndTime(String date, String time);

  /// Short currency label shown next to a price. The argument is a lower-case ISO code of a supported currency.
  ///
  /// In en, this message translates to:
  /// **'{currency, select, egp{EGP} sar{SAR} aed{AED} jod{JOD} other{{currency}}}'**
  String currencyLabel(String currency);

  /// A price: amount (already grouped, Western digits) and the short currency label. For discovery display only.
  ///
  /// In en, this message translates to:
  /// **'{amount} {currency}'**
  String priceDisplay(String amount, String currency);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
