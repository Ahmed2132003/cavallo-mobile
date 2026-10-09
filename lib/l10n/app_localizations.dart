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

  /// App bar title of the login screen.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authLoginTitle;

  /// App bar title of the registration screen.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authRegisterTitle;

  /// Label of the email field.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// Label of the password field.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// Label of the confirm-password field.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPasswordLabel;

  /// Label above the customer / business selector.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get authAccountTypeLabel;

  /// Account type option: a person who discovers and follows businesses.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get authAccountTypeCustomer;

  /// Account type option: a trader or factory.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get authAccountTypeBusiness;

  /// Submit button of the login form.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLoginButton;

  /// Submit button of the registration form.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authRegisterButton;

  /// Link from the login screen to the registration screen.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get authGoToRegister;

  /// Link from the registration screen to the login screen.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get authGoToLogin;

  /// Validation: email is empty.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get authEmailRequired;

  /// Validation: email has no @.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authEmailInvalid;

  /// Validation: password is empty.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get authPasswordRequired;

  /// Validation: confirm-password is empty.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password.'**
  String get authConfirmPasswordRequired;

  /// Validation: the two passwords differ (checked on the device).
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authPasswordsDoNotMatch;

  /// Shown on the login screen when the server rejects the credentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get authInvalidCredentials;

  /// Shown when registration worked but the automatic login right after it failed.
  ///
  /// In en, this message translates to:
  /// **'Account created, but automatic sign-in failed. Please log in.'**
  String get authAutoLoginFailed;

  /// The server rejected the email field. The server's own sentence is never shown.
  ///
  /// In en, this message translates to:
  /// **'This email address cannot be used. Please check it or try another one.'**
  String get authFieldErrorEmail;

  /// The server rejected the password field.
  ///
  /// In en, this message translates to:
  /// **'This password cannot be used. Please choose a different one.'**
  String get authFieldErrorPassword;

  /// The server rejected the confirm-password field.
  ///
  /// In en, this message translates to:
  /// **'The passwords you entered do not match.'**
  String get authFieldErrorPasswordConfirm;

  /// The server rejected the account type.
  ///
  /// In en, this message translates to:
  /// **'Please choose a valid account type.'**
  String get authFieldErrorAccountType;

  /// Retry button of the shared error state.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Text on the splash screen while the session is checked.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get splashLoading;

  /// Button on the splash placeholder that opens the login screen.
  ///
  /// In en, this message translates to:
  /// **'Go to login'**
  String get splashGoToLogin;

  /// Title of the page shown for an address the app does not know.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get routeErrorTitle;

  /// Body of the unknown-address page.
  ///
  /// In en, this message translates to:
  /// **'The page you are looking for does not exist or has moved.'**
  String get routeErrorMessage;

  /// Button of the unknown-address page that returns to the home screen.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get routeErrorGoHome;

  /// Bottom bar tab: the home feed.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom bar tab: search and discover.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// Bottom bar tab (Customer): saved posts, reels and products.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get navSaved;

  /// Bottom bar tab (Business): opens the create sheet (post, reel, story, product).
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get navCreate;

  /// Bottom bar tab (Staff): the moderation queue.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get navModeration;

  /// Bottom bar tab: conversations.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get navChats;

  /// Bottom bar tab: profile and settings.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// App bar title of the Profile and Settings hub (tab 5).
  ///
  /// In en, this message translates to:
  /// **'Profile & Settings'**
  String get hubTitle;

  /// Account-type chip in the hub header: a Customer account.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get hubAccountTypeCustomer;

  /// Account-type chip in the hub header: a Business (Trader or Factory) account.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get hubAccountTypeBusiness;

  /// Account-type chip in the hub header: a Staff or Moderator account.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get hubAccountTypeStaff;

  /// Hub row: opens the Saved screen.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get hubSaved;

  /// Hub row: opens the notification preferences screen.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get hubNotificationPreferences;

  /// Caption of the hub group that holds Appearance and Language.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get hubSettingsGroup;

  /// Hub row title: the light or dark theme setting.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get hubAppearance;

  /// Appearance option: follow the device theme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get hubAppearanceSystem;

  /// Appearance option: always light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get hubAppearanceLight;

  /// Appearance option: always dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get hubAppearanceDark;

  /// Hub row title: the app language setting.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get hubLanguage;

  /// Caption of the hub group shown to Business accounts only.
  ///
  /// In en, this message translates to:
  /// **'Business tools'**
  String get hubBusinessTools;

  /// Hub row (Business): opens the business console.
  ///
  /// In en, this message translates to:
  /// **'Business console'**
  String get hubBusinessConsole;

  /// Hub row (Business): opens the business profile editor.
  ///
  /// In en, this message translates to:
  /// **'Edit business profile'**
  String get hubEditBusinessProfile;

  /// Hub row (Business): the products list of the business console.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get hubProducts;

  /// Hub row (Business): the posts and reels list of the business console.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get hubContent;

  /// Hub row (Business): the stories list of the business console.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get hubStories;

  /// Hub row (Business): the analytics screen of the business console.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get hubAnalytics;

  /// Hub row (Business): shows whether the business is currently Featured. Display only.
  ///
  /// In en, this message translates to:
  /// **'Featured status'**
  String get hubFeaturedStatus;

  /// Value of the Featured status row when the business is not Featured.
  ///
  /// In en, this message translates to:
  /// **'Not featured'**
  String get hubFeaturedNo;

  /// Caption of the hub group shown to Staff accounts only.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get hubModeration;

  /// Hub row (Staff): opens the moderation queue, with the pending count.
  ///
  /// In en, this message translates to:
  /// **'Moderation queue'**
  String get hubModerationQueue;

  /// Hub row: opens the About dialog.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get hubAbout;

  /// Hub row and confirm button: sign out of the account.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get hubLogOut;

  /// Title of the dialog that asks for confirmation before signing out.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get hubLogOutConfirmTitle;

  /// Body of the sign-out confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to use your account.'**
  String get hubLogOutConfirmMessage;

  /// Cancel button of the sign-out confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get hubCancel;

  /// Tab of the Saved screen: saved posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get savedTabPosts;

  /// Tab of the Saved screen: saved reels.
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get savedTabReels;

  /// Tab of the Saved screen: saved products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get savedTabProducts;

  /// Empty state of the Saved screen, Posts tab.
  ///
  /// In en, this message translates to:
  /// **'No saved posts yet. Tap the bookmark on a post to keep it here.'**
  String get savedEmptyPosts;

  /// Empty state of the Saved screen, Reels tab.
  ///
  /// In en, this message translates to:
  /// **'No saved reels yet. Tap the bookmark on a reel to keep it here.'**
  String get savedEmptyReels;

  /// Empty state of the Saved screen, Products tab.
  ///
  /// In en, this message translates to:
  /// **'No saved products yet. Tap the bookmark on a product to keep it here.'**
  String get savedEmptyProducts;

  /// Tooltip of the bookmark button that removes an item from Saved.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get savedUnsave;

  /// Shown instead of the preview when a saved item no longer exists.
  ///
  /// In en, this message translates to:
  /// **'This item is no longer available'**
  String get savedUnavailable;

  /// Title of a saved item whose preview text is empty (for example an image-only post).
  ///
  /// In en, this message translates to:
  /// **'Saved item'**
  String get savedNoPreviewText;

  /// SnackBar shown when removing an item from Saved fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove it from saved. Please try again.'**
  String get savedUnsaveFailed;

  /// Shown when loading the next page of the Saved list fails, next to a Retry button.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more saved items.'**
  String get savedLoadMoreFailed;

  /// Title of the Business create sheet opened by the + tab.
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get createSheetTitle;

  /// Create sheet option: new post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get createSheetPost;

  /// Create sheet option: new reel.
  ///
  /// In en, this message translates to:
  /// **'Reel'**
  String get createSheetReel;

  /// Create sheet option: new story.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get createSheetStory;

  /// Create sheet option: new product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get createSheetProduct;

  /// Brand wordmark at the start of the Home top bar. A brand name, so it is the same in every language.
  ///
  /// In en, this message translates to:
  /// **'Cavallo'**
  String get homeWordmark;

  /// Tooltip and screen-reader label of the bell icon in the Home top bar.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get homeNotificationsTooltip;

  /// Tooltip and screen-reader label of the chats icon in the Home top bar.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get homeChatsTooltip;

  /// Hint of the search bar at the top of the Explore tab. Tapping it opens the search screen.
  ///
  /// In en, this message translates to:
  /// **'Search businesses, products and posts'**
  String get discoverSearchHint;

  /// Label of the Business account's own tile at the start of the stories tray.
  ///
  /// In en, this message translates to:
  /// **'Your story'**
  String get storyYourStory;

  /// Screen-reader label of the Business account's own '+' tile in the stories tray. Opens the story creation form.
  ///
  /// In en, this message translates to:
  /// **'Add to your story'**
  String get storyAddTooltip;

  /// Screen-reader label of a story ring with at least one unseen story.
  ///
  /// In en, this message translates to:
  /// **'{name}, new story'**
  String storyRingNewLabel(String name);

  /// Screen-reader label of a story ring whose stories were all seen.
  ///
  /// In en, this message translates to:
  /// **'{name}, story seen'**
  String storyRingSeenLabel(String name);

  /// Tooltip and screen-reader label of the close button of the full-screen story viewer.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get storyViewerClose;

  /// Story viewer: the link does not point to a valid business.
  ///
  /// In en, this message translates to:
  /// **'Story not found.'**
  String get storyViewerNotFound;

  /// Story viewer: the business has no visible stories.
  ///
  /// In en, this message translates to:
  /// **'No stories to show right now.'**
  String get storyViewerEmpty;

  /// Story viewer: generic failure message when the stories could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load stories.'**
  String get storyViewerLoadFailed;

  /// Story viewer: name shown in the header when the business name is not known.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get storyViewerDefaultName;

  /// Name shown for a business whose public profile could not be resolved.
  ///
  /// In en, this message translates to:
  /// **'Unknown business'**
  String get businessUnknownName;

  /// Button that expands a cut-off post or reel caption in place.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get captionMore;

  /// Tooltip and screen-reader label of the Like button on posts and reels.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get actionLike;

  /// Tooltip and screen-reader label of the Comment button on posts and reels.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get actionComment;

  /// Tooltip and screen-reader label of the Share button on posts and reels.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// Tooltip and screen-reader label of the Save (bookmark) button on posts and reels.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Likes line under the action row of a post card. count is the exact number (it picks the plural form); formatted is the compact text (for example 1.2K) shown to the user.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{formatted} like} other{{formatted} likes}}'**
  String feedLikesLine(int count, String formatted);

  /// Link under the caption of a post card that opens the comments. count is the exact number (plural form); formatted is the compact text.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{View 1 comment} other{View all {formatted} comments}}'**
  String feedViewAllComments(int count, String formatted);

  /// Screen-reader label of the blue Verified mark after a business name.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get feedVerifiedLabel;

  /// Screen-reader label of the picture of a post card.
  ///
  /// In en, this message translates to:
  /// **'Post by {name}'**
  String feedPostMediaLabel(String name);

  /// Screen-reader label of the media of a reel card.
  ///
  /// In en, this message translates to:
  /// **'Reel by {name}'**
  String feedReelMediaLabel(String name);

  /// Home feed: message shown when there is nothing to show yet.
  ///
  /// In en, this message translates to:
  /// **'Your feed is empty right now.\nFollow some businesses, or check back soon.'**
  String get feedEmptyMessage;

  /// Home feed: message shown when the first page could not be loaded (next to the Retry button).
  ///
  /// In en, this message translates to:
  /// **'Could not load your feed.'**
  String get feedLoadFailed;

  /// Home feed: screen-reader label of the skeleton shown while the first page loads.
  ///
  /// In en, this message translates to:
  /// **'Loading your feed'**
  String get feedLoadingLabel;

  /// App bar title of the public business profile screen.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get profileScreenTitle;

  /// Business profile stats row: label under the number of posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profileStatPosts;

  /// Business profile stats row: label under the number of followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get profileStatFollowers;

  /// Business profile stats row: label under the number of products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get profileStatProducts;

  /// Business profile: tooltip and screen-reader label of the Posts grid tab.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profileTabPosts;

  /// Business profile: tooltip and screen-reader label of the Reels grid tab.
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get profileTabReels;

  /// Business profile: tooltip and screen-reader label of the Products grid tab.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get profileTabProducts;

  /// Business profile: tooltip and screen-reader label of the Info tab.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get profileTabInfo;

  /// Label of the Follow button on a business.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get followButtonFollow;

  /// Label of the button once the business is followed (tap to unfollow).
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followButtonFollowing;

  /// Followers line under the Follow button. count is the exact number (plural form); formatted is the compact text.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{formatted} follower} other{{formatted} followers}}'**
  String followersCountLine(int count, String formatted);

  /// Business profile: button that opens a conversation with the business.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get profileMessageButton;

  /// Snackbar shown when the conversation was started but could not be opened directly.
  ///
  /// In en, this message translates to:
  /// **'Conversation started. Open it from Messages.'**
  String get profileMessageStarted;

  /// Snackbar shown when starting a conversation with the business failed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the conversation. Please try again.'**
  String get profileMessageFailed;

  /// Business profile: message when the business does not exist.
  ///
  /// In en, this message translates to:
  /// **'Business not found.\nIt may have been removed.'**
  String get profileNotFound;

  /// Business profile: fallback message when loading failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this business profile.'**
  String get profileLoadFailed;

  /// Business profile: text shown when the bio is empty.
  ///
  /// In en, this message translates to:
  /// **'This business hasn\'t added a description yet.'**
  String get profileNoDescription;

  /// City and country of a business.
  ///
  /// In en, this message translates to:
  /// **'{city}, {country}'**
  String profileLocation(String city, String country);

  /// Business type label: trader.
  ///
  /// In en, this message translates to:
  /// **'Trader'**
  String get businessTypeTrader;

  /// Business type label: factory.
  ///
  /// In en, this message translates to:
  /// **'Factory'**
  String get businessTypeFactory;

  /// Business profile, Posts tab: empty state.
  ///
  /// In en, this message translates to:
  /// **'This business hasn\'t shared any posts yet.'**
  String get profilePostsEmpty;

  /// Business profile, Posts tab: fallback error message.
  ///
  /// In en, this message translates to:
  /// **'Could not load this business\'s posts.'**
  String get profilePostsLoadFailed;

  /// Business profile, Reels tab: empty state.
  ///
  /// In en, this message translates to:
  /// **'This business hasn\'t shared any reels yet.'**
  String get profileReelsEmpty;

  /// Business profile, Reels tab: fallback error message.
  ///
  /// In en, this message translates to:
  /// **'Could not load this business\'s reels.'**
  String get profileReelsLoadFailed;

  /// Business profile, Products tab: empty state.
  ///
  /// In en, this message translates to:
  /// **'This business hasn\'t added any products yet.'**
  String get profileProductsEmpty;

  /// Business profile, Products tab: fallback error message.
  ///
  /// In en, this message translates to:
  /// **'Could not load this business\'s products.'**
  String get profileProductsLoadFailed;

  /// Business profile, Info tab: label of the business type row.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get profileInfoType;

  /// Business profile, Info tab: label of the location row.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get profileInfoLocation;

  /// Business profile, Info tab: label of the phone row.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profileInfoPhone;

  /// Screen-reader label of the skeleton tiles shown while a profile tab loads.
  ///
  /// In en, this message translates to:
  /// **'Loading content'**
  String get profileGridLoadingLabel;

  /// Text of the amber Featured badge (Featured / Sponsored businesses).
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featuredBadgeLabel;

  /// Hint of the search field on the Search screen.
  ///
  /// In en, this message translates to:
  /// **'Search traders, factories, products...'**
  String get searchFieldHint;

  /// Tooltip / screen-reader label of the clear button inside the search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClearTooltip;

  /// Search screen: label of the chip that opens the filter sheet (no filter active).
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get searchFiltersChip;

  /// Search screen: label of the chip that opens the filter sheet when some filters are active. count is how many.
  ///
  /// In en, this message translates to:
  /// **'Filters ({count})'**
  String searchFiltersChipActive(int count);

  /// Search screen: prompt before any search was made.
  ///
  /// In en, this message translates to:
  /// **'Search for traders, factories, and products.\nType a keyword or set a filter to get started.'**
  String get searchIdlePrompt;

  /// Search screen: a search finished with zero results.
  ///
  /// In en, this message translates to:
  /// **'No results found. Try a different search or adjust your filters.'**
  String get searchNoResults;

  /// Search screen: error message when a search fails.
  ///
  /// In en, this message translates to:
  /// **'Could not load search results.'**
  String get searchLoadFailed;

  /// Screen-reader label of the skeleton rows shown while search results load.
  ///
  /// In en, this message translates to:
  /// **'Loading results'**
  String get searchResultsLoadingLabel;

  /// Discover screen: empty state.
  ///
  /// In en, this message translates to:
  /// **'Nothing to discover yet.\nCheck back soon for new businesses.'**
  String get discoverEmpty;

  /// Discover screen: error message when the first load fails.
  ///
  /// In en, this message translates to:
  /// **'Could not load Discover right now.'**
  String get discoverLoadFailed;

  /// Title of the filter bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get searchFilterTitle;

  /// Filter sheet: label of the category field; also the text of the category chip when a category filter is active.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get searchFilterCategory;

  /// Filter sheet: the dropdown entry meaning no category filter.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get searchFilterCategoryAll;

  /// Filter sheet: the category list failed to load.
  ///
  /// In en, this message translates to:
  /// **'Could not load categories.'**
  String get searchFilterCategoriesFailed;

  /// Filter sheet: country field label.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get searchFilterCountry;

  /// Filter sheet: city field label.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get searchFilterCity;

  /// Filter sheet: title of the business type chips.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get searchFilterBusinessType;

  /// Filter sheet: the option meaning no restriction (business type, rating).
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get searchFilterAny;

  /// Filter sheet: title of the minimum rating dropdown.
  ///
  /// In en, this message translates to:
  /// **'Minimum rating'**
  String get searchFilterMinRating;

  /// Filter sheet: one option of the minimum rating dropdown, also the text of the rating chip. stars is 1 to 4.
  ///
  /// In en, this message translates to:
  /// **'{stars, plural, one{{stars} star & up} other{{stars} stars & up}}'**
  String searchFilterMinRatingOption(int stars);

  /// Filter sheet: label of the Featured-only switch; also the text of its chip.
  ///
  /// In en, this message translates to:
  /// **'Featured only'**
  String get searchFilterFeaturedOnly;

  /// Filter sheet: button that resets every filter.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchFilterClear;

  /// Filter sheet: button that applies the filters.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get searchFilterApply;

  /// Title of the product detail screen (app bar).
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productDetailTitle;

  /// Price line of a product. price is the backend decimal text, currency is the currency code. It is a discovery price, never a checkout total.
  ///
  /// In en, this message translates to:
  /// **'Starting from {price} {currency}'**
  String productPriceHeadline(String price, String currency);

  /// Mandatory note under every product price: the price is approximate and negotiated with the business (architecture Section 20).
  ///
  /// In en, this message translates to:
  /// **'Approximate price, negotiable directly with the business. Message the business to confirm.'**
  String get productPriceNote;

  /// Empty state of the product detail screen when the product does not exist or is no longer available.
  ///
  /// In en, this message translates to:
  /// **'Product not found.\nIt may have been removed.'**
  String get productNotFoundMessage;

  /// Fallback error text of the product detail screen when the failure has no message of its own.
  ///
  /// In en, this message translates to:
  /// **'Could not load this product.'**
  String get productLoadFailed;

  /// Shown on the product detail screen when the product has no description.
  ///
  /// In en, this message translates to:
  /// **'This business hasn\'t added a description yet.'**
  String get productNoDescription;

  /// Heading of the read-only variants list on the product detail screen.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get productVariantsTitle;

  /// Primary button on the product detail screen: starts a conversation with the business. Not a purchase action.
  ///
  /// In en, this message translates to:
  /// **'Message Business'**
  String get productMessageBusiness;

  /// Text sent by the native share sheet when sharing a product. name is the product name.
  ///
  /// In en, this message translates to:
  /// **'Check out {name} on Cavallo'**
  String productShareText(String name);

  /// Screen-reader label of the product detail loading skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading product'**
  String get productLoadingLabel;

  /// Heading of the comments bottom sheet and of the inline comments block on post and reel detail screens.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// Hint of the comment input field.
  ///
  /// In en, this message translates to:
  /// **'Add a comment...'**
  String get commentsInputHint;

  /// Tooltip and screen-reader label of the send button of the comment input.
  ///
  /// In en, this message translates to:
  /// **'Post comment'**
  String get commentsPostTooltip;

  /// Empty state of the comment list.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Be the first to comment.'**
  String get commentsEmpty;

  /// Marker under a comment that is hidden pending moderation; only its author or a moderator sees it.
  ///
  /// In en, this message translates to:
  /// **'Pending review: hidden from other users'**
  String get commentsPendingReview;

  /// Button that loads the next page of comments.
  ///
  /// In en, this message translates to:
  /// **'Load more comments'**
  String get commentsLoadMore;

  /// Author name of a comment while the backend gives only the user id. id is the user id.
  ///
  /// In en, this message translates to:
  /// **'User #{id}'**
  String commentsAuthorFallback(String id);

  /// Screen-reader label of the comment list loading skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading comments'**
  String get commentsLoadingLabel;

  /// Title of the chat list screen (top bar).
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatListTitle;

  /// Empty state of the chat list.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatListEmpty;

  /// Row preview of a conversation that has no messages yet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatListNoMessages;

  /// Row name when the other participant is missing (should never happen).
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get chatListUnknownUser;

  /// Row preview when the last message is a photo with no text.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatListPreviewPhoto;

  /// Row preview when the last message is a video with no text.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatListPreviewVideo;

  /// Row preview when the last message shares a post with no text.
  ///
  /// In en, this message translates to:
  /// **'Shared a post'**
  String get chatListPreviewSharedPost;

  /// Row preview when the last message shares a reel with no text.
  ///
  /// In en, this message translates to:
  /// **'Shared a reel'**
  String get chatListPreviewSharedReel;

  /// Row preview when the last message shares a product with no text.
  ///
  /// In en, this message translates to:
  /// **'Shared a product'**
  String get chatListPreviewSharedProduct;

  /// Screen-reader label of the chat list loading skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading conversations'**
  String get chatListLoadingLabel;

  /// Label of the temporary manual-testing button on the chat list.
  ///
  /// In en, this message translates to:
  /// **'New chat (test)'**
  String get chatListNewChatTest;

  /// Title of the temporary test-conversation dialog.
  ///
  /// In en, this message translates to:
  /// **'Start test conversation'**
  String get chatTestDialogTitle;

  /// Field label in the temporary test-conversation dialog.
  ///
  /// In en, this message translates to:
  /// **'Other account\'s user id'**
  String get chatTestUserIdLabel;

  /// Field hint in the temporary test-conversation dialog.
  ///
  /// In en, this message translates to:
  /// **'e.g. 7'**
  String get chatTestUserIdHint;

  /// Cancel button of the temporary test-conversation dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatTestCancel;

  /// Confirm button of the temporary test-conversation dialog.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get chatTestStart;

  /// Screen-reader label of the unread-count badge on a chat row.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} unread message} other{{count} unread messages}}'**
  String chatListUnreadLabel(int count);

  /// Temporary placeholder name of a test conversation. id is the user id.
  ///
  /// In en, this message translates to:
  /// **'User #{id}'**
  String chatTestUserPlaceholder(int id);

  /// Title of the notification center screen (app bar).
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// Title of the notification preferences screen and tooltip of the settings button in the notification center.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notifSettingsTitle;

  /// Snackbar shown when the next page of notifications fails to load.
  ///
  /// In en, this message translates to:
  /// **'Could not load more notifications.'**
  String get notifLoadMoreFailed;

  /// Error message of the notification center when the first page fails to load.
  ///
  /// In en, this message translates to:
  /// **'Could not load your notifications.'**
  String get notifLoadFailed;

  /// Empty state of the notification center.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get notifEmpty;

  /// Notification center section header for notifications received today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notifSectionToday;

  /// Notification center section header for notifications from the previous 6 days.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get notifSectionThisWeek;

  /// Notification center section header for notifications older than a week.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notifSectionEarlier;

  /// Screen reader label of the unread dot on a notification row.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notifUnreadLabel;

  /// Screen reader label of the notification skeleton loaders.
  ///
  /// In en, this message translates to:
  /// **'Loading notifications'**
  String get notifLoadingLabel;

  /// Small header above the group of notification switches.
  ///
  /// In en, this message translates to:
  /// **'Notify me about'**
  String get notifPrefsSectionHeader;

  /// Notification preference title: chat.
  ///
  /// In en, this message translates to:
  /// **'Chat messages'**
  String get notifPrefChatTitle;

  /// Notification preference description: chat.
  ///
  /// In en, this message translates to:
  /// **'New messages in your conversations.'**
  String get notifPrefChatSubtitle;

  /// Notification preference title: moderation.
  ///
  /// In en, this message translates to:
  /// **'Content review'**
  String get notifPrefModerationTitle;

  /// Notification preference description: moderation.
  ///
  /// In en, this message translates to:
  /// **'When your content is approved or rejected.'**
  String get notifPrefModerationSubtitle;

  /// Notification preference title: social.
  ///
  /// In en, this message translates to:
  /// **'Social activity'**
  String get notifPrefSocialTitle;

  /// Notification preference description: social.
  ///
  /// In en, this message translates to:
  /// **'New followers, comments, likes, shares and ratings.'**
  String get notifPrefSocialSubtitle;

  /// Snackbar shown when saving a notification preference fails.
  ///
  /// In en, this message translates to:
  /// **'Could not save your preference. Please try again.'**
  String get notifPrefsSaveFailed;

  /// Error message of the notification preferences screen.
  ///
  /// In en, this message translates to:
  /// **'Could not load your notification settings.'**
  String get notifPrefsLoadFailed;

  /// Footer under the switches: system announcements cannot be turned off.
  ///
  /// In en, this message translates to:
  /// **'Important system announcements are always delivered.'**
  String get notifPrefsSystemFooter;
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
