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

  /// No description provided for @hubEditMyProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get hubEditMyProfile;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit my profile'**
  String get editProfileTitle;

  /// No description provided for @editProfileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get editProfileNameLabel;

  /// No description provided for @editProfileNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Display name must be 80 characters or fewer.'**
  String get editProfileNameTooLong;

  /// No description provided for @editProfilePhotoSemantic.
  ///
  /// In en, this message translates to:
  /// **'Profile photo. Tap to change.'**
  String get editProfilePhotoSemantic;

  /// No description provided for @editProfilePickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get editProfilePickFromGallery;

  /// No description provided for @editProfileRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get editProfileRemovePhoto;

  /// No description provided for @editProfileSave.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get editProfileSave;

  /// No description provided for @editProfileNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes to save.'**
  String get editProfileNoChanges;

  /// No description provided for @editProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get editProfileSaved;

  /// No description provided for @editProfilePhotoUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Choose a JPEG, PNG or WebP image.'**
  String get editProfilePhotoUnsupported;

  /// Edit profile: snackbar when the chosen photo exceeds the size limit.
  ///
  /// In en, this message translates to:
  /// **'Photo is too large (max {maxMb} MB).'**
  String editProfilePhotoTooLarge(int maxMb);

  /// No description provided for @editProfilePhotoPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the photo. Please try again.'**
  String get editProfilePhotoPickFailed;

  /// No description provided for @editProfileAvatarRejected.
  ///
  /// In en, this message translates to:
  /// **'The server could not accept this photo. Try a different one.'**
  String get editProfileAvatarRejected;

  /// No description provided for @editProfileNameRejected.
  ///
  /// In en, this message translates to:
  /// **'The server could not accept this display name.'**
  String get editProfileNameRejected;

  /// No description provided for @editProfileLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading your profile'**
  String get editProfileLoadingLabel;

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

  /// Backend code SUBSCRIPTION_REQUIRED (HTTP 403): the business is locked or has no active subscription.
  ///
  /// In en, this message translates to:
  /// **'Your subscription has ended. Renew your plan to continue.'**
  String get errorSubscriptionRequired;

  /// Backend code STORAGE_QUOTA_EXCEEDED (HTTP 403) when an upload would exceed the plan's storage.
  ///
  /// In en, this message translates to:
  /// **'You have used all of your storage. Upgrade your plan or delete some files to continue.'**
  String get errorStorageQuotaExceeded;

  /// Backend code downgrade_blocked_usage (HTTP 409): current usage is above the target plan's quota.
  ///
  /// In en, this message translates to:
  /// **'You are using more storage than this plan includes. Free up space before switching to it.'**
  String get errorDowngradeBlockedUsage;

  /// Backend code downgrade_already_pending (HTTP 409): a downgrade is already scheduled.
  ///
  /// In en, this message translates to:
  /// **'A plan change is already scheduled for the end of your current period.'**
  String get errorDowngradeAlreadyPending;

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

  /// About dialog title: the name of the app.
  ///
  /// In en, this message translates to:
  /// **'Cavallo'**
  String get aboutAppName;

  /// About dialog body: short description of what the app is.
  ///
  /// In en, this message translates to:
  /// **'Cavallo is a social commerce app that connects traders and factories with customers. Share reels, posts and stories, discover products and businesses, and chat directly to get deals done, all in one place.'**
  String get aboutDescription;

  /// About dialog: developer credit line.
  ///
  /// In en, this message translates to:
  /// **'Developed by Eng. Ahmed Ibrahim'**
  String get aboutDevelopedBy;

  /// About dialog: button that closes the dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get aboutClose;

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

  /// Label of the new-chat button on the chat list.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatListNewChat;

  /// Title of the new-chat picker sheet.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChatSheetTitle;

  /// Subtitle of the new-chat picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation with a business you follow'**
  String get newChatSheetSubtitle;

  /// Empty state of the new-chat picker when the user follows nobody.
  ///
  /// In en, this message translates to:
  /// **'You are not following any business yet. Follow a business to start chatting with it.'**
  String get newChatSheetEmpty;

  /// Snackbar when a conversation was started but could not be opened.
  ///
  /// In en, this message translates to:
  /// **'Could not open the conversation. Please try again.'**
  String get newChatOpenFailed;

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

  /// Business console tab / dashboard card: products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get consoleNavProducts;

  /// Business console tab / dashboard card: posts and reels.
  ///
  /// In en, this message translates to:
  /// **'Posts/Reels'**
  String get consoleNavContent;

  /// Business console tab and screen title: stories.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get consoleNavStories;

  /// Business console tab: analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get consoleNavAnalytics;

  /// Dashboard card label: stories that are published or pending review.
  ///
  /// In en, this message translates to:
  /// **'Active stories'**
  String get consoleDashStories;

  /// Dashboard card label: new followers in the selected analytics range.
  ///
  /// In en, this message translates to:
  /// **'New followers'**
  String get consoleDashFollowers;

  /// Dashboard card caption: the analytics range. days is the exact number (it picks the plural form).
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{last day} other{last {days} days}}'**
  String consoleDashRange(int days);

  /// Dashboard card value shown when that area failed to load.
  ///
  /// In en, this message translates to:
  /// **'–'**
  String get consoleDashValueUnavailable;

  /// App bar title of the business product list.
  ///
  /// In en, this message translates to:
  /// **'My Products'**
  String get consoleProductsTitle;

  /// Extended button on the product list.
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get consoleProductsCreate;

  /// Empty state of the product list.
  ///
  /// In en, this message translates to:
  /// **'No products yet.\nTap \"Create New\" to add your first product.'**
  String get consoleProductsEmpty;

  /// Fallback error of the product list.
  ///
  /// In en, this message translates to:
  /// **'Could not load your products.'**
  String get consoleProductsLoadFailed;

  /// Title of the delete product confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete product?'**
  String get consoleProductsDeleteTitle;

  /// Body of the delete product dialog. name is the product name.
  ///
  /// In en, this message translates to:
  /// **'This will remove \"{name}\" from your products. This cannot be undone.'**
  String consoleProductsDeleteBody(String name);

  /// Snackbar when deleting a product fails.
  ///
  /// In en, this message translates to:
  /// **'Could not delete this product.'**
  String get consoleProductsDeleteFailed;

  /// Variant count under a product row. count is the exact number.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} variant} other{{count} variants}}'**
  String consoleProductVariants(int count);

  /// Status chip of a hidden product.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get consoleProductInactive;

  /// Tooltip of an edit icon in console rows.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get consoleEdit;

  /// Tooltip and confirm button of a delete action in the console.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get consoleDelete;

  /// Cancel button of console dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get consoleCancel;

  /// App bar title of the business posts and reels list.
  ///
  /// In en, this message translates to:
  /// **'My Content'**
  String get consoleContentTitle;

  /// Extended button: create a post.
  ///
  /// In en, this message translates to:
  /// **'New Post'**
  String get consoleContentNewPost;

  /// Extended button: create a reel.
  ///
  /// In en, this message translates to:
  /// **'New Reel'**
  String get consoleContentNewReel;

  /// Empty state of the posts and reels list.
  ///
  /// In en, this message translates to:
  /// **'No posts or reels yet.\nTap \"New Post\" or \"New Reel\" to share your first one.'**
  String get consoleContentEmpty;

  /// Fallback error of the posts and reels list.
  ///
  /// In en, this message translates to:
  /// **'Could not load your content.'**
  String get consoleContentLoadFailed;

  /// Type label of a post row.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get consoleTypePost;

  /// Type label of a reel row.
  ///
  /// In en, this message translates to:
  /// **'Reel'**
  String get consoleTypeReel;

  /// Moderation chip: waiting for review (Pending).
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get consoleStatusUnderReview;

  /// Moderation chip: approved and published (Approved).
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get consoleStatusLive;

  /// Moderation chip: rejected, always followed by the reason.
  ///
  /// In en, this message translates to:
  /// **'Rejected: {reason}'**
  String consoleStatusRejectedWithReason(String reason);

  /// Fallback shown when a rejected item has no reason.
  ///
  /// In en, this message translates to:
  /// **'no reason given'**
  String get consoleStatusNoReasonGiven;

  /// Chip of a reel that has not reached moderation yet.
  ///
  /// In en, this message translates to:
  /// **'Processing video…'**
  String get consoleStatusProcessing;

  /// Chip of a reel whose processing failed.
  ///
  /// In en, this message translates to:
  /// **'Video processing failed'**
  String get consoleStatusProcessingFailed;

  /// Extended button on the stories list.
  ///
  /// In en, this message translates to:
  /// **'Create Story'**
  String get consoleStoriesCreate;

  /// Empty state of the stories list.
  ///
  /// In en, this message translates to:
  /// **'No stories yet.\nTap \"Create Story\" to share your first one.'**
  String get consoleStoriesEmpty;

  /// Fallback error of the stories list.
  ///
  /// In en, this message translates to:
  /// **'Could not load your stories.'**
  String get consoleStoriesLoadFailed;

  /// Title of a story row. id is the story number.
  ///
  /// In en, this message translates to:
  /// **'Story #{id}'**
  String consoleStoryNumber(int id);

  /// Story status chip: published.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get consoleStoryPublished;

  /// Story status chip: pending review.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get consoleStoryPending;

  /// Story status chip: rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get consoleStoryRejected;

  /// Story status chip: expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get consoleStoryExpired;

  /// Story status chip: status not recognised.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get consoleStoryUnknown;

  /// Rejection reason line under a rejected story.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String consoleStoryReason(String reason);

  /// Time left of a story: hours and minutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m left'**
  String consoleStoryTimeLeftHM(int hours, int minutes);

  /// Time left of a story: minutes only.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m left'**
  String consoleStoryTimeLeftM(int minutes);

  /// Time left of a story: under one minute.
  ///
  /// In en, this message translates to:
  /// **'Less than 1m left'**
  String get consoleStoryTimeLeftLess;

  /// Generic refresh button / tooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// Generic cancel button of a dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Staff: title of the moderation queue screen.
  ///
  /// In en, this message translates to:
  /// **'Moderation queue'**
  String get moderationQueueTitle;

  /// Staff: empty state of the moderation queue.
  ///
  /// In en, this message translates to:
  /// **'The queue is clear.\nNothing is waiting for review.'**
  String get moderationQueueEmpty;

  /// Staff: shown when the API answers 403 for a moderation call.
  ///
  /// In en, this message translates to:
  /// **'Your account is not allowed to review content. If it should be, ask an admin to add it to the Moderator group.'**
  String get moderationNotAllowed;

  /// Staff: generic load failure of the moderation queue.
  ///
  /// In en, this message translates to:
  /// **'Could not load the moderation queue.'**
  String get moderationQueueLoadFailed;

  /// Staff: queue summary line. count is the number of pending items.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String moderationSummaryPending(int count);

  /// Staff: queue summary line when some items are fast path.
  ///
  /// In en, this message translates to:
  /// **'{count} pending · {fast} fast path'**
  String moderationSummaryPendingFast(int count, int fast);

  /// Staff: placeholder when a queue item has no preview text.
  ///
  /// In en, this message translates to:
  /// **'No preview available'**
  String get moderationNoPreview;

  /// Staff: priority badge of a fast path item.
  ///
  /// In en, this message translates to:
  /// **'Fast path'**
  String get moderationPriorityFast;

  /// Staff: priority badge of a normal item.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get moderationPriorityNormal;

  /// Staff: waiting time shorter than one minute.
  ///
  /// In en, this message translates to:
  /// **'<1 min'**
  String get moderationAgeUnderMinute;

  /// Staff: waiting time in minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String moderationAgeMinutes(int minutes);

  /// Staff: waiting time in whole hours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String moderationAgeHours(int hours);

  /// Staff: waiting time in hours and minutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String moderationAgeHoursMinutes(int hours, int minutes);

  /// Staff: waiting time in whole days.
  ///
  /// In en, this message translates to:
  /// **'{days} d'**
  String moderationAgeDays(int days);

  /// Staff: waiting time in days and hours.
  ///
  /// In en, this message translates to:
  /// **'{days} d {hours} h'**
  String moderationAgeDaysHours(int days, int hours);

  /// Staff: waiting time chip text when the SLA is breached. age is the already formatted waiting time.
  ///
  /// In en, this message translates to:
  /// **'{age} · overdue'**
  String moderationAgeOverdue(String age);

  /// Staff: content type label.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get moderationContentTypePost;

  /// Staff: content type label.
  ///
  /// In en, this message translates to:
  /// **'Reel'**
  String get moderationContentTypeReel;

  /// Staff: content type label.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get moderationContentTypeStory;

  /// Staff: content type label when the backend sent none.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get moderationContentTypeUnknown;

  /// Staff: title of the review screen.
  ///
  /// In en, this message translates to:
  /// **'Review content'**
  String get moderationReviewTitle;

  /// Staff: caption above the preview text on the review screen.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get moderationPreview;

  /// Staff: review details row label.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get moderationDetailType;

  /// Staff: review details row label.
  ///
  /// In en, this message translates to:
  /// **'Submitted by'**
  String get moderationDetailSubmittedBy;

  /// Staff: review details row label.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get moderationDetailPriority;

  /// Staff: review details row label.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get moderationDetailWaiting;

  /// Staff: review details row label.
  ///
  /// In en, this message translates to:
  /// **'Queue item'**
  String get moderationDetailQueueItem;

  /// Staff: note under the review details.
  ///
  /// In en, this message translates to:
  /// **'Waiting time is as of the last queue refresh.'**
  String get moderationWaitingNote;

  /// Staff: reject button and confirm button.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get moderationReject;

  /// Staff: approve button.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get moderationApprove;

  /// Staff: snackbar after approving.
  ///
  /// In en, this message translates to:
  /// **'Item approved'**
  String get moderationItemApproved;

  /// Staff: snackbar after rejecting.
  ///
  /// In en, this message translates to:
  /// **'Item rejected'**
  String get moderationItemRejected;

  /// Staff: fallback error when approving fails.
  ///
  /// In en, this message translates to:
  /// **'Could not approve this item. Please try again.'**
  String get moderationApproveFailed;

  /// Staff: fallback error when rejecting fails.
  ///
  /// In en, this message translates to:
  /// **'Could not reject this item. Please try again.'**
  String get moderationRejectFailed;

  /// Staff: snackbar when the item is no longer pending.
  ///
  /// In en, this message translates to:
  /// **'This item was already handled by someone else, or no longer exists. It has been removed from your queue.'**
  String get moderationAlreadyHandled;

  /// Staff: title of the reject dialog.
  ///
  /// In en, this message translates to:
  /// **'Reject content'**
  String get moderationRejectTitle;

  /// Staff: note in the reject dialog. The rejection reason is always visible to the business.
  ///
  /// In en, this message translates to:
  /// **'The business will see this reason.'**
  String get moderationRejectNote;

  /// Staff: label of the reason field in the reject dialog.
  ///
  /// In en, this message translates to:
  /// **'Reason (required)'**
  String get moderationRejectReasonLabel;

  /// Staff: validation text under the reason field.
  ///
  /// In en, this message translates to:
  /// **'A reason is required.'**
  String get moderationRejectReasonRequired;

  /// Business: analytics load failure.
  ///
  /// In en, this message translates to:
  /// **'Could not load your analytics.'**
  String get analyticsLoadFailed;

  /// Business: analytics empty state. days is the exact range (it picks the plural form).
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{No activity has been recorded for the last day yet.} other{No activity has been recorded for the last {days} days yet.}}'**
  String analyticsEmpty(int days);

  /// Business: how many days of the range have a recorded row.
  ///
  /// In en, this message translates to:
  /// **'Days with data: {withData} of {days}'**
  String analyticsDaysWithData(int withData, int days);

  /// Business: note under the analytics totals.
  ///
  /// In en, this message translates to:
  /// **'Days are counted in UTC. Days without a recorded row are not drawn as zero.'**
  String get analyticsUtcNote;

  /// Business: chart title.
  ///
  /// In en, this message translates to:
  /// **'New followers by day'**
  String get analyticsChartFollowersTitle;

  /// Business: screen reader summary of the followers chart. days picks the plural form.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{New followers: {total} total over 1 day} other{New followers: {total} total over {days} days}}'**
  String analyticsChartFollowersSemantics(int days, int total);

  /// Business: chart title.
  ///
  /// In en, this message translates to:
  /// **'Likes received by day'**
  String get analyticsChartLikesTitle;

  /// Business: screen reader summary of the likes chart. days picks the plural form.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Likes received: {total} total over 1 day} other{Likes received: {total} total over {days} days}}'**
  String analyticsChartLikesSemantics(int days, int total);

  /// Business: section heading.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get analyticsRatingsHeading;

  /// Business: shown when there is no rating in the range.
  ///
  /// In en, this message translates to:
  /// **'No rating has been recorded yet, so there is no rating trend to draw.'**
  String get analyticsRatingEmpty;

  /// Business: chart title.
  ///
  /// In en, this message translates to:
  /// **'Average rating by day'**
  String get analyticsChartRatingTitle;

  /// Business: screen reader summary of the rating chart. days picks the plural form; average is the formatted latest average.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Average rating: latest {average} over 1 day} other{Average rating: latest {average} over {days} days}}'**
  String analyticsChartRatingSemantics(int days, String average);

  /// Business: note under the rating chart.
  ///
  /// In en, this message translates to:
  /// **'Each point is the average rating stored when that day was rolled up. Days before the first rating are not drawn.'**
  String get analyticsRatingNote;

  /// Business: section heading.
  ///
  /// In en, this message translates to:
  /// **'Catalog size'**
  String get analyticsCatalogHeading;

  /// Business: note above the catalog size cards.
  ///
  /// In en, this message translates to:
  /// **'As of {day}/{month} (UTC). These are totals recorded by the daily rollup, not daily changes.'**
  String analyticsCatalogAsOf(int day, int month);

  /// Business: label of a range segment (7 / 14 / 30 days).
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{{days} day} other{{days} days}}'**
  String analyticsRangeDays(int days);

  /// Business: analytics card label.
  ///
  /// In en, this message translates to:
  /// **'New followers'**
  String get analyticsNewFollowers;

  /// Business: analytics card label.
  ///
  /// In en, this message translates to:
  /// **'Likes received'**
  String get analyticsLikesReceived;

  /// Business: analytics card label.
  ///
  /// In en, this message translates to:
  /// **'Comments received'**
  String get analyticsCommentsReceived;

  /// Business: analytics card label.
  ///
  /// In en, this message translates to:
  /// **'Story views'**
  String get analyticsStoryViews;

  /// Business: analytics card label.
  ///
  /// In en, this message translates to:
  /// **'New ratings'**
  String get analyticsNewRatings;

  /// Business: analytics card label.
  ///
  /// In en, this message translates to:
  /// **'Average rating'**
  String get analyticsAverageRating;

  /// Business: analytics card label.
  ///
  /// In en, this message translates to:
  /// **'Active products'**
  String get analyticsActiveProducts;

  /// Business: analytics card label.
  ///
  /// In en, this message translates to:
  /// **'Published posts'**
  String get analyticsPublishedPosts;

  /// Business: analytics card label.
  ///
  /// In en, this message translates to:
  /// **'Published reels'**
  String get analyticsPublishedReels;

  /// Business onboarding: app bar title.
  ///
  /// In en, this message translates to:
  /// **'Complete your business profile'**
  String get bizOnboardTitle;

  /// Business forms: business name field label.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get bizFieldName;

  /// Business forms: phone field label.
  ///
  /// In en, this message translates to:
  /// **'Phone number (optional)'**
  String get bizFieldPhone;

  /// Business forms: phone field validation message.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number for the selected country.'**
  String get bizFieldPhoneInvalid;

  /// Business forms: description field label.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get bizFieldDescription;

  /// Business onboarding: submit button.
  ///
  /// In en, this message translates to:
  /// **'Complete profile'**
  String get bizOnboardSubmit;

  /// Business profile edit: app bar title.
  ///
  /// In en, this message translates to:
  /// **'Business profile'**
  String get bizProfileTitle;

  /// Business profile edit: back-to-home tooltip.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get bizProfileBackHome;

  /// Business profile edit: shown when no profile exists.
  ///
  /// In en, this message translates to:
  /// **'You have not completed your business profile yet.'**
  String get bizProfileIncomplete;

  /// Business profile edit: snackbar when nothing changed.
  ///
  /// In en, this message translates to:
  /// **'No changes to save.'**
  String get bizProfileNoChanges;

  /// Business profile edit: snackbar after saving.
  ///
  /// In en, this message translates to:
  /// **'Business profile updated.'**
  String get bizProfileUpdated;

  /// Business profile edit: save button.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get bizProfileSave;

  /// Shared: remove button (image, video).
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// Post detail: empty state when the post does not exist.
  ///
  /// In en, this message translates to:
  /// **'Post not found.\nIt may have been removed.'**
  String get contentPostNotFound;

  /// Reel detail: empty state when the reel does not exist.
  ///
  /// In en, this message translates to:
  /// **'Reel not found.\nIt may have been removed.'**
  String get contentReelNotFound;

  /// Reel detail: snackbar of the playback placeholder button.
  ///
  /// In en, this message translates to:
  /// **'Video playback — Coming soon'**
  String get contentReelPlaybackSoon;

  /// Post form: image section label.
  ///
  /// In en, this message translates to:
  /// **'Image (optional)'**
  String get contentFormImageLabel;

  /// Reel form: video section label.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get contentFormVideoLabel;

  /// Post and product forms: pick-image button.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get contentFormChooseImage;

  /// Post and product forms: pick-image button once an image is chosen.
  ///
  /// In en, this message translates to:
  /// **'Change image'**
  String get contentFormChangeImage;

  /// Reel form: pick-video button.
  ///
  /// In en, this message translates to:
  /// **'Choose video'**
  String get contentFormChooseVideo;

  /// Reel form: pick-video button once a video is chosen.
  ///
  /// In en, this message translates to:
  /// **'Change video'**
  String get contentFormChangeVideo;

  /// Post and reel forms: caption field label.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get contentFormCaption;

  /// Post form: app bar title.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get postFormTitle;

  /// Post form: moderation note under the form.
  ///
  /// In en, this message translates to:
  /// **'Your post will be reviewed before it becomes visible to customers.'**
  String get postFormReviewNote;

  /// Post form: submit button.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postFormSubmit;

  /// Reel form: app bar title.
  ///
  /// In en, this message translates to:
  /// **'New reel'**
  String get reelFormTitle;

  /// Reel form: processing and moderation note under the form.
  ///
  /// In en, this message translates to:
  /// **'Your video is processed first, then reviewed before it becomes visible to customers. You\'ll see its status on your content list.'**
  String get reelFormReviewNote;

  /// Reel form: submit button.
  ///
  /// In en, this message translates to:
  /// **'Post reel'**
  String get reelFormSubmit;

  /// Product form: image section label.
  ///
  /// In en, this message translates to:
  /// **'Product image (optional)'**
  String get productFormImageLabel;

  /// Product form: variant name field label.
  ///
  /// In en, this message translates to:
  /// **'Variant name (e.g. Size)'**
  String get productFormVariantName;

  /// Product form: variant value field label.
  ///
  /// In en, this message translates to:
  /// **'Value (e.g. Large)'**
  String get productFormVariantValue;

  /// Product form: remove-variant tooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove variant'**
  String get productFormRemoveVariant;

  /// Product form: add-variant button.
  ///
  /// In en, this message translates to:
  /// **'Add variant'**
  String get productFormAddVariant;

  /// Product form: name field label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get productFormName;

  /// Product form: description field label.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get productFormDescription;

  /// Product form: price field label.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get productFormPrice;

  /// Product form: currency dropdown label.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get productFormCurrency;

  /// Product form: active switch title.
  ///
  /// In en, this message translates to:
  /// **'Active (visible to customers)'**
  String get productFormActive;

  /// Product form: category validation message.
  ///
  /// In en, this message translates to:
  /// **'Category is required.'**
  String get productFormCategoryRequired;

  /// Product form: currency validation message.
  ///
  /// In en, this message translates to:
  /// **'Currency is required.'**
  String get productFormCurrencyRequired;

  /// Content overflow menu: tooltip.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get socialMoreOptions;

  /// Report: menu item and dialog title.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get socialReport;

  /// Report: snackbar after submitting.
  ///
  /// In en, this message translates to:
  /// **'Thanks, your report was submitted.'**
  String get socialReportThanks;

  /// Report dialog: question above the reasons.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this?'**
  String get socialReportWhy;

  /// Report dialog: details field label.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get socialReportDetails;

  /// Report dialog: submit button.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get socialReportSubmit;

  /// Report reason: spam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get socialReasonSpam;

  /// Report reason: inappropriate content.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get socialReasonInappropriate;

  /// Report reason: misleading.
  ///
  /// In en, this message translates to:
  /// **'Misleading'**
  String get socialReasonMisleading;

  /// Report reason: other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get socialReasonOther;

  /// Story creation: snackbar after the upload is queued.
  ///
  /// In en, this message translates to:
  /// **'Story upload started.'**
  String get storyUploadStarted;

  /// Story creation: placeholder before a file is picked.
  ///
  /// In en, this message translates to:
  /// **'No photo or video selected yet.'**
  String get storyNoMediaSelected;

  /// Story creation: error when submitting without a file.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or video first.'**
  String get storyAddMediaFirst;

  /// Story creation: pick-photo button.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get storyAddPhoto;

  /// Story creation: pick-video button.
  ///
  /// In en, this message translates to:
  /// **'Add Video'**
  String get storyAddVideo;

  /// Story creation: submit button.
  ///
  /// In en, this message translates to:
  /// **'Post Story'**
  String get storyPostButton;

  /// Story upload banner: discard-failed-upload tooltip.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get storyUploadDiscard;

  /// Story upload banner: uploading status. attempt is the current attempt number.
  ///
  /// In en, this message translates to:
  /// **'Uploading story... (attempt {attempt} of 5)'**
  String storyUploadUploading(int attempt);

  /// Story upload banner: retrying status. attempt is the current attempt number.
  ///
  /// In en, this message translates to:
  /// **'Connection lost — retrying story upload... (attempt {attempt} of 5)'**
  String storyUploadRetrying(int attempt);

  /// Story upload banner: failed status without a reason.
  ///
  /// In en, this message translates to:
  /// **'Story upload failed.'**
  String get storyUploadFailed;

  /// Story upload banner: failed status with the reason returned by the server.
  ///
  /// In en, this message translates to:
  /// **'Story upload failed: {reason}'**
  String storyUploadFailedWithReason(String reason);

  /// Push notification banner: action button that opens the linked screen.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get pushBannerView;

  /// No description provided for @validationBusinessNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Business name is required.'**
  String get validationBusinessNameRequired;

  /// No description provided for @validationCountryRequired.
  ///
  /// In en, this message translates to:
  /// **'Country is required.'**
  String get validationCountryRequired;

  /// No description provided for @validationCityRequired.
  ///
  /// In en, this message translates to:
  /// **'City is required.'**
  String get validationCityRequired;

  /// No description provided for @businessProfileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your business profile.'**
  String get businessProfileLoadError;

  /// No description provided for @postLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this post.'**
  String get postLoadError;

  /// No description provided for @reelLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this reel.'**
  String get reelLoadError;

  /// No description provided for @commonGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonGenericError;

  /// No description provided for @validationCaptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Caption is required.'**
  String get validationCaptionRequired;

  /// No description provided for @reelVideoRequired.
  ///
  /// In en, this message translates to:
  /// **'A video is required.'**
  String get reelVideoRequired;

  /// No description provided for @productFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get productFormEditTitle;

  /// No description provided for @productFormCreate.
  ///
  /// In en, this message translates to:
  /// **'Create product'**
  String get productFormCreate;

  /// No description provided for @productFormSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get productFormSaveChanges;

  /// No description provided for @validationProductNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get validationProductNameRequired;

  /// No description provided for @validationDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Description is required.'**
  String get validationDescriptionRequired;

  /// No description provided for @validationPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'Price is required.'**
  String get validationPriceRequired;

  /// No description provided for @validationPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price (e.g. 199.99).'**
  String get validationPriceInvalid;

  /// Chat thread app bar title when the other participant is unknown.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatThreadFallbackTitle;

  /// Chat thread subtitle: this device's live connection is up.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get chatConnectionOnline;

  /// Chat thread subtitle: connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get chatConnectionConnecting;

  /// Chat thread subtitle: connection lost, retrying.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get chatConnectionReconnecting;

  /// Chat thread subtitle: no live connection.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chatConnectionOffline;

  /// Chat thread subtitle while the other person is typing.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get chatThreadTyping;

  /// Empty chat thread message.
  ///
  /// In en, this message translates to:
  /// **'No messages yet — say hi!'**
  String get chatThreadEmpty;

  /// Hint text of the chat message input.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get chatComposerHint;

  /// Attach sheet option: pick a photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatAttachPhoto;

  /// Attach sheet option: pick a video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatAttachVideo;

  /// Snackbar when the chosen photo exceeds the size cap.
  ///
  /// In en, this message translates to:
  /// **'Photo is too large (max {maxMb} MB).'**
  String chatPhotoTooLarge(int maxMb);

  /// Chat video viewer: shown when the video fails to load or decode.
  ///
  /// In en, this message translates to:
  /// **'This video cannot be played here. Its format may not be supported on your device.'**
  String get chatVideoCannotPlay;

  /// Chat video viewer: retry loading the video.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get chatVideoRetry;

  /// Chat video viewer: open the video URL in an external player/browser.
  ///
  /// In en, this message translates to:
  /// **'Open in another app'**
  String get chatVideoOpenExternal;

  /// Snackbar when the chosen video exceeds the size cap.
  ///
  /// In en, this message translates to:
  /// **'Video is too large (max {maxMb} MB).'**
  String chatVideoTooLarge(int maxMb);

  /// Outgoing bubble footer while the queue retries.
  ///
  /// In en, this message translates to:
  /// **'Retrying…'**
  String get chatBubbleRetrying;

  /// Outgoing bubble footer when sending failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send · Tap to retry'**
  String get chatBubbleFailedTapRetry;

  /// Share options sheet: system share sheet.
  ///
  /// In en, this message translates to:
  /// **'Share via…'**
  String get chatShareVia;

  /// Share options sheet entry and picker title.
  ///
  /// In en, this message translates to:
  /// **'Share to conversation'**
  String get chatShareToConversation;

  /// Share picker empty state.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.\nStart one from the Messages tab first.'**
  String get chatSharePickerEmpty;

  /// Share picker load error.
  ///
  /// In en, this message translates to:
  /// **'Could not load your conversations.'**
  String get chatSharePickerLoadError;

  /// Snackbar when sharing to a conversation fails unexpectedly.
  ///
  /// In en, this message translates to:
  /// **'Could not share. Please try again.'**
  String get chatShareFailed;

  /// Label on a shared-content preview card.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get sharedContentTypePost;

  /// Label on a shared-content preview card.
  ///
  /// In en, this message translates to:
  /// **'Reel'**
  String get sharedContentTypeReel;

  /// Label on a shared-content preview card.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get sharedContentTypeProduct;

  /// Shared content was removed after sharing.
  ///
  /// In en, this message translates to:
  /// **'This content is no longer available'**
  String get sharedContentUnavailable;

  /// Tooltip of the mute button on the full-screen reel player.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get reelPlayerMute;

  /// Tooltip of the unmute button on the full-screen reel player.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get reelPlayerUnmute;

  /// Shown over the reel player when the video fails to load, next to a Retry button.
  ///
  /// In en, this message translates to:
  /// **'Could not play this video.'**
  String get reelPlayerError;

  /// Hint shown under the reel form while the video is uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading your video... large videos can take a few minutes. Please keep this screen open.'**
  String get reelFormUploading;

  /// Business forms: button that picks a profile photo when there is none.
  ///
  /// In en, this message translates to:
  /// **'Add profile photo'**
  String get bizAvatarAdd;

  /// Business forms: button that picks a different profile photo.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get bizAvatarChange;

  /// Business forms: button that removes the profile photo.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get bizAvatarRemove;

  /// Snackbar after the business profile photo was uploaded.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated.'**
  String get bizAvatarUpdated;

  /// Snackbar after the business profile photo was removed.
  ///
  /// In en, this message translates to:
  /// **'Profile photo removed.'**
  String get bizAvatarRemoved;

  /// Snackbar when picking or uploading the profile photo failed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the photo. Please try again.'**
  String get bizAvatarUploadFailed;

  /// Snackbar after onboarding when only the photo upload failed.
  ///
  /// In en, this message translates to:
  /// **'Your profile was created, but the photo could not be uploaded. You can add it from Edit profile.'**
  String get bizAvatarUploadLater;

  /// Accessibility label of the business profile photo.
  ///
  /// In en, this message translates to:
  /// **'Business profile photo'**
  String get bizAvatarSemantic;

  /// Forgot-password step 1 (email): screen title.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get authResetEmailTitle;

  /// Forgot-password step 1: explanatory text under the title.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email and we will send you a verification code.'**
  String get authResetEmailSubtitle;

  /// Forgot-password step 1: button that requests the verification code.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authResetEmailSubmit;

  /// Forgot-password step 2 (code): screen title.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get authResetOtpTitle;

  /// Forgot-password step 2: explains where the code was sent. {email} is the address the user typed.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code we sent to {email}.'**
  String authResetOtpSubtitle(String email);

  /// Forgot-password step 2: label of the code field.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get authResetOtpLabel;

  /// Forgot-password step 2: button that checks the code.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get authResetOtpSubmit;

  /// Forgot-password step 2: shown when the code field is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code.'**
  String get authResetOtpRequired;

  /// Forgot-password step 2: shown when the server rejects the code (wrong, expired or too many tries; the server does not say which).
  ///
  /// In en, this message translates to:
  /// **'This code is invalid or has expired. Check it or request a new code.'**
  String get authResetOtpInvalid;

  /// Forgot-password step 2: button that asks for a new code once the wait is over.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get authResetResendButton;

  /// Forgot-password step 2: disabled resend button while the wait runs. {seconds} is the whole number of seconds left (Western digits).
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String authResetResendCooldown(int seconds);

  /// Forgot-password step 2: confirmation after resending.
  ///
  /// In en, this message translates to:
  /// **'A new code has been sent.'**
  String get authResetResendSent;

  /// Forgot-password step 2: link that goes back to step 1.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get authResetChangeEmail;

  /// Forgot-password step 3 (new password): screen title.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get authResetNewPasswordTitle;

  /// Forgot-password step 3: explanatory text under the title.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password for your account.'**
  String get authResetNewPasswordSubtitle;

  /// Forgot-password step 3: label of the new password field.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authResetNewPasswordLabel;

  /// Forgot-password step 3: label of the confirmation field.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get authResetConfirmPasswordLabel;

  /// Forgot-password step 3: button that saves the new password.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authResetNewPasswordSubmit;

  /// Forgot-password step 3: shown when the password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password.'**
  String get authResetPasswordRequired;

  /// Forgot-password step 3: shown when the two password fields differ.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authResetPasswordsDoNotMatch;

  /// Forgot-password step 3: shown when the server rejects the password as too weak or common.
  ///
  /// In en, this message translates to:
  /// **'This password cannot be used. Choose a stronger one.'**
  String get authResetPasswordWeak;

  /// Forgot-password step 3: shown when the server says the reset token is wrong or expired; the flow restarts at step 1.
  ///
  /// In en, this message translates to:
  /// **'Your reset session has expired. Please start again.'**
  String get authResetSessionExpired;

  /// Forgot-password done state: title.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get authResetSuccessTitle;

  /// Forgot-password done state: explanatory text.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed. Log in with your new password.'**
  String get authResetSuccessBody;

  /// Forgot-password done state: button that returns to the login screen.
  ///
  /// In en, this message translates to:
  /// **'Back to log in'**
  String get authResetBackToLogin;

  /// Forgot-password flow: shown when the server throttles a request (HTTP 429).
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get authResetThrottled;

  /// Login screen: link to the forgot-password flow.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPasswordLink;

  /// Forgot-password step 2: neutral text (the server answers the same for every address, so it does not say the code was sent). {email} is the address the user typed.
  ///
  /// In en, this message translates to:
  /// **'If {email} is registered, a 6-digit code is on its way.'**
  String authResetOtpNeutralHint(String email);

  /// Forgot-password step 2: how long the code is valid (matches the backend OTP lifetime of 300 seconds).
  ///
  /// In en, this message translates to:
  /// **'The code is valid for 5 minutes.'**
  String get authResetOtpExpiry;

  /// Forgot-password step 3: tooltip of the button that reveals the typed password.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authResetShowPassword;

  /// Forgot-password step 3: tooltip of the button that hides the typed password.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authResetHidePassword;

  /// No description provided for @ordersStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get ordersStatusPending;

  /// No description provided for @ordersStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get ordersStatusConfirmed;

  /// No description provided for @ordersStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get ordersStatusProcessing;

  /// No description provided for @ordersStatusShipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get ordersStatusShipped;

  /// No description provided for @ordersStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get ordersStatusDelivered;

  /// No description provided for @ordersStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get ordersStatusCancelled;

  /// No description provided for @ordersStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get ordersStatusUnknown;

  /// No description provided for @ordersFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get ordersFilterAll;

  /// No description provided for @ordersTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersTitle;

  /// No description provided for @consoleNavOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get consoleNavOrders;

  /// No description provided for @ordersOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get ordersOverviewTitle;

  /// No description provided for @ordersOverviewTotal.
  ///
  /// In en, this message translates to:
  /// **'Total orders'**
  String get ordersOverviewTotal;

  /// No description provided for @ordersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by order number'**
  String get ordersSearchHint;

  /// No description provided for @ordersSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get ordersSearchClear;

  /// No description provided for @ordersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get ordersEmptyTitle;

  /// No description provided for @ordersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Sales you record from chat will appear here.'**
  String get ordersEmptyBody;

  /// No description provided for @ordersEmptyFilteredTitle.
  ///
  /// In en, this message translates to:
  /// **'No orders with this status'**
  String get ordersEmptyFilteredTitle;

  /// No description provided for @ordersEmptySearchTitle.
  ///
  /// In en, this message translates to:
  /// **'No order matches your search'**
  String get ordersEmptySearchTitle;

  /// No description provided for @ordersErrorLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load orders.'**
  String get ordersErrorLoad;

  /// Orders list: shown when loading stopped at the page cap.
  ///
  /// In en, this message translates to:
  /// **'Showing the latest {count} orders only.'**
  String ordersTruncatedNote(int count);

  /// No description provided for @ordersCustomerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get ordersCustomerLabel;

  /// No description provided for @ordersProductLabel.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get ordersProductLabel;

  /// No description provided for @ordersQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get ordersQuantityLabel;

  /// No description provided for @ordersUnitPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Agreed unit price'**
  String get ordersUnitPriceLabel;

  /// No description provided for @ordersTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get ordersTotalLabel;

  /// No description provided for @ordersCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get ordersCurrencyLabel;

  /// No description provided for @ordersStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get ordersStatusLabel;

  /// Order card: quantity times the agreed unit price.
  ///
  /// In en, this message translates to:
  /// **'{quantity} × {price}'**
  String ordersQuantityTimesPrice(int quantity, String price);

  /// Order: creation date.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String ordersCreatedAt(String date);

  /// Order: confirmation date.
  ///
  /// In en, this message translates to:
  /// **'Confirmed {date}'**
  String ordersConfirmedAt(String date);

  /// Order: delivery date.
  ///
  /// In en, this message translates to:
  /// **'Delivered {date}'**
  String ordersCompletedAt(String date);

  /// Order: cancellation date.
  ///
  /// In en, this message translates to:
  /// **'Cancelled {date}'**
  String ordersCancelledAt(String date);

  /// No description provided for @ordersTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get ordersTimelineTitle;

  /// No description provided for @ordersTimelineCreated.
  ///
  /// In en, this message translates to:
  /// **'Order recorded'**
  String get ordersTimelineCreated;

  /// Order timeline entry for a status change.
  ///
  /// In en, this message translates to:
  /// **'Status changed from {from} to {to}'**
  String ordersTimelineStatusChanged(String from, String to);

  /// No description provided for @ordersNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get ordersNotesTitle;

  /// No description provided for @ordersNotesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes yet.'**
  String get ordersNotesEmpty;

  /// No description provided for @ordersCustomerNote.
  ///
  /// In en, this message translates to:
  /// **'Customer note'**
  String get ordersCustomerNote;

  /// No description provided for @ordersInternalNote.
  ///
  /// In en, this message translates to:
  /// **'Internal note'**
  String get ordersInternalNote;

  /// No description provided for @ordersInternalBadge.
  ///
  /// In en, this message translates to:
  /// **'Internal'**
  String get ordersInternalBadge;

  /// No description provided for @ordersOpenConversation.
  ///
  /// In en, this message translates to:
  /// **'Open conversation'**
  String get ordersOpenConversation;

  /// No description provided for @ordersOpenDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get ordersOpenDetails;

  /// No description provided for @ordersUpdateStatus.
  ///
  /// In en, this message translates to:
  /// **'Update status'**
  String get ordersUpdateStatus;

  /// No description provided for @ordersChangeStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Change status'**
  String get ordersChangeStatusTitle;

  /// No description provided for @ordersStatusNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note for the customer (optional)'**
  String get ordersStatusNoteHint;

  /// No description provided for @ordersStatusNoTransitions.
  ///
  /// In en, this message translates to:
  /// **'This order cannot change status anymore.'**
  String get ordersStatusNoTransitions;

  /// No description provided for @ordersStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'Status updated.'**
  String get ordersStatusChanged;

  /// No description provided for @ordersAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get ordersAddNote;

  /// No description provided for @ordersNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Write a note'**
  String get ordersNoteHint;

  /// No description provided for @ordersNoteInternalToggle.
  ///
  /// In en, this message translates to:
  /// **'Internal note (hidden from the customer)'**
  String get ordersNoteInternalToggle;

  /// No description provided for @ordersNoteAdded.
  ///
  /// In en, this message translates to:
  /// **'Note added.'**
  String get ordersNoteAdded;

  /// No description provided for @ordersNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Write a note first.'**
  String get ordersNoteRequired;

  /// No description provided for @ordersActionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get ordersActionSave;

  /// No description provided for @ordersActionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ordersActionCancel;

  /// No description provided for @ordersRecordSale.
  ///
  /// In en, this message translates to:
  /// **'Record Sale'**
  String get ordersRecordSale;

  /// No description provided for @ordersRecordSaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Record a sale'**
  String get ordersRecordSaleTitle;

  /// No description provided for @ordersFieldCustomerNote.
  ///
  /// In en, this message translates to:
  /// **'Note for the customer'**
  String get ordersFieldCustomerNote;

  /// No description provided for @ordersFieldInternalNote.
  ///
  /// In en, this message translates to:
  /// **'Internal note (only you)'**
  String get ordersFieldInternalNote;

  /// No description provided for @ordersSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get ordersSummaryTitle;

  /// Record Sale summary line.
  ///
  /// In en, this message translates to:
  /// **'{quantity} × {price} = {total}'**
  String ordersSummaryLine(int quantity, String price, String total);

  /// No description provided for @ordersConfirmRecord.
  ///
  /// In en, this message translates to:
  /// **'Confirm and record'**
  String get ordersConfirmRecord;

  /// No description provided for @ordersSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get ordersSubmitting;

  /// No description provided for @ordersRetryRecord.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get ordersRetryRecord;

  /// Snackbar after a sale was recorded.
  ///
  /// In en, this message translates to:
  /// **'Sale recorded as {orderNumber}.'**
  String ordersRecordedSuccess(String orderNumber);

  /// Snackbar when the server returned the existing order.
  ///
  /// In en, this message translates to:
  /// **'This sale was already recorded as {orderNumber}.'**
  String ordersAlreadyRecorded(String orderNumber);

  /// No description provided for @ordersCurrencyAutoNote.
  ///
  /// In en, this message translates to:
  /// **'The currency of the product is applied automatically.'**
  String get ordersCurrencyAutoNote;

  /// No description provided for @ordersValidationQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 1 to 100000.'**
  String get ordersValidationQuantity;

  /// No description provided for @ordersValidationPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a price above 0 with up to 2 decimals.'**
  String get ordersValidationPrice;

  /// No description provided for @ordersErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get ordersErrorNetwork;

  /// No description provided for @ordersErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get ordersErrorGeneric;

  /// No description provided for @ordersErrorSafeRetry.
  ///
  /// In en, this message translates to:
  /// **'Trying again will not create a duplicate order.'**
  String get ordersErrorSafeRetry;

  /// Fallback product name when the real name is not loaded.
  ///
  /// In en, this message translates to:
  /// **'Product #{id}'**
  String ordersProductFallback(int id);

  /// No description provided for @ordersDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get ordersDetailsTitle;

  /// No description provided for @ordersNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found.'**
  String get ordersNotFound;

  /// No description provided for @ordersConversationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open the conversation.'**
  String get ordersConversationUnavailable;

  /// No description provided for @analyticsContentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No posts or reels found for this period and filter.'**
  String get analyticsContentEmpty;

  /// No description provided for @analyticsContentExternalInDetails.
  ///
  /// In en, this message translates to:
  /// **'External platform numbers are shown in the details.'**
  String get analyticsContentExternalInDetails;

  /// No description provided for @analyticsContentExternalNote.
  ///
  /// In en, this message translates to:
  /// **'Entered manually by you. These numbers are not synced with Instagram, Facebook or TikTok.'**
  String get analyticsContentExternalNote;

  /// No description provided for @analyticsContentExternalTitle.
  ///
  /// In en, this message translates to:
  /// **'External platforms (manual)'**
  String get analyticsContentExternalTitle;

  /// No description provided for @analyticsContentInAppNote.
  ///
  /// In en, this message translates to:
  /// **'Counted inside the app only. In-app shares do not prove any external view.'**
  String get analyticsContentInAppNote;

  /// No description provided for @analyticsContentInternalTitle.
  ///
  /// In en, this message translates to:
  /// **'In-app numbers'**
  String get analyticsContentInternalTitle;

  /// No description provided for @analyticsContentLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the analytics of this content. Try again.'**
  String get analyticsContentLoadError;

  /// No description provided for @analyticsContentMetricComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get analyticsContentMetricComments;

  /// No description provided for @analyticsContentMetricEngagementRate.
  ///
  /// In en, this message translates to:
  /// **'Engagement rate'**
  String get analyticsContentMetricEngagementRate;

  /// No description provided for @analyticsContentMetricInAppShares.
  ///
  /// In en, this message translates to:
  /// **'In-app shares'**
  String get analyticsContentMetricInAppShares;

  /// No description provided for @analyticsContentMetricLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get analyticsContentMetricLikes;

  /// No description provided for @analyticsContentNoCaption.
  ///
  /// In en, this message translates to:
  /// **'No caption'**
  String get analyticsContentNoCaption;

  /// No description provided for @analyticsContentOpenDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get analyticsContentOpenDetails;

  /// No description provided for @analyticsContentOrderHighestEngagement.
  ///
  /// In en, this message translates to:
  /// **'Highest engagement'**
  String get analyticsContentOrderHighestEngagement;

  /// No description provided for @analyticsContentOrderMostLiked.
  ///
  /// In en, this message translates to:
  /// **'Most liked'**
  String get analyticsContentOrderMostLiked;

  /// No description provided for @analyticsContentOrderMostSaved.
  ///
  /// In en, this message translates to:
  /// **'Most saved'**
  String get analyticsContentOrderMostSaved;

  /// No description provided for @analyticsContentOrderMostShared.
  ///
  /// In en, this message translates to:
  /// **'Most shared'**
  String get analyticsContentOrderMostShared;

  /// No description provided for @analyticsContentOrderMostViewed.
  ///
  /// In en, this message translates to:
  /// **'Most viewed'**
  String get analyticsContentOrderMostViewed;

  /// No description provided for @analyticsContentOrderNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get analyticsContentOrderNewest;

  /// No description provided for @analyticsContentTrendInteractions.
  ///
  /// In en, this message translates to:
  /// **'Interactions'**
  String get analyticsContentTrendInteractions;

  /// No description provided for @analyticsContentTypeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get analyticsContentTypeAll;

  /// No description provided for @analyticsContentTypePost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get analyticsContentTypePost;

  /// No description provided for @analyticsContentTypePosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get analyticsContentTypePosts;

  /// No description provided for @analyticsContentTypeReel.
  ///
  /// In en, this message translates to:
  /// **'Reel'**
  String get analyticsContentTypeReel;

  /// No description provided for @analyticsContentTypeReels.
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get analyticsContentTypeReels;

  /// No description provided for @analyticsExternalAddUpdate.
  ///
  /// In en, this message translates to:
  /// **'Add or update numbers'**
  String get analyticsExternalAddUpdate;

  /// No description provided for @analyticsExternalBadgeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get analyticsExternalBadgeManual;

  /// No description provided for @analyticsExternalBadgeSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get analyticsExternalBadgeSynced;

  /// No description provided for @analyticsExternalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No external numbers entered yet.'**
  String get analyticsExternalEmpty;

  /// No description provided for @analyticsExternalFormMetric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get analyticsExternalFormMetric;

  /// No description provided for @analyticsExternalFormNote.
  ///
  /// In en, this message translates to:
  /// **'Enter the number you see on the platform. It is saved as a manual entry.'**
  String get analyticsExternalFormNote;

  /// No description provided for @analyticsExternalFormPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get analyticsExternalFormPlatform;

  /// No description provided for @analyticsExternalFormReference.
  ///
  /// In en, this message translates to:
  /// **'Reference (optional)'**
  String get analyticsExternalFormReference;

  /// No description provided for @analyticsExternalFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get analyticsExternalFormSave;

  /// No description provided for @analyticsExternalFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Add external numbers'**
  String get analyticsExternalFormTitle;

  /// No description provided for @analyticsExternalFormValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get analyticsExternalFormValue;

  /// No description provided for @analyticsExternalIntro.
  ///
  /// In en, this message translates to:
  /// **'Numbers from Instagram, Facebook and TikTok that you enter yourself. Nothing is synced automatically.'**
  String get analyticsExternalIntro;

  /// Last update time of one external metric.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String analyticsExternalLastUpdated(String date);

  /// No description provided for @analyticsExternalLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the external numbers. Try again.'**
  String get analyticsExternalLoadError;

  /// No description provided for @analyticsExternalMetricLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get analyticsExternalMetricLikes;

  /// No description provided for @analyticsExternalMetricSaves.
  ///
  /// In en, this message translates to:
  /// **'Saves'**
  String get analyticsExternalMetricSaves;

  /// No description provided for @analyticsExternalMetricShares.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get analyticsExternalMetricShares;

  /// No description provided for @analyticsExternalMetricViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get analyticsExternalMetricViews;

  /// No description provided for @analyticsExternalPlatformFacebook.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get analyticsExternalPlatformFacebook;

  /// No description provided for @analyticsExternalPlatformInstagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get analyticsExternalPlatformInstagram;

  /// No description provided for @analyticsExternalPlatformTiktok.
  ///
  /// In en, this message translates to:
  /// **'TikTok'**
  String get analyticsExternalPlatformTiktok;

  /// The optional reference the merchant typed for an external metric.
  ///
  /// In en, this message translates to:
  /// **'Reference: {reference}'**
  String analyticsExternalReference(String reference);

  /// No description provided for @analyticsExternalSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get analyticsExternalSaveError;

  /// No description provided for @analyticsExternalSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get analyticsExternalSaved;

  /// No description provided for @analyticsExternalSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Source: entered manually'**
  String get analyticsExternalSourceManual;

  /// No description provided for @analyticsExternalSourceSynced.
  ///
  /// In en, this message translates to:
  /// **'Source: synced from the platform'**
  String get analyticsExternalSourceSynced;

  /// No description provided for @analyticsExternalValueInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number, 0 or more.'**
  String get analyticsExternalValueInvalid;

  /// No description provided for @analyticsProdEmpty.
  ///
  /// In en, this message translates to:
  /// **'No products with analytics in this period.'**
  String get analyticsProdEmpty;

  /// No description provided for @analyticsProdFunnelTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversion funnel'**
  String get analyticsProdFunnelTitle;

  /// No description provided for @analyticsProdInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive product'**
  String get analyticsProdInactive;

  /// A metric label followed by its value.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String analyticsProdLabelValue(String label, String value);

  /// No description provided for @analyticsProdLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the analytics of this product. Try again.'**
  String get analyticsProdLoadError;

  /// No description provided for @analyticsProdLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get analyticsProdLoadMore;

  /// No description provided for @analyticsProdMetricAverageOrderValue.
  ///
  /// In en, this message translates to:
  /// **'Average order value'**
  String get analyticsProdMetricAverageOrderValue;

  /// No description provided for @analyticsProdMetricConversion.
  ///
  /// In en, this message translates to:
  /// **'Conversion'**
  String get analyticsProdMetricConversion;

  /// No description provided for @analyticsProdMetricInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get analyticsProdMetricInterests;

  /// No description provided for @analyticsProdMetricOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get analyticsProdMetricOrders;

  /// No description provided for @analyticsProdMetricSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get analyticsProdMetricSales;

  /// No description provided for @analyticsProdMetricSaves.
  ///
  /// In en, this message translates to:
  /// **'Saves'**
  String get analyticsProdMetricSaves;

  /// No description provided for @analyticsProdMetricSoldOrders.
  ///
  /// In en, this message translates to:
  /// **'Sold orders'**
  String get analyticsProdMetricSoldOrders;

  /// No description provided for @analyticsProdMetricUniqueViews.
  ///
  /// In en, this message translates to:
  /// **'Unique views'**
  String get analyticsProdMetricUniqueViews;

  /// No description provided for @analyticsProdMetricUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get analyticsProdMetricUnits;

  /// No description provided for @analyticsProdMetricViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get analyticsProdMetricViews;

  /// No description provided for @analyticsProdNoBusiness.
  ///
  /// In en, this message translates to:
  /// **'No business profile found for this account.'**
  String get analyticsProdNoBusiness;

  /// No description provided for @analyticsProdNoSales.
  ///
  /// In en, this message translates to:
  /// **'No sales in this period.'**
  String get analyticsProdNoSales;

  /// No description provided for @analyticsProdOpenOrders.
  ///
  /// In en, this message translates to:
  /// **'Open orders'**
  String get analyticsProdOpenOrders;

  /// No description provided for @analyticsProdOrderBestSelling.
  ///
  /// In en, this message translates to:
  /// **'Best selling'**
  String get analyticsProdOrderBestSelling;

  /// No description provided for @analyticsProdOrderHighestConversion.
  ///
  /// In en, this message translates to:
  /// **'Highest conversion'**
  String get analyticsProdOrderHighestConversion;

  /// No description provided for @analyticsProdOrderLowestConversion.
  ///
  /// In en, this message translates to:
  /// **'Lowest conversion'**
  String get analyticsProdOrderLowestConversion;

  /// No description provided for @analyticsProdOrderMostInterested.
  ///
  /// In en, this message translates to:
  /// **'Most interested'**
  String get analyticsProdOrderMostInterested;

  /// No description provided for @analyticsProdOrderMostOrdered.
  ///
  /// In en, this message translates to:
  /// **'Most ordered'**
  String get analyticsProdOrderMostOrdered;

  /// No description provided for @analyticsProdOrderMostViewed.
  ///
  /// In en, this message translates to:
  /// **'Most viewed'**
  String get analyticsProdOrderMostViewed;

  /// No description provided for @analyticsProdOrdersLinkNote.
  ///
  /// In en, this message translates to:
  /// **'Opens all your orders. Filtering orders by product is not available.'**
  String get analyticsProdOrdersLinkNote;

  /// When the orders data of a product was last updated.
  ///
  /// In en, this message translates to:
  /// **'Orders updated {date}'**
  String analyticsProdOrdersUpdatedAt(String date);

  /// A rate as a percentage; the number is already formatted.
  ///
  /// In en, this message translates to:
  /// **'{rate}%'**
  String analyticsProdRateValue(String rate);

  /// Sales line of one currency for a product; both numbers are already formatted.
  ///
  /// In en, this message translates to:
  /// **'Sold orders: {orders} · Units: {units}'**
  String analyticsProdSalesLine(String orders, String units);

  /// No description provided for @analyticsProdSalesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales by currency'**
  String get analyticsProdSalesTitle;

  /// No description provided for @analyticsProdTotalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get analyticsProdTotalsTitle;

  /// No description provided for @analyticsProdTrendNoData.
  ///
  /// In en, this message translates to:
  /// **'No trend data for this period.'**
  String get analyticsProdTrendNoData;

  /// No description provided for @analyticsProdTrendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily trends'**
  String get analyticsProdTrendsTitle;

  /// When the analytics data was last updated.
  ///
  /// In en, this message translates to:
  /// **'Data updated {date}'**
  String analyticsProdUpdatedAt(String date);

  /// No description provided for @analyticsProdViewsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Views are not complete for this period, so rates that depend on views are not shown.'**
  String get analyticsProdViewsIncomplete;

  /// No description provided for @analyticsProdViewsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'View data is not available for this period.'**
  String get analyticsProdViewsUnavailable;

  /// Screen-reader summary of a chart.
  ///
  /// In en, this message translates to:
  /// **'{title}, period in days: {days}'**
  String biChartSemantics(String title, int days);

  /// No description provided for @biComparedWithPrevious.
  ///
  /// In en, this message translates to:
  /// **'Compared with the previous period'**
  String get biComparedWithPrevious;

  /// No description provided for @biDataNeverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Data has not been updated yet.'**
  String get biDataNeverUpdated;

  /// When the analytics data was last updated.
  ///
  /// In en, this message translates to:
  /// **'Data updated {date}'**
  String biDataUpdatedAt(String date);

  /// No description provided for @biErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get biErrorNetwork;

  /// No description provided for @biFunnelCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get biFunnelCompleted;

  /// No description provided for @biFunnelConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get biFunnelConfirmed;

  /// Conversion rate between two funnel stages; the percentage is already formatted.
  ///
  /// In en, this message translates to:
  /// **'{rate} conversion'**
  String biFunnelConversion(String rate);

  /// Share lost between two funnel stages; the percentage is already formatted.
  ///
  /// In en, this message translates to:
  /// **'{rate} lost'**
  String biFunnelDrop(String rate);

  /// No description provided for @biFunnelInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get biFunnelInterests;

  /// No description provided for @biFunnelOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get biFunnelOrders;

  /// Overall funnel conversion; the percentage is already formatted.
  ///
  /// In en, this message translates to:
  /// **'Overall conversion: {rate}'**
  String biFunnelOverall(String rate);

  /// No description provided for @biFunnelTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversion funnel'**
  String get biFunnelTitle;

  /// No description provided for @biFunnelUnitsNote.
  ///
  /// In en, this message translates to:
  /// **'Views are unique views. Interests, orders, confirmed and completed count each customer once.'**
  String get biFunnelUnitsNote;

  /// No description provided for @biFunnelViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get biFunnelViews;

  /// No description provided for @biGroupContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get biGroupContent;

  /// No description provided for @biGroupOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get biGroupOrders;

  /// No description provided for @biGroupProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get biGroupProducts;

  /// No description provided for @biKpiAov.
  ///
  /// In en, this message translates to:
  /// **'Average order value'**
  String get biKpiAov;

  /// No description provided for @biKpiComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get biKpiComments;

  /// No description provided for @biKpiCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed orders'**
  String get biKpiCompleted;

  /// No description provided for @biKpiConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed orders'**
  String get biKpiConfirmed;

  /// No description provided for @biKpiContentViews.
  ///
  /// In en, this message translates to:
  /// **'Content views'**
  String get biKpiContentViews;

  /// No description provided for @biKpiInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get biKpiInterests;

  /// No description provided for @biKpiLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get biKpiLikes;

  /// No description provided for @biKpiOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get biKpiOrders;

  /// No description provided for @biKpiProductUniqueViews.
  ///
  /// In en, this message translates to:
  /// **'Product unique views'**
  String get biKpiProductUniqueViews;

  /// No description provided for @biKpiProductViews.
  ///
  /// In en, this message translates to:
  /// **'Product views'**
  String get biKpiProductViews;

  /// No description provided for @biKpiSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get biKpiSales;

  /// No description provided for @biKpiSaves.
  ///
  /// In en, this message translates to:
  /// **'Saves'**
  String get biKpiSaves;

  /// No description provided for @biKpiShares.
  ///
  /// In en, this message translates to:
  /// **'In-app shares'**
  String get biKpiShares;

  /// No description provided for @biLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the analytics. Try again.'**
  String get biLoadFailed;

  /// No description provided for @biNoBusiness.
  ///
  /// In en, this message translates to:
  /// **'No business profile found for this account.'**
  String get biNoBusiness;

  /// No description provided for @biNoPreviousData.
  ///
  /// In en, this message translates to:
  /// **'No previous data'**
  String get biNoPreviousData;

  /// No description provided for @biNoSalesInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No sales in this period.'**
  String get biNoSalesInPeriod;

  /// No description provided for @biOrdersByStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders by status'**
  String get biOrdersByStatusTitle;

  /// No description provided for @biOrdersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No orders in this period.'**
  String get biOrdersEmpty;

  /// No description provided for @biOrdersOverTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders over time'**
  String get biOrdersOverTimeTitle;

  /// No description provided for @biOrdersTotal.
  ///
  /// In en, this message translates to:
  /// **'Total orders'**
  String get biOrdersTotal;

  /// When the orders data was last updated.
  ///
  /// In en, this message translates to:
  /// **'Orders updated {date}'**
  String biOrdersUpdatedAt(String date);

  /// No description provided for @biPeriodNote.
  ///
  /// In en, this message translates to:
  /// **'Dates are in UTC. Today is not included because it has no daily rollup yet.'**
  String get biPeriodNote;

  /// The selected period: first and last day, already formatted.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String biPeriodRange(String start, String end);

  /// No description provided for @biPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get biPresetCustom;

  /// No description provided for @biPresetLast14.
  ///
  /// In en, this message translates to:
  /// **'14 days'**
  String get biPresetLast14;

  /// No description provided for @biPresetLast30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get biPresetLast30;

  /// No description provided for @biPresetLast7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get biPresetLast7;

  /// No description provided for @biPresetLast90.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get biPresetLast90;

  /// No description provided for @biPresetPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get biPresetPreviousMonth;

  /// No description provided for @biPresetThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get biPresetThisMonth;

  /// Snackbar when the picked custom range is longer than the maximum.
  ///
  /// In en, this message translates to:
  /// **'The range can be at most {days} days.'**
  String biRangeTooLong(int days);

  /// No description provided for @biRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get biRefresh;

  /// Title of the sales chart of one currency.
  ///
  /// In en, this message translates to:
  /// **'Sales over time ({currency})'**
  String biRevenueOverTimeTitle(String currency);

  /// No description provided for @biSalesDefinition.
  ///
  /// In en, this message translates to:
  /// **'Sales value = confirmed, processing, shipped and delivered orders. Pending and cancelled orders are not counted.'**
  String get biSalesDefinition;

  /// No description provided for @biSalesDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'These are sales you recorded, not collected payments.'**
  String get biSalesDisclaimer;

  /// No description provided for @biSeriesOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get biSeriesOrders;

  /// No description provided for @biSeriesSoldOrders.
  ///
  /// In en, this message translates to:
  /// **'Sold orders'**
  String get biSeriesSoldOrders;

  /// No description provided for @biStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get biStatusCancelled;

  /// No description provided for @biStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get biStatusConfirmed;

  /// No description provided for @biStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get biStatusDelivered;

  /// No description provided for @biStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get biStatusPending;

  /// No description provided for @biStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get biStatusProcessing;

  /// No description provided for @biStatusShipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get biStatusShipped;

  /// No description provided for @biStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get biStatusUnknown;

  /// No description provided for @biTabContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get biTabContent;

  /// No description provided for @biTabExternal.
  ///
  /// In en, this message translates to:
  /// **'External'**
  String get biTabExternal;

  /// No description provided for @biTabOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders & sales'**
  String get biTabOrders;

  /// No description provided for @biTabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get biTabOverview;

  /// No description provided for @biTabProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get biTabProducts;

  /// Second line of a top product row; both numbers are already formatted.
  ///
  /// In en, this message translates to:
  /// **'Sold orders: {orders} · Units: {units}'**
  String biTopProductSub(String orders, String units);

  /// No description provided for @biTopProductsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sold products in this period.'**
  String get biTopProductsEmpty;

  /// No description provided for @biTopProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Top products'**
  String get biTopProductsTitle;

  /// No description provided for @biTotalSales.
  ///
  /// In en, this message translates to:
  /// **'Total sales'**
  String get biTotalSales;

  /// No description provided for @biUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get biUnits;

  /// No description provided for @biViewsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Views are not complete for this period. Rates that depend on views and the previous-period comparison are not shown.'**
  String get biViewsIncomplete;

  /// No description provided for @biViewsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'View data is not available for this period.'**
  String get biViewsUnavailable;
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
