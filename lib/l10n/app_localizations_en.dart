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
}
