// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get hubEditMyProfile => 'Edit profile';

  @override
  String get editProfileTitle => 'Edit my profile';

  @override
  String get editProfileNameLabel => 'Display name';

  @override
  String get editProfileNameTooLong => 'Display name must be 80 characters or fewer.';

  @override
  String get editProfilePhotoSemantic => 'Profile photo. Tap to change.';

  @override
  String get editProfilePickFromGallery => 'Choose from gallery';

  @override
  String get editProfileRemovePhoto => 'Remove photo';

  @override
  String get editProfileSave => 'Save changes';

  @override
  String get editProfileNoChanges => 'No changes to save.';

  @override
  String get editProfileSaved => 'Profile updated.';

  @override
  String get editProfilePhotoUnsupported => 'Choose a JPEG, PNG or WebP image.';

  @override
  String editProfilePhotoTooLarge(int maxMb) {
    return 'Photo is too large (max $maxMb MB).';
  }

  @override
  String get editProfilePhotoPickFailed => 'Could not open the photo. Please try again.';

  @override
  String get editProfileAvatarRejected => 'The server could not accept this photo. Try a different one.';

  @override
  String get editProfileNameRejected => 'The server could not accept this display name.';

  @override
  String get editProfileLoadingLabel => 'Loading your profile';

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
  String get errorSubscriptionRequired => 'Your subscription has ended. Renew your plan to continue.';

  @override
  String get errorStorageQuotaExceeded => 'You have used all of your storage. Upgrade your plan or delete some files to continue.';

  @override
  String get errorDowngradeBlockedUsage => 'You are using more storage than this plan includes. Free up space before switching to it.';

  @override
  String get errorDowngradeAlreadyPending => 'A plan change is already scheduled for the end of your current period.';

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

  @override
  String get authLoginTitle => 'Login';

  @override
  String get authRegisterTitle => 'Register';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authAccountTypeLabel => 'Account type';

  @override
  String get authAccountTypeCustomer => 'Customer';

  @override
  String get authAccountTypeBusiness => 'Business';

  @override
  String get authLoginButton => 'Log in';

  @override
  String get authRegisterButton => 'Create account';

  @override
  String get authGoToRegister => 'Don\'t have an account? Register';

  @override
  String get authGoToLogin => 'Already have an account? Log in';

  @override
  String get authEmailRequired => 'Email is required.';

  @override
  String get authEmailInvalid => 'Enter a valid email address.';

  @override
  String get authPasswordRequired => 'Password is required.';

  @override
  String get authConfirmPasswordRequired => 'Please confirm your password.';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match.';

  @override
  String get authInvalidCredentials => 'Invalid email or password.';

  @override
  String get authAutoLoginFailed => 'Account created, but automatic sign-in failed. Please log in.';

  @override
  String get authFieldErrorEmail => 'This email address cannot be used. Please check it or try another one.';

  @override
  String get authFieldErrorPassword => 'This password cannot be used. Please choose a different one.';

  @override
  String get authFieldErrorPasswordConfirm => 'The passwords you entered do not match.';

  @override
  String get authFieldErrorAccountType => 'Please choose a valid account type.';

  @override
  String get commonRetry => 'Retry';

  @override
  String get splashLoading => 'Loading...';

  @override
  String get splashGoToLogin => 'Go to login';

  @override
  String get routeErrorTitle => 'Page not found';

  @override
  String get routeErrorMessage => 'The page you are looking for does not exist or has moved.';

  @override
  String get routeErrorGoHome => 'Back to home';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navSaved => 'Saved';

  @override
  String get navCreate => 'Create';

  @override
  String get navModeration => 'Moderation';

  @override
  String get navChats => 'Chats';

  @override
  String get navProfile => 'Profile';

  @override
  String get hubTitle => 'Profile & Settings';

  @override
  String get hubAccountTypeCustomer => 'Customer';

  @override
  String get hubAccountTypeBusiness => 'Business';

  @override
  String get hubAccountTypeStaff => 'Staff';

  @override
  String get hubSaved => 'Saved';

  @override
  String get hubNotificationPreferences => 'Notification preferences';

  @override
  String get hubSettingsGroup => 'Settings';

  @override
  String get hubAppearance => 'Appearance';

  @override
  String get hubAppearanceSystem => 'System';

  @override
  String get hubAppearanceLight => 'Light';

  @override
  String get hubAppearanceDark => 'Dark';

  @override
  String get hubLanguage => 'Language';

  @override
  String get hubBusinessTools => 'Business tools';

  @override
  String get hubBusinessConsole => 'Business console';

  @override
  String get hubEditBusinessProfile => 'Edit business profile';

  @override
  String get hubProducts => 'Products';

  @override
  String get hubContent => 'Content';

  @override
  String get hubStories => 'Stories';

  @override
  String get hubAnalytics => 'Analytics';

  @override
  String get hubFeaturedStatus => 'Featured status';

  @override
  String get hubFeaturedNo => 'Not featured';

  @override
  String get hubModeration => 'Moderation';

  @override
  String get hubModerationQueue => 'Moderation queue';

  @override
  String get hubAbout => 'About';

  @override
  String get aboutAppName => 'Cavallo';

  @override
  String get aboutDescription => 'Cavallo is a social commerce app that connects traders and factories with customers. Share reels, posts and stories, discover products and businesses, and chat directly to get deals done, all in one place.';

  @override
  String get aboutDevelopedBy => 'Developed by Eng. Ahmed Ibrahim';

  @override
  String get aboutClose => 'Close';

  @override
  String get hubLogOut => 'Log out';

  @override
  String get hubLogOutConfirmTitle => 'Log out?';

  @override
  String get hubLogOutConfirmMessage => 'You will need to sign in again to use your account.';

  @override
  String get hubCancel => 'Cancel';

  @override
  String get savedTabPosts => 'Posts';

  @override
  String get savedTabReels => 'Reels';

  @override
  String get savedTabProducts => 'Products';

  @override
  String get savedEmptyPosts => 'No saved posts yet. Tap the bookmark on a post to keep it here.';

  @override
  String get savedEmptyReels => 'No saved reels yet. Tap the bookmark on a reel to keep it here.';

  @override
  String get savedEmptyProducts => 'No saved products yet. Tap the bookmark on a product to keep it here.';

  @override
  String get savedUnsave => 'Remove from saved';

  @override
  String get savedUnavailable => 'This item is no longer available';

  @override
  String get savedNoPreviewText => 'Saved item';

  @override
  String get savedUnsaveFailed => 'Couldn\'t remove it from saved. Please try again.';

  @override
  String get savedLoadMoreFailed => 'Couldn\'t load more saved items.';

  @override
  String get createSheetTitle => 'Create new';

  @override
  String get createSheetPost => 'Post';

  @override
  String get createSheetReel => 'Reel';

  @override
  String get createSheetStory => 'Story';

  @override
  String get createSheetProduct => 'Product';

  @override
  String get homeWordmark => 'Cavallo';

  @override
  String get homeNotificationsTooltip => 'Notifications';

  @override
  String get homeChatsTooltip => 'Chats';

  @override
  String get discoverSearchHint => 'Search businesses, products and posts';

  @override
  String get storyYourStory => 'Your story';

  @override
  String get storyAddTooltip => 'Add to your story';

  @override
  String storyRingNewLabel(String name) {
    return '$name, new story';
  }

  @override
  String storyRingSeenLabel(String name) {
    return '$name, story seen';
  }

  @override
  String get storyViewerClose => 'Close';

  @override
  String get storyViewerNotFound => 'Story not found.';

  @override
  String get storyViewerEmpty => 'No stories to show right now.';

  @override
  String get storyViewerLoadFailed => 'Could not load stories.';

  @override
  String get storyViewerDefaultName => 'Business';

  @override
  String get businessUnknownName => 'Unknown business';

  @override
  String get captionMore => 'more';

  @override
  String get actionLike => 'Like';

  @override
  String get actionComment => 'Comment';

  @override
  String get actionShare => 'Share';

  @override
  String get actionSave => 'Save';

  @override
  String feedLikesLine(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted likes',
      one: '$formatted like',
    );
    return '$_temp0';
  }

  @override
  String feedViewAllComments(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'View all $formatted comments',
      one: 'View 1 comment',
    );
    return '$_temp0';
  }

  @override
  String get feedVerifiedLabel => 'Verified';

  @override
  String feedPostMediaLabel(String name) {
    return 'Post by $name';
  }

  @override
  String feedReelMediaLabel(String name) {
    return 'Reel by $name';
  }

  @override
  String get feedEmptyMessage => 'Your feed is empty right now.\nFollow some businesses, or check back soon.';

  @override
  String get feedLoadFailed => 'Could not load your feed.';

  @override
  String get feedLoadingLabel => 'Loading your feed';

  @override
  String get profileScreenTitle => 'Business';

  @override
  String get profileStatPosts => 'Posts';

  @override
  String get profileStatFollowers => 'Followers';

  @override
  String get profileStatProducts => 'Products';

  @override
  String get profileTabPosts => 'Posts';

  @override
  String get profileTabReels => 'Reels';

  @override
  String get profileTabProducts => 'Products';

  @override
  String get profileTabInfo => 'Info';

  @override
  String get followButtonFollow => 'Follow';

  @override
  String get followButtonFollowing => 'Following';

  @override
  String followersCountLine(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted followers',
      one: '$formatted follower',
    );
    return '$_temp0';
  }

  @override
  String get profileMessageButton => 'Message';

  @override
  String get profileMessageStarted => 'Conversation started. Open it from Messages.';

  @override
  String get profileMessageFailed => 'Could not start the conversation. Please try again.';

  @override
  String get profileNotFound => 'Business not found.\nIt may have been removed.';

  @override
  String get profileLoadFailed => 'Could not load this business profile.';

  @override
  String get profileNoDescription => 'This business hasn\'t added a description yet.';

  @override
  String profileLocation(String city, String country) {
    return '$city, $country';
  }

  @override
  String get businessTypeTrader => 'Trader';

  @override
  String get businessTypeFactory => 'Factory';

  @override
  String get profilePostsEmpty => 'This business hasn\'t shared any posts yet.';

  @override
  String get profilePostsLoadFailed => 'Could not load this business\'s posts.';

  @override
  String get profileReelsEmpty => 'This business hasn\'t shared any reels yet.';

  @override
  String get profileReelsLoadFailed => 'Could not load this business\'s reels.';

  @override
  String get profileProductsEmpty => 'This business hasn\'t added any products yet.';

  @override
  String get profileProductsLoadFailed => 'Could not load this business\'s products.';

  @override
  String get profileInfoType => 'Business type';

  @override
  String get profileInfoLocation => 'Location';

  @override
  String get profileInfoPhone => 'Phone';

  @override
  String get profileGridLoadingLabel => 'Loading content';

  @override
  String get featuredBadgeLabel => 'Featured';

  @override
  String get searchFieldHint => 'Search traders, factories, products...';

  @override
  String get searchClearTooltip => 'Clear search';

  @override
  String get searchFiltersChip => 'Filters';

  @override
  String searchFiltersChipActive(int count) {
    return 'Filters ($count)';
  }

  @override
  String get searchIdlePrompt => 'Search for traders, factories, and products.\nType a keyword or set a filter to get started.';

  @override
  String get searchNoResults => 'No results found. Try a different search or adjust your filters.';

  @override
  String get searchLoadFailed => 'Could not load search results.';

  @override
  String get searchResultsLoadingLabel => 'Loading results';

  @override
  String get discoverEmpty => 'Nothing to discover yet.\nCheck back soon for new businesses.';

  @override
  String get discoverLoadFailed => 'Could not load Discover right now.';

  @override
  String get searchFilterTitle => 'Filters';

  @override
  String get searchFilterCategory => 'Category';

  @override
  String get searchFilterCategoryAll => 'All categories';

  @override
  String get searchFilterCategoriesFailed => 'Could not load categories.';

  @override
  String get searchFilterCountry => 'Country';

  @override
  String get searchFilterCity => 'City';

  @override
  String get searchFilterBusinessType => 'Business type';

  @override
  String get searchFilterAny => 'Any';

  @override
  String get searchFilterMinRating => 'Minimum rating';

  @override
  String searchFilterMinRatingOption(int stars) {
    String _temp0 = intl.Intl.pluralLogic(
      stars,
      locale: localeName,
      other: '$stars stars & up',
      one: '$stars star & up',
    );
    return '$_temp0';
  }

  @override
  String get searchFilterFeaturedOnly => 'Featured only';

  @override
  String get searchFilterClear => 'Clear';

  @override
  String get searchFilterApply => 'Apply';

  @override
  String get productDetailTitle => 'Product';

  @override
  String productPriceHeadline(String price, String currency) {
    return 'Starting from $price $currency';
  }

  @override
  String get productPriceNote => 'Approximate price, negotiable directly with the business. Message the business to confirm.';

  @override
  String get productNotFoundMessage => 'Product not found.\nIt may have been removed.';

  @override
  String get productLoadFailed => 'Could not load this product.';

  @override
  String get productNoDescription => 'This business hasn\'t added a description yet.';

  @override
  String get productVariantsTitle => 'Variants';

  @override
  String get productMessageBusiness => 'Message Business';

  @override
  String productShareText(String name) {
    return 'Check out $name on Cavallo';
  }

  @override
  String get productLoadingLabel => 'Loading product';

  @override
  String get commentsTitle => 'Comments';

  @override
  String get commentsInputHint => 'Add a comment...';

  @override
  String get commentsPostTooltip => 'Post comment';

  @override
  String get commentsEmpty => 'No comments yet. Be the first to comment.';

  @override
  String get commentsPendingReview => 'Pending review: hidden from other users';

  @override
  String get commentsLoadMore => 'Load more comments';

  @override
  String commentsAuthorFallback(String id) {
    return 'User #$id';
  }

  @override
  String get commentsLoadingLabel => 'Loading comments';

  @override
  String get chatListTitle => 'Messages';

  @override
  String get chatListEmpty => 'No conversations yet';

  @override
  String get chatListNoMessages => 'No messages yet';

  @override
  String get chatListUnknownUser => 'Unknown';

  @override
  String get chatListPreviewPhoto => 'Photo';

  @override
  String get chatListPreviewVideo => 'Video';

  @override
  String get chatListPreviewSharedPost => 'Shared a post';

  @override
  String get chatListPreviewSharedReel => 'Shared a reel';

  @override
  String get chatListPreviewSharedProduct => 'Shared a product';

  @override
  String get chatListLoadingLabel => 'Loading conversations';

  @override
  String get chatListNewChatTest => 'New chat (test)';

  @override
  String get chatListNewChat => 'New chat';

  @override
  String get newChatSheetTitle => 'New chat';

  @override
  String get newChatSheetSubtitle => 'Start a conversation with a business you follow';

  @override
  String get newChatSheetEmpty => 'You are not following any business yet. Follow a business to start chatting with it.';

  @override
  String get newChatOpenFailed => 'Could not open the conversation. Please try again.';

  @override
  String get chatTestDialogTitle => 'Start test conversation';

  @override
  String get chatTestUserIdLabel => 'Other account\'s user id';

  @override
  String get chatTestUserIdHint => 'e.g. 7';

  @override
  String get chatTestCancel => 'Cancel';

  @override
  String get chatTestStart => 'Start';

  @override
  String chatListUnreadLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '$count unread message',
    );
    return '$_temp0';
  }

  @override
  String chatTestUserPlaceholder(int id) {
    return 'User #$id';
  }

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifSettingsTitle => 'Notification settings';

  @override
  String get notifLoadMoreFailed => 'Could not load more notifications.';

  @override
  String get notifLoadFailed => 'Could not load your notifications.';

  @override
  String get notifEmpty => 'No notifications yet.';

  @override
  String get notifSectionToday => 'Today';

  @override
  String get notifSectionThisWeek => 'This week';

  @override
  String get notifSectionEarlier => 'Earlier';

  @override
  String get notifUnreadLabel => 'Unread';

  @override
  String get notifLoadingLabel => 'Loading notifications';

  @override
  String get notifPrefsSectionHeader => 'Notify me about';

  @override
  String get notifPrefChatTitle => 'Chat messages';

  @override
  String get notifPrefChatSubtitle => 'New messages in your conversations.';

  @override
  String get notifPrefModerationTitle => 'Content review';

  @override
  String get notifPrefModerationSubtitle => 'When your content is approved or rejected.';

  @override
  String get notifPrefSocialTitle => 'Social activity';

  @override
  String get notifPrefSocialSubtitle => 'New followers, comments, likes, shares and ratings.';

  @override
  String get notifPrefsSaveFailed => 'Could not save your preference. Please try again.';

  @override
  String get notifPrefsLoadFailed => 'Could not load your notification settings.';

  @override
  String get notifPrefsSystemFooter => 'Important system announcements are always delivered.';

  @override
  String get consoleNavProducts => 'Products';

  @override
  String get consoleNavContent => 'Posts/Reels';

  @override
  String get consoleNavStories => 'Stories';

  @override
  String get consoleNavAnalytics => 'Analytics';

  @override
  String get consoleDashStories => 'Active stories';

  @override
  String get consoleDashFollowers => 'New followers';

  @override
  String consoleDashRange(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'last $days days',
      one: 'last day',
    );
    return '$_temp0';
  }

  @override
  String get consoleDashValueUnavailable => '–';

  @override
  String get consoleProductsTitle => 'My Products';

  @override
  String get consoleProductsCreate => 'Create New';

  @override
  String get consoleProductsEmpty => 'No products yet.\nTap \"Create New\" to add your first product.';

  @override
  String get consoleProductsLoadFailed => 'Could not load your products.';

  @override
  String get consoleProductsDeleteTitle => 'Delete product?';

  @override
  String consoleProductsDeleteBody(String name) {
    return 'This will remove \"$name\" from your products. This cannot be undone.';
  }

  @override
  String get consoleProductsDeleteFailed => 'Could not delete this product.';

  @override
  String consoleProductVariants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count variants',
      one: '$count variant',
    );
    return '$_temp0';
  }

  @override
  String get consoleProductInactive => 'Inactive';

  @override
  String get consoleEdit => 'Edit';

  @override
  String get consoleDelete => 'Delete';

  @override
  String get consoleCancel => 'Cancel';

  @override
  String get consoleContentTitle => 'My Content';

  @override
  String get consoleContentNewPost => 'New Post';

  @override
  String get consoleContentNewReel => 'New Reel';

  @override
  String get consoleContentEmpty => 'No posts or reels yet.\nTap \"New Post\" or \"New Reel\" to share your first one.';

  @override
  String get consoleContentLoadFailed => 'Could not load your content.';

  @override
  String get consoleTypePost => 'Post';

  @override
  String get consoleTypeReel => 'Reel';

  @override
  String get consoleStatusUnderReview => 'Under review';

  @override
  String get consoleStatusLive => 'Live';

  @override
  String consoleStatusRejectedWithReason(String reason) {
    return 'Rejected: $reason';
  }

  @override
  String get consoleStatusNoReasonGiven => 'no reason given';

  @override
  String get consoleStatusProcessing => 'Processing video…';

  @override
  String get consoleStatusProcessingFailed => 'Video processing failed';

  @override
  String get consoleStoriesCreate => 'Create Story';

  @override
  String get consoleStoriesEmpty => 'No stories yet.\nTap \"Create Story\" to share your first one.';

  @override
  String get consoleStoriesLoadFailed => 'Could not load your stories.';

  @override
  String consoleStoryNumber(int id) {
    return 'Story #$id';
  }

  @override
  String get consoleStoryPublished => 'Published';

  @override
  String get consoleStoryPending => 'Pending';

  @override
  String get consoleStoryRejected => 'Rejected';

  @override
  String get consoleStoryExpired => 'Expired';

  @override
  String get consoleStoryUnknown => 'Unknown';

  @override
  String consoleStoryReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String consoleStoryTimeLeftHM(int hours, int minutes) {
    return '${hours}h ${minutes}m left';
  }

  @override
  String consoleStoryTimeLeftM(int minutes) {
    return '${minutes}m left';
  }

  @override
  String get consoleStoryTimeLeftLess => 'Less than 1m left';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get moderationQueueTitle => 'Moderation queue';

  @override
  String get moderationQueueEmpty => 'The queue is clear.\nNothing is waiting for review.';

  @override
  String get moderationNotAllowed => 'Your account is not allowed to review content. If it should be, ask an admin to add it to the Moderator group.';

  @override
  String get moderationQueueLoadFailed => 'Could not load the moderation queue.';

  @override
  String moderationSummaryPending(int count) {
    return '$count pending';
  }

  @override
  String moderationSummaryPendingFast(int count, int fast) {
    return '$count pending · $fast fast path';
  }

  @override
  String get moderationNoPreview => 'No preview available';

  @override
  String get moderationPriorityFast => 'Fast path';

  @override
  String get moderationPriorityNormal => 'Normal';

  @override
  String get moderationAgeUnderMinute => '<1 min';

  @override
  String moderationAgeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String moderationAgeHours(int hours) {
    return '$hours h';
  }

  @override
  String moderationAgeHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String moderationAgeDays(int days) {
    return '$days d';
  }

  @override
  String moderationAgeDaysHours(int days, int hours) {
    return '$days d $hours h';
  }

  @override
  String moderationAgeOverdue(String age) {
    return '$age · overdue';
  }

  @override
  String get moderationContentTypePost => 'Post';

  @override
  String get moderationContentTypeReel => 'Reel';

  @override
  String get moderationContentTypeStory => 'Story';

  @override
  String get moderationContentTypeUnknown => 'Unknown';

  @override
  String get moderationReviewTitle => 'Review content';

  @override
  String get moderationPreview => 'Preview';

  @override
  String get moderationDetailType => 'Type';

  @override
  String get moderationDetailSubmittedBy => 'Submitted by';

  @override
  String get moderationDetailPriority => 'Priority';

  @override
  String get moderationDetailWaiting => 'Waiting';

  @override
  String get moderationDetailQueueItem => 'Queue item';

  @override
  String get moderationWaitingNote => 'Waiting time is as of the last queue refresh.';

  @override
  String get moderationReject => 'Reject';

  @override
  String get moderationApprove => 'Approve';

  @override
  String get moderationItemApproved => 'Item approved';

  @override
  String get moderationItemRejected => 'Item rejected';

  @override
  String get moderationApproveFailed => 'Could not approve this item. Please try again.';

  @override
  String get moderationRejectFailed => 'Could not reject this item. Please try again.';

  @override
  String get moderationAlreadyHandled => 'This item was already handled by someone else, or no longer exists. It has been removed from your queue.';

  @override
  String get moderationRejectTitle => 'Reject content';

  @override
  String get moderationRejectNote => 'The business will see this reason.';

  @override
  String get moderationRejectReasonLabel => 'Reason (required)';

  @override
  String get moderationRejectReasonRequired => 'A reason is required.';

  @override
  String get analyticsLoadFailed => 'Could not load your analytics.';

  @override
  String analyticsEmpty(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'No activity has been recorded for the last $days days yet.',
      one: 'No activity has been recorded for the last day yet.',
    );
    return '$_temp0';
  }

  @override
  String analyticsDaysWithData(int withData, int days) {
    return 'Days with data: $withData of $days';
  }

  @override
  String get analyticsUtcNote => 'Days are counted in UTC. Days without a recorded row are not drawn as zero.';

  @override
  String get analyticsChartFollowersTitle => 'New followers by day';

  @override
  String analyticsChartFollowersSemantics(int days, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'New followers: $total total over $days days',
      one: 'New followers: $total total over 1 day',
    );
    return '$_temp0';
  }

  @override
  String get analyticsChartLikesTitle => 'Likes received by day';

  @override
  String analyticsChartLikesSemantics(int days, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Likes received: $total total over $days days',
      one: 'Likes received: $total total over 1 day',
    );
    return '$_temp0';
  }

  @override
  String get analyticsRatingsHeading => 'Ratings';

  @override
  String get analyticsRatingEmpty => 'No rating has been recorded yet, so there is no rating trend to draw.';

  @override
  String get analyticsChartRatingTitle => 'Average rating by day';

  @override
  String analyticsChartRatingSemantics(int days, String average) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Average rating: latest $average over $days days',
      one: 'Average rating: latest $average over 1 day',
    );
    return '$_temp0';
  }

  @override
  String get analyticsRatingNote => 'Each point is the average rating stored when that day was rolled up. Days before the first rating are not drawn.';

  @override
  String get analyticsCatalogHeading => 'Catalog size';

  @override
  String analyticsCatalogAsOf(int day, int month) {
    return 'As of $day/$month (UTC). These are totals recorded by the daily rollup, not daily changes.';
  }

  @override
  String analyticsRangeDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '$days day',
    );
    return '$_temp0';
  }

  @override
  String get analyticsNewFollowers => 'New followers';

  @override
  String get analyticsLikesReceived => 'Likes received';

  @override
  String get analyticsCommentsReceived => 'Comments received';

  @override
  String get analyticsStoryViews => 'Story views';

  @override
  String get analyticsNewRatings => 'New ratings';

  @override
  String get analyticsAverageRating => 'Average rating';

  @override
  String get analyticsActiveProducts => 'Active products';

  @override
  String get analyticsPublishedPosts => 'Published posts';

  @override
  String get analyticsPublishedReels => 'Published reels';

  @override
  String get bizOnboardTitle => 'Complete your business profile';

  @override
  String get bizFieldName => 'Business name';

  @override
  String get bizFieldPhone => 'Phone number (optional)';

  @override
  String get bizFieldPhoneInvalid => 'Enter a valid phone number for the selected country.';

  @override
  String get bizFieldDescription => 'Description (optional)';

  @override
  String get bizOnboardSubmit => 'Complete profile';

  @override
  String get bizProfileTitle => 'Business profile';

  @override
  String get bizProfileBackHome => 'Back to home';

  @override
  String get bizProfileIncomplete => 'You have not completed your business profile yet.';

  @override
  String get bizProfileNoChanges => 'No changes to save.';

  @override
  String get bizProfileUpdated => 'Business profile updated.';

  @override
  String get bizProfileSave => 'Save changes';

  @override
  String get commonRemove => 'Remove';

  @override
  String get contentPostNotFound => 'Post not found.\nIt may have been removed.';

  @override
  String get contentReelNotFound => 'Reel not found.\nIt may have been removed.';

  @override
  String get contentReelPlaybackSoon => 'Video playback — Coming soon';

  @override
  String get contentFormImageLabel => 'Image (optional)';

  @override
  String get contentFormVideoLabel => 'Video';

  @override
  String get contentFormChooseImage => 'Choose image';

  @override
  String get contentFormChangeImage => 'Change image';

  @override
  String get contentFormChooseVideo => 'Choose video';

  @override
  String get contentFormChangeVideo => 'Change video';

  @override
  String get contentFormCaption => 'Caption';

  @override
  String get postFormTitle => 'New post';

  @override
  String get postFormReviewNote => 'Your post will be reviewed before it becomes visible to customers.';

  @override
  String get postFormSubmit => 'Post';

  @override
  String get reelFormTitle => 'New reel';

  @override
  String get reelFormReviewNote => 'Your video is processed first, then reviewed before it becomes visible to customers. You\'ll see its status on your content list.';

  @override
  String get reelFormSubmit => 'Post reel';

  @override
  String get productFormImageLabel => 'Product image (optional)';

  @override
  String get productFormVariantName => 'Variant name (e.g. Size)';

  @override
  String get productFormVariantValue => 'Value (e.g. Large)';

  @override
  String get productFormRemoveVariant => 'Remove variant';

  @override
  String get productFormAddVariant => 'Add variant';

  @override
  String get productFormName => 'Name';

  @override
  String get productFormDescription => 'Description';

  @override
  String get productFormPrice => 'Price';

  @override
  String get productFormCurrency => 'Currency';

  @override
  String get productFormActive => 'Active (visible to customers)';

  @override
  String get productFormCategoryRequired => 'Category is required.';

  @override
  String get productFormCurrencyRequired => 'Currency is required.';

  @override
  String get socialMoreOptions => 'More options';

  @override
  String get socialReport => 'Report';

  @override
  String get socialReportThanks => 'Thanks, your report was submitted.';

  @override
  String get socialReportWhy => 'Why are you reporting this?';

  @override
  String get socialReportDetails => 'Details (optional)';

  @override
  String get socialReportSubmit => 'Submit';

  @override
  String get socialReasonSpam => 'Spam';

  @override
  String get socialReasonInappropriate => 'Inappropriate content';

  @override
  String get socialReasonMisleading => 'Misleading';

  @override
  String get socialReasonOther => 'Other';

  @override
  String get storyUploadStarted => 'Story upload started.';

  @override
  String get storyNoMediaSelected => 'No photo or video selected yet.';

  @override
  String get storyAddMediaFirst => 'Add a photo or video first.';

  @override
  String get storyAddPhoto => 'Add Photo';

  @override
  String get storyAddVideo => 'Add Video';

  @override
  String get storyPostButton => 'Post Story';

  @override
  String get storyUploadDiscard => 'Discard';

  @override
  String storyUploadUploading(int attempt) {
    return 'Uploading story... (attempt $attempt of 5)';
  }

  @override
  String storyUploadRetrying(int attempt) {
    return 'Connection lost — retrying story upload... (attempt $attempt of 5)';
  }

  @override
  String get storyUploadFailed => 'Story upload failed.';

  @override
  String storyUploadFailedWithReason(String reason) {
    return 'Story upload failed: $reason';
  }

  @override
  String get pushBannerView => 'View';

  @override
  String get validationBusinessNameRequired => 'Business name is required.';

  @override
  String get validationCountryRequired => 'Country is required.';

  @override
  String get validationCityRequired => 'City is required.';

  @override
  String get businessProfileLoadError => 'Could not load your business profile.';

  @override
  String get postLoadError => 'Could not load this post.';

  @override
  String get reelLoadError => 'Could not load this reel.';

  @override
  String get commonGenericError => 'Something went wrong. Please try again.';

  @override
  String get validationCaptionRequired => 'Caption is required.';

  @override
  String get reelVideoRequired => 'A video is required.';

  @override
  String get productFormEditTitle => 'Edit product';

  @override
  String get productFormCreate => 'Create product';

  @override
  String get productFormSaveChanges => 'Save changes';

  @override
  String get validationProductNameRequired => 'Name is required.';

  @override
  String get validationDescriptionRequired => 'Description is required.';

  @override
  String get validationPriceRequired => 'Price is required.';

  @override
  String get validationPriceInvalid => 'Enter a valid price (e.g. 199.99).';

  @override
  String get chatThreadFallbackTitle => 'Chat';

  @override
  String get chatConnectionOnline => 'Online';

  @override
  String get chatConnectionConnecting => 'Connecting…';

  @override
  String get chatConnectionReconnecting => 'Reconnecting…';

  @override
  String get chatConnectionOffline => 'Offline';

  @override
  String get chatThreadTyping => 'typing…';

  @override
  String get chatThreadEmpty => 'No messages yet — say hi!';

  @override
  String get chatComposerHint => 'Message…';

  @override
  String get chatAttachPhoto => 'Photo';

  @override
  String get chatAttachVideo => 'Video';

  @override
  String chatPhotoTooLarge(int maxMb) {
    return 'Photo is too large (max $maxMb MB).';
  }

  @override
  String get chatVideoCannotPlay => 'This video cannot be played here. Its format may not be supported on your device.';

  @override
  String get chatVideoRetry => 'Try again';

  @override
  String get chatVideoOpenExternal => 'Open in another app';

  @override
  String chatVideoTooLarge(int maxMb) {
    return 'Video is too large (max $maxMb MB).';
  }

  @override
  String get chatBubbleRetrying => 'Retrying…';

  @override
  String get chatBubbleFailedTapRetry => 'Failed to send · Tap to retry';

  @override
  String get chatShareVia => 'Share via…';

  @override
  String get chatShareToConversation => 'Share to conversation';

  @override
  String get chatSharePickerEmpty => 'No conversations yet.\nStart one from the Messages tab first.';

  @override
  String get chatSharePickerLoadError => 'Could not load your conversations.';

  @override
  String get chatShareFailed => 'Could not share. Please try again.';

  @override
  String get sharedContentTypePost => 'Post';

  @override
  String get sharedContentTypeReel => 'Reel';

  @override
  String get sharedContentTypeProduct => 'Product';

  @override
  String get sharedContentUnavailable => 'This content is no longer available';

  @override
  String get reelPlayerMute => 'Mute';

  @override
  String get reelPlayerUnmute => 'Unmute';

  @override
  String get reelPlayerError => 'Could not play this video.';

  @override
  String get reelFormUploading => 'Uploading your video... large videos can take a few minutes. Please keep this screen open.';

  @override
  String get bizAvatarAdd => 'Add profile photo';

  @override
  String get bizAvatarChange => 'Change photo';

  @override
  String get bizAvatarRemove => 'Remove photo';

  @override
  String get bizAvatarUpdated => 'Profile photo updated.';

  @override
  String get bizAvatarRemoved => 'Profile photo removed.';

  @override
  String get bizAvatarUploadFailed => 'Could not update the photo. Please try again.';

  @override
  String get bizAvatarUploadLater => 'Your profile was created, but the photo could not be uploaded. You can add it from Edit profile.';

  @override
  String get bizAvatarSemantic => 'Business profile photo';

  @override
  String get authResetEmailTitle => 'Forgot password';

  @override
  String get authResetEmailSubtitle => 'Enter your account email and we will send you a verification code.';

  @override
  String get authResetEmailSubmit => 'Send code';

  @override
  String get authResetOtpTitle => 'Verify your email';

  @override
  String authResetOtpSubtitle(String email) {
    return 'Enter the 6-digit code we sent to $email.';
  }

  @override
  String get authResetOtpLabel => 'Verification code';

  @override
  String get authResetOtpSubmit => 'Verify code';

  @override
  String get authResetOtpRequired => 'Enter the verification code.';

  @override
  String get authResetOtpInvalid => 'This code is invalid or has expired. Check it or request a new code.';

  @override
  String get authResetResendButton => 'Resend code';

  @override
  String authResetResendCooldown(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get authResetResendSent => 'A new code has been sent.';

  @override
  String get authResetChangeEmail => 'Use a different email';

  @override
  String get authResetNewPasswordTitle => 'Set a new password';

  @override
  String get authResetNewPasswordSubtitle => 'Choose a new password for your account.';

  @override
  String get authResetNewPasswordLabel => 'New password';

  @override
  String get authResetConfirmPasswordLabel => 'Confirm new password';

  @override
  String get authResetNewPasswordSubmit => 'Reset password';

  @override
  String get authResetPasswordRequired => 'Enter a new password.';

  @override
  String get authResetPasswordsDoNotMatch => 'Passwords do not match.';

  @override
  String get authResetPasswordWeak => 'This password cannot be used. Choose a stronger one.';

  @override
  String get authResetSessionExpired => 'Your reset session has expired. Please start again.';

  @override
  String get authResetSuccessTitle => 'Password updated';

  @override
  String get authResetSuccessBody => 'Your password has been changed. Log in with your new password.';

  @override
  String get authResetBackToLogin => 'Back to log in';

  @override
  String get authResetThrottled => 'Too many attempts. Please try again later.';

  @override
  String get authForgotPasswordLink => 'Forgot password?';

  @override
  String authResetOtpNeutralHint(String email) {
    return 'If $email is registered, a 6-digit code is on its way.';
  }

  @override
  String get authResetOtpExpiry => 'The code is valid for 5 minutes.';

  @override
  String get authResetShowPassword => 'Show password';

  @override
  String get authResetHidePassword => 'Hide password';

  @override
  String get ordersStatusPending => 'Pending';

  @override
  String get ordersStatusConfirmed => 'Confirmed';

  @override
  String get ordersStatusProcessing => 'Processing';

  @override
  String get ordersStatusShipped => 'Shipped';

  @override
  String get ordersStatusDelivered => 'Delivered';

  @override
  String get ordersStatusCancelled => 'Cancelled';

  @override
  String get ordersStatusUnknown => 'Unknown';

  @override
  String get ordersFilterAll => 'All';

  @override
  String get ordersTitle => 'Orders';

  @override
  String get consoleNavOrders => 'Orders';

  @override
  String get ordersOverviewTitle => 'Overview';

  @override
  String get ordersOverviewTotal => 'Total orders';

  @override
  String get ordersSearchHint => 'Search by order number';

  @override
  String get ordersSearchClear => 'Clear search';

  @override
  String get ordersEmptyTitle => 'No orders yet';

  @override
  String get ordersEmptyBody => 'Sales you record from chat will appear here.';

  @override
  String get ordersEmptyFilteredTitle => 'No orders with this status';

  @override
  String get ordersEmptySearchTitle => 'No order matches your search';

  @override
  String get ordersErrorLoad => 'Could not load orders.';

  @override
  String ordersTruncatedNote(int count) {
    return 'Showing the latest $count orders only.';
  }

  @override
  String get ordersCustomerLabel => 'Customer';

  @override
  String get ordersProductLabel => 'Product';

  @override
  String get ordersQuantityLabel => 'Quantity';

  @override
  String get ordersUnitPriceLabel => 'Agreed unit price';

  @override
  String get ordersTotalLabel => 'Total';

  @override
  String get ordersCurrencyLabel => 'Currency';

  @override
  String get ordersStatusLabel => 'Status';

  @override
  String ordersQuantityTimesPrice(int quantity, String price) {
    return '$quantity × $price';
  }

  @override
  String ordersCreatedAt(String date) {
    return 'Created $date';
  }

  @override
  String ordersConfirmedAt(String date) {
    return 'Confirmed $date';
  }

  @override
  String ordersCompletedAt(String date) {
    return 'Delivered $date';
  }

  @override
  String ordersCancelledAt(String date) {
    return 'Cancelled $date';
  }

  @override
  String get ordersTimelineTitle => 'Timeline';

  @override
  String get ordersTimelineCreated => 'Order recorded';

  @override
  String ordersTimelineStatusChanged(String from, String to) {
    return 'Status changed from $from to $to';
  }

  @override
  String get ordersNotesTitle => 'Notes';

  @override
  String get ordersNotesEmpty => 'No notes yet.';

  @override
  String get ordersCustomerNote => 'Customer note';

  @override
  String get ordersInternalNote => 'Internal note';

  @override
  String get ordersInternalBadge => 'Internal';

  @override
  String get ordersOpenConversation => 'Open conversation';

  @override
  String get ordersOpenDetails => 'Details';

  @override
  String get ordersUpdateStatus => 'Update status';

  @override
  String get ordersChangeStatusTitle => 'Change status';

  @override
  String get ordersStatusNoteHint => 'Note for the customer (optional)';

  @override
  String get ordersStatusNoTransitions => 'This order cannot change status anymore.';

  @override
  String get ordersStatusChanged => 'Status updated.';

  @override
  String get ordersAddNote => 'Add note';

  @override
  String get ordersNoteHint => 'Write a note';

  @override
  String get ordersNoteInternalToggle => 'Internal note (hidden from the customer)';

  @override
  String get ordersNoteAdded => 'Note added.';

  @override
  String get ordersNoteRequired => 'Write a note first.';

  @override
  String get ordersActionSave => 'Save';

  @override
  String get ordersActionCancel => 'Cancel';

  @override
  String get ordersRecordSale => 'Record Sale';

  @override
  String get ordersRecordSaleTitle => 'Record a sale';

  @override
  String get ordersFieldCustomerNote => 'Note for the customer';

  @override
  String get ordersFieldInternalNote => 'Internal note (only you)';

  @override
  String get ordersSummaryTitle => 'Summary';

  @override
  String ordersSummaryLine(int quantity, String price, String total) {
    return '$quantity × $price = $total';
  }

  @override
  String get ordersConfirmRecord => 'Confirm and record';

  @override
  String get ordersSubmitting => 'Recording…';

  @override
  String get ordersRetryRecord => 'Try again';

  @override
  String ordersRecordedSuccess(String orderNumber) {
    return 'Sale recorded as $orderNumber.';
  }

  @override
  String ordersAlreadyRecorded(String orderNumber) {
    return 'This sale was already recorded as $orderNumber.';
  }

  @override
  String get ordersCurrencyAutoNote => 'The currency of the product is applied automatically.';

  @override
  String get ordersValidationQuantity => 'Enter a whole number from 1 to 100000.';

  @override
  String get ordersValidationPrice => 'Enter a price above 0 with up to 2 decimals.';

  @override
  String get ordersErrorNetwork => 'No connection. Check your internet and try again.';

  @override
  String get ordersErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get ordersErrorSafeRetry => 'Trying again will not create a duplicate order.';

  @override
  String ordersProductFallback(int id) {
    return 'Product #$id';
  }

  @override
  String get ordersDetailsTitle => 'Order details';

  @override
  String get ordersNotFound => 'Order not found.';

  @override
  String get ordersConversationUnavailable => 'Could not open the conversation.';

  @override
  String get analyticsContentEmpty => 'No posts or reels found for this period and filter.';

  @override
  String get analyticsContentExternalInDetails => 'External platform numbers are shown in the details.';

  @override
  String get analyticsContentExternalNote => 'Entered manually by you. These numbers are not synced with Instagram, Facebook or TikTok.';

  @override
  String get analyticsContentExternalTitle => 'External platforms (manual)';

  @override
  String get analyticsContentInAppNote => 'Counted inside the app only. In-app shares do not prove any external view.';

  @override
  String get analyticsContentInternalTitle => 'In-app numbers';

  @override
  String get analyticsContentLoadError => 'Could not load the analytics of this content. Try again.';

  @override
  String get analyticsContentMetricComments => 'Comments';

  @override
  String get analyticsContentMetricEngagementRate => 'Engagement rate';

  @override
  String get analyticsContentMetricInAppShares => 'In-app shares';

  @override
  String get analyticsContentMetricLikes => 'Likes';

  @override
  String get analyticsContentNoCaption => 'No caption';

  @override
  String get analyticsContentOpenDetails => 'View details';

  @override
  String get analyticsContentOrderHighestEngagement => 'Highest engagement';

  @override
  String get analyticsContentOrderMostLiked => 'Most liked';

  @override
  String get analyticsContentOrderMostSaved => 'Most saved';

  @override
  String get analyticsContentOrderMostShared => 'Most shared';

  @override
  String get analyticsContentOrderMostViewed => 'Most viewed';

  @override
  String get analyticsContentOrderNewest => 'Newest';

  @override
  String get analyticsContentTrendInteractions => 'Interactions';

  @override
  String get analyticsContentTypeAll => 'All';

  @override
  String get analyticsContentTypePost => 'Post';

  @override
  String get analyticsContentTypePosts => 'Posts';

  @override
  String get analyticsContentTypeReel => 'Reel';

  @override
  String get analyticsContentTypeReels => 'Reels';

  @override
  String get analyticsExternalAddUpdate => 'Add or update numbers';

  @override
  String get analyticsExternalBadgeManual => 'Manual';

  @override
  String get analyticsExternalBadgeSynced => 'Synced';

  @override
  String get analyticsExternalEmpty => 'No external numbers entered yet.';

  @override
  String get analyticsExternalFormMetric => 'Metric';

  @override
  String get analyticsExternalFormNote => 'Enter the number you see on the platform. It is saved as a manual entry.';

  @override
  String get analyticsExternalFormPlatform => 'Platform';

  @override
  String get analyticsExternalFormReference => 'Reference (optional)';

  @override
  String get analyticsExternalFormSave => 'Save';

  @override
  String get analyticsExternalFormTitle => 'Add external numbers';

  @override
  String get analyticsExternalFormValue => 'Value';

  @override
  String get analyticsExternalIntro => 'Numbers from Instagram, Facebook and TikTok that you enter yourself. Nothing is synced automatically.';

  @override
  String analyticsExternalLastUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String get analyticsExternalLoadError => 'Could not load the external numbers. Try again.';

  @override
  String get analyticsExternalMetricLikes => 'Likes';

  @override
  String get analyticsExternalMetricSaves => 'Saves';

  @override
  String get analyticsExternalMetricShares => 'Shares';

  @override
  String get analyticsExternalMetricViews => 'Views';

  @override
  String get analyticsExternalPlatformFacebook => 'Facebook';

  @override
  String get analyticsExternalPlatformInstagram => 'Instagram';

  @override
  String get analyticsExternalPlatformTiktok => 'TikTok';

  @override
  String analyticsExternalReference(String reference) {
    return 'Reference: $reference';
  }

  @override
  String get analyticsExternalSaveError => 'Could not save. Please try again.';

  @override
  String get analyticsExternalSaved => 'Saved.';

  @override
  String get analyticsExternalSourceManual => 'Source: entered manually';

  @override
  String get analyticsExternalSourceSynced => 'Source: synced from the platform';

  @override
  String get analyticsExternalValueInvalid => 'Enter a whole number, 0 or more.';

  @override
  String get analyticsProdEmpty => 'No products with analytics in this period.';

  @override
  String get analyticsProdFunnelTitle => 'Conversion funnel';

  @override
  String get analyticsProdInactive => 'Inactive product';

  @override
  String analyticsProdLabelValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String get analyticsProdLoadError => 'Could not load the analytics of this product. Try again.';

  @override
  String get analyticsProdLoadMore => 'Load more';

  @override
  String get analyticsProdMetricAverageOrderValue => 'Average order value';

  @override
  String get analyticsProdMetricConversion => 'Conversion';

  @override
  String get analyticsProdMetricInterests => 'Interests';

  @override
  String get analyticsProdMetricOrders => 'Orders';

  @override
  String get analyticsProdMetricSales => 'Sales';

  @override
  String get analyticsProdMetricSaves => 'Saves';

  @override
  String get analyticsProdMetricSoldOrders => 'Sold orders';

  @override
  String get analyticsProdMetricUniqueViews => 'Unique views';

  @override
  String get analyticsProdMetricUnits => 'Units';

  @override
  String get analyticsProdMetricViews => 'Views';

  @override
  String get analyticsProdNoBusiness => 'No business profile found for this account.';

  @override
  String get analyticsProdNoSales => 'No sales in this period.';

  @override
  String get analyticsProdOpenOrders => 'Open orders';

  @override
  String get analyticsProdOrderBestSelling => 'Best selling';

  @override
  String get analyticsProdOrderHighestConversion => 'Highest conversion';

  @override
  String get analyticsProdOrderLowestConversion => 'Lowest conversion';

  @override
  String get analyticsProdOrderMostInterested => 'Most interested';

  @override
  String get analyticsProdOrderMostOrdered => 'Most ordered';

  @override
  String get analyticsProdOrderMostViewed => 'Most viewed';

  @override
  String get analyticsProdOrdersLinkNote => 'Opens all your orders. Filtering orders by product is not available.';

  @override
  String analyticsProdOrdersUpdatedAt(String date) {
    return 'Orders updated $date';
  }

  @override
  String analyticsProdRateValue(String rate) {
    return '$rate%';
  }

  @override
  String analyticsProdSalesLine(String orders, String units) {
    return 'Sold orders: $orders · Units: $units';
  }

  @override
  String get analyticsProdSalesTitle => 'Sales by currency';

  @override
  String get analyticsProdTotalsTitle => 'Totals';

  @override
  String get analyticsProdTrendNoData => 'No trend data for this period.';

  @override
  String get analyticsProdTrendsTitle => 'Daily trends';

  @override
  String analyticsProdUpdatedAt(String date) {
    return 'Data updated $date';
  }

  @override
  String get analyticsProdViewsIncomplete => 'Views are not complete for this period, so rates that depend on views are not shown.';

  @override
  String get analyticsProdViewsUnavailable => 'View data is not available for this period.';

  @override
  String biChartSemantics(String title, int days) {
    return '$title, period in days: $days';
  }

  @override
  String get biComparedWithPrevious => 'Compared with the previous period';

  @override
  String get biDataNeverUpdated => 'Data has not been updated yet.';

  @override
  String biDataUpdatedAt(String date) {
    return 'Data updated $date';
  }

  @override
  String get biErrorNetwork => 'No connection. Check your internet and try again.';

  @override
  String get biFunnelCompleted => 'Completed';

  @override
  String get biFunnelConfirmed => 'Confirmed';

  @override
  String biFunnelConversion(String rate) {
    return '$rate conversion';
  }

  @override
  String biFunnelDrop(String rate) {
    return '$rate lost';
  }

  @override
  String get biFunnelInterests => 'Interests';

  @override
  String get biFunnelOrders => 'Orders';

  @override
  String biFunnelOverall(String rate) {
    return 'Overall conversion: $rate';
  }

  @override
  String get biFunnelTitle => 'Conversion funnel';

  @override
  String get biFunnelUnitsNote => 'Views are unique views. Interests, orders, confirmed and completed count each customer once.';

  @override
  String get biFunnelViews => 'Views';

  @override
  String get biGroupContent => 'Content';

  @override
  String get biGroupOrders => 'Orders';

  @override
  String get biGroupProducts => 'Products';

  @override
  String get biKpiAov => 'Average order value';

  @override
  String get biKpiComments => 'Comments';

  @override
  String get biKpiCompleted => 'Completed orders';

  @override
  String get biKpiConfirmed => 'Confirmed orders';

  @override
  String get biKpiContentViews => 'Content views';

  @override
  String get biKpiInterests => 'Interests';

  @override
  String get biKpiLikes => 'Likes';

  @override
  String get biKpiOrders => 'Orders';

  @override
  String get biKpiProductUniqueViews => 'Product unique views';

  @override
  String get biKpiProductViews => 'Product views';

  @override
  String get biKpiSales => 'Sales';

  @override
  String get biKpiSaves => 'Saves';

  @override
  String get biKpiShares => 'In-app shares';

  @override
  String get biLoadFailed => 'Could not load the analytics. Try again.';

  @override
  String get biNoBusiness => 'No business profile found for this account.';

  @override
  String get biNoPreviousData => 'No previous data';

  @override
  String get biNoSalesInPeriod => 'No sales in this period.';

  @override
  String get biOrdersByStatusTitle => 'Orders by status';

  @override
  String get biOrdersEmpty => 'No orders in this period.';

  @override
  String get biOrdersOverTimeTitle => 'Orders over time';

  @override
  String get biOrdersTotal => 'Total orders';

  @override
  String biOrdersUpdatedAt(String date) {
    return 'Orders updated $date';
  }

  @override
  String get biPeriodNote => 'Dates are in UTC. Today is not included because it has no daily rollup yet.';

  @override
  String biPeriodRange(String start, String end) {
    return '$start to $end';
  }

  @override
  String get biPresetCustom => 'Custom';

  @override
  String get biPresetLast14 => '14 days';

  @override
  String get biPresetLast30 => '30 days';

  @override
  String get biPresetLast7 => '7 days';

  @override
  String get biPresetLast90 => '90 days';

  @override
  String get biPresetPreviousMonth => 'Previous month';

  @override
  String get biPresetThisMonth => 'This month';

  @override
  String biRangeTooLong(int days) {
    return 'The range can be at most $days days.';
  }

  @override
  String get biRefresh => 'Refresh';

  @override
  String biRevenueOverTimeTitle(String currency) {
    return 'Sales over time ($currency)';
  }

  @override
  String get biSalesDefinition => 'Sales value = confirmed, processing, shipped and delivered orders. Pending and cancelled orders are not counted.';

  @override
  String get biSalesDisclaimer => 'These are sales you recorded, not collected payments.';

  @override
  String get biSeriesOrders => 'Orders';

  @override
  String get biSeriesSoldOrders => 'Sold orders';

  @override
  String get biStatusCancelled => 'Cancelled';

  @override
  String get biStatusConfirmed => 'Confirmed';

  @override
  String get biStatusDelivered => 'Delivered';

  @override
  String get biStatusPending => 'Pending';

  @override
  String get biStatusProcessing => 'Processing';

  @override
  String get biStatusShipped => 'Shipped';

  @override
  String get biStatusUnknown => 'Unknown';

  @override
  String get biTabContent => 'Content';

  @override
  String get biTabExternal => 'External';

  @override
  String get biTabOrders => 'Orders & sales';

  @override
  String get biTabOverview => 'Overview';

  @override
  String get biTabProducts => 'Products';

  @override
  String biTopProductSub(String orders, String units) {
    return 'Sold orders: $orders · Units: $units';
  }

  @override
  String get biTopProductsEmpty => 'No sold products in this period.';

  @override
  String get biTopProductsTitle => 'Top products';

  @override
  String get biTotalSales => 'Total sales';

  @override
  String get biUnits => 'Units';

  @override
  String get biViewsIncomplete => 'Views are not complete for this period. Rates that depend on views and the previous-period comparison are not shown.';

  @override
  String get biViewsUnavailable => 'View data is not available for this period.';
}
