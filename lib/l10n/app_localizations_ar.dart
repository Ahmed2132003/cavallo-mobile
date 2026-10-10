// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'منصة اكتشاف التجار والمصانع';

  @override
  String get relativeJustNow => 'الآن';

  @override
  String relativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count دقيقة',
      many: 'منذ $count دقيقة',
      few: 'منذ $count دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
      zero: 'منذ $count دقيقة',
    );
    return '$_temp0';
  }

  @override
  String relativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count ساعة',
      many: 'منذ $count ساعة',
      few: 'منذ $count ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
      zero: 'منذ $count ساعة',
    );
    return '$_temp0';
  }

  @override
  String relativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count يوم',
      many: 'منذ $count يومًا',
      few: 'منذ $count أيام',
      two: 'منذ يومين',
      one: 'منذ يوم',
      zero: 'منذ $count يوم',
    );
    return '$_temp0';
  }

  @override
  String get errorNetwork => 'لا يوجد اتصال. تحقق من الإنترنت وحاول مرة أخرى.';

  @override
  String get errorSecureConnection => 'تعذّر إنشاء اتصال آمن بالخادم.';

  @override
  String get errorServer => 'حدث خطأ من جانبنا. حاول مرة أخرى لاحقًا.';

  @override
  String get errorAuthentication => 'تعذّر التحقق من هويتك. سجّل الدخول مرة أخرى.';

  @override
  String get errorNotAuthorized => 'غير مسموح لك بتنفيذ هذا الإجراء.';

  @override
  String get errorPermissionDenied => 'ليست لديك صلاحية لتنفيذ هذا الإجراء.';

  @override
  String get errorNotFound => 'تعذّر العثور على ما تبحث عنه.';

  @override
  String get errorBadRequest => 'تعذّر إتمام الطلب.';

  @override
  String get errorValidation => 'تعذّر قبول بعض البيانات التي أدخلتها. راجعها وحاول مرة أخرى.';

  @override
  String get errorThrottled => 'محاولات كثيرة في وقت قصير. انتظر قليلًا ثم حاول مرة أخرى.';

  @override
  String get errorConflict => 'تغيّرت حالة هذا العنصر بالفعل. حدّث الصفحة وحاول مرة أخرى.';

  @override
  String get errorServiceUnavailable => 'هذه الخدمة غير متاحة حاليًا. حاول مرة أخرى لاحقًا.';

  @override
  String get errorCancelled => 'تم إلغاء الطلب.';

  @override
  String get errorUnknown => 'حدث خطأ غير متوقع. حاول مرة أخرى.';

  @override
  String compactThousands(String value) {
    return '$value ألف';
  }

  @override
  String compactMillions(String value) {
    return '$value مليون';
  }

  @override
  String compactBillions(String value) {
    return '$value مليار';
  }

  @override
  String monthName(String month) {
    String _temp0 = intl.Intl.selectLogic(
      month,
      {
        'january': 'يناير',
        'february': 'فبراير',
        'march': 'مارس',
        'april': 'أبريل',
        'may': 'مايو',
        'june': 'يونيو',
        'july': 'يوليو',
        'august': 'أغسطس',
        'september': 'سبتمبر',
        'october': 'أكتوبر',
        'november': 'نوفمبر',
        'december': 'ديسمبر',
        'other': '$month',
      },
    );
    return '$_temp0';
  }

  @override
  String dateFull(String day, String month, String year) {
    return '$day $month $year';
  }

  @override
  String dateAndTime(String date, String time) {
    return '$date، $time';
  }

  @override
  String currencyLabel(String currency) {
    String _temp0 = intl.Intl.selectLogic(
      currency,
      {
        'egp': 'ج.م',
        'sar': 'ر.س',
        'aed': 'د.إ',
        'jod': 'د.أ',
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
  String get authLoginTitle => 'تسجيل الدخول';

  @override
  String get authRegisterTitle => 'إنشاء حساب';

  @override
  String get authEmailLabel => 'البريد الإلكتروني';

  @override
  String get authPasswordLabel => 'كلمة المرور';

  @override
  String get authConfirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get authAccountTypeLabel => 'نوع الحساب';

  @override
  String get authAccountTypeCustomer => 'عميل';

  @override
  String get authAccountTypeBusiness => 'نشاط تجاري';

  @override
  String get authLoginButton => 'تسجيل الدخول';

  @override
  String get authRegisterButton => 'إنشاء الحساب';

  @override
  String get authGoToRegister => 'ليس لديك حساب؟ أنشئ حسابًا';

  @override
  String get authGoToLogin => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String get authEmailRequired => 'البريد الإلكتروني مطلوب.';

  @override
  String get authEmailInvalid => 'أدخل بريدًا إلكترونيًا صالحًا.';

  @override
  String get authPasswordRequired => 'كلمة المرور مطلوبة.';

  @override
  String get authConfirmPasswordRequired => 'يرجى تأكيد كلمة المرور.';

  @override
  String get authPasswordsDoNotMatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get authInvalidCredentials => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get authAutoLoginFailed => 'تم إنشاء الحساب، لكن تعذّر تسجيل الدخول تلقائيًا. يرجى تسجيل الدخول.';

  @override
  String get authFieldErrorEmail => 'لا يمكن استخدام هذا البريد الإلكتروني. تحقق منه أو جرّب بريدًا آخر.';

  @override
  String get authFieldErrorPassword => 'لا يمكن استخدام كلمة المرور هذه. يرجى اختيار كلمة أخرى.';

  @override
  String get authFieldErrorPasswordConfirm => 'كلمتا المرور اللتان أدخلتهما غير متطابقتين.';

  @override
  String get authFieldErrorAccountType => 'يرجى اختيار نوع حساب صالح.';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get splashLoading => 'جارٍ التحميل...';

  @override
  String get splashGoToLogin => 'الانتقال إلى تسجيل الدخول';

  @override
  String get routeErrorTitle => 'الصفحة غير موجودة';

  @override
  String get routeErrorMessage => 'الصفحة التي تبحث عنها غير موجودة أو تم نقلها.';

  @override
  String get routeErrorGoHome => 'العودة إلى الرئيسية';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navExplore => 'استكشاف';

  @override
  String get navSaved => 'المحفوظات';

  @override
  String get navCreate => 'إنشاء';

  @override
  String get navModeration => 'المراجعة';

  @override
  String get navChats => 'المحادثات';

  @override
  String get navProfile => 'حسابي';

  @override
  String get hubTitle => 'الحساب والإعدادات';

  @override
  String get hubAccountTypeCustomer => 'عميل';

  @override
  String get hubAccountTypeBusiness => 'نشاط تجاري';

  @override
  String get hubAccountTypeStaff => 'فريق العمل';

  @override
  String get hubSaved => 'المحفوظات';

  @override
  String get hubNotificationPreferences => 'تفضيلات الإشعارات';

  @override
  String get hubSettingsGroup => 'الإعدادات';

  @override
  String get hubAppearance => 'المظهر';

  @override
  String get hubAppearanceSystem => 'تلقائي';

  @override
  String get hubAppearanceLight => 'فاتح';

  @override
  String get hubAppearanceDark => 'داكن';

  @override
  String get hubLanguage => 'اللغة';

  @override
  String get hubBusinessTools => 'أدوات النشاط التجاري';

  @override
  String get hubBusinessConsole => 'لوحة النشاط التجاري';

  @override
  String get hubEditBusinessProfile => 'تعديل ملف النشاط التجاري';

  @override
  String get hubProducts => 'المنتجات';

  @override
  String get hubContent => 'المحتوى';

  @override
  String get hubStories => 'القصص';

  @override
  String get hubAnalytics => 'التحليلات';

  @override
  String get hubFeaturedStatus => 'حالة الظهور المميز';

  @override
  String get hubFeaturedNo => 'غير مميّز';

  @override
  String get hubModeration => 'المراجعة';

  @override
  String get hubModerationQueue => 'قائمة المراجعة';

  @override
  String get hubAbout => 'عن التطبيق';

  @override
  String get hubLogOut => 'تسجيل الخروج';

  @override
  String get hubLogOutConfirmTitle => 'تسجيل الخروج؟';

  @override
  String get hubLogOutConfirmMessage => 'ستحتاج إلى تسجيل الدخول مرة أخرى لاستخدام حسابك.';

  @override
  String get hubCancel => 'إلغاء';

  @override
  String get savedTabPosts => 'المنشورات';

  @override
  String get savedTabReels => 'الريلز';

  @override
  String get savedTabProducts => 'المنتجات';

  @override
  String get savedEmptyPosts => 'لا توجد منشورات محفوظة بعد. اضغط على علامة الحفظ في أي منشور ليظهر هنا.';

  @override
  String get savedEmptyReels => 'لا توجد ريلز محفوظة بعد. اضغط على علامة الحفظ في أي ريل ليظهر هنا.';

  @override
  String get savedEmptyProducts => 'لا توجد منتجات محفوظة بعد. اضغط على علامة الحفظ في أي منتج ليظهر هنا.';

  @override
  String get savedUnsave => 'إزالة من المحفوظات';

  @override
  String get savedUnavailable => 'هذا العنصر لم يعد متاحًا';

  @override
  String get savedNoPreviewText => 'عنصر محفوظ';

  @override
  String get savedUnsaveFailed => 'تعذّرت الإزالة من المحفوظات. حاول مرة أخرى.';

  @override
  String get savedLoadMoreFailed => 'تعذّر تحميل المزيد من المحفوظات.';

  @override
  String get createSheetTitle => 'إنشاء جديد';

  @override
  String get createSheetPost => 'منشور';

  @override
  String get createSheetReel => 'ريل';

  @override
  String get createSheetStory => 'قصة';

  @override
  String get createSheetProduct => 'منتج';

  @override
  String get homeWordmark => 'Cavallo';

  @override
  String get homeNotificationsTooltip => 'الإشعارات';

  @override
  String get homeChatsTooltip => 'المحادثات';

  @override
  String get discoverSearchHint => 'ابحث عن أنشطة تجارية ومنتجات ومنشورات';

  @override
  String get storyYourStory => 'قصتك';

  @override
  String get storyAddTooltip => 'أضف إلى قصتك';

  @override
  String storyRingNewLabel(String name) {
    return '$name، قصة جديدة';
  }

  @override
  String storyRingSeenLabel(String name) {
    return '$name، تمت مشاهدة القصة';
  }

  @override
  String get storyViewerClose => 'إغلاق';

  @override
  String get storyViewerNotFound => 'لم يتم العثور على القصة.';

  @override
  String get storyViewerEmpty => 'لا توجد قصص للعرض الآن.';

  @override
  String get storyViewerLoadFailed => 'تعذّر تحميل القصص.';

  @override
  String get storyViewerDefaultName => 'نشاط تجاري';

  @override
  String get businessUnknownName => 'نشاط تجاري غير معروف';

  @override
  String get captionMore => 'المزيد';

  @override
  String get actionLike => 'إعجاب';

  @override
  String get actionComment => 'تعليق';

  @override
  String get actionShare => 'مشاركة';

  @override
  String get actionSave => 'حفظ';

  @override
  String feedLikesLine(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted إعجاب',
      many: '$formatted إعجابًا',
      few: '$formatted إعجابات',
      two: 'إعجابان',
      one: 'إعجاب واحد',
      zero: '$formatted إعجاب',
    );
    return '$_temp0';
  }

  @override
  String feedViewAllComments(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عرض كل $formatted تعليق',
      many: 'عرض كل $formatted تعليقًا',
      few: 'عرض كل $formatted تعليقات',
      two: 'عرض التعليقين',
      one: 'عرض التعليق',
      zero: 'عرض كل $formatted تعليق',
    );
    return '$_temp0';
  }

  @override
  String get feedVerifiedLabel => 'موثّق';

  @override
  String feedPostMediaLabel(String name) {
    return 'منشور من $name';
  }

  @override
  String feedReelMediaLabel(String name) {
    return 'ريل من $name';
  }

  @override
  String get feedEmptyMessage => 'خلاصتك فارغة حاليًا.\nتابع بعض الأنشطة التجارية، أو عد لاحقًا.';

  @override
  String get feedLoadFailed => 'تعذّر تحميل خلاصتك.';

  @override
  String get feedLoadingLabel => 'جارٍ تحميل خلاصتك';

  @override
  String get profileScreenTitle => 'نشاط تجاري';

  @override
  String get profileStatPosts => 'المنشورات';

  @override
  String get profileStatFollowers => 'المتابعون';

  @override
  String get profileStatProducts => 'المنتجات';

  @override
  String get profileTabPosts => 'المنشورات';

  @override
  String get profileTabReels => 'الريلز';

  @override
  String get profileTabProducts => 'المنتجات';

  @override
  String get profileTabInfo => 'معلومات';

  @override
  String get followButtonFollow => 'متابعة';

  @override
  String get followButtonFollowing => 'تتم المتابعة';

  @override
  String followersCountLine(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted متابع',
      many: '$formatted متابعًا',
      few: '$formatted متابعين',
      two: 'متابعان',
      one: 'متابع واحد',
      zero: '$formatted متابع',
    );
    return '$_temp0';
  }

  @override
  String get profileMessageButton => 'مراسلة';

  @override
  String get profileMessageStarted => 'بدأت المحادثة. افتحها من الرسائل.';

  @override
  String get profileMessageFailed => 'تعذّر بدء المحادثة. حاول مرة أخرى.';

  @override
  String get profileNotFound => 'لم يتم العثور على النشاط التجاري.\nربما تمت إزالته.';

  @override
  String get profileLoadFailed => 'تعذّر تحميل ملف هذا النشاط التجاري.';

  @override
  String get profileNoDescription => 'لم يضف هذا النشاط التجاري وصفًا بعد.';

  @override
  String profileLocation(String city, String country) {
    return '$city، $country';
  }

  @override
  String get businessTypeTrader => 'تاجر';

  @override
  String get businessTypeFactory => 'مصنع';

  @override
  String get profilePostsEmpty => 'لم يشارك هذا النشاط التجاري أي منشورات بعد.';

  @override
  String get profilePostsLoadFailed => 'تعذّر تحميل منشورات هذا النشاط التجاري.';

  @override
  String get profileReelsEmpty => 'لم يشارك هذا النشاط التجاري أي ريلز بعد.';

  @override
  String get profileReelsLoadFailed => 'تعذّر تحميل ريلز هذا النشاط التجاري.';

  @override
  String get profileProductsEmpty => 'لم يضف هذا النشاط التجاري أي منتجات بعد.';

  @override
  String get profileProductsLoadFailed => 'تعذّر تحميل منتجات هذا النشاط التجاري.';

  @override
  String get profileInfoType => 'نوع النشاط';

  @override
  String get profileInfoLocation => 'الموقع';

  @override
  String get profileInfoPhone => 'الهاتف';

  @override
  String get profileGridLoadingLabel => 'جارٍ تحميل المحتوى';

  @override
  String get featuredBadgeLabel => 'مميّز';

  @override
  String get searchFieldHint => 'ابحث عن تجار ومصانع ومنتجات...';

  @override
  String get searchClearTooltip => 'مسح البحث';

  @override
  String get searchFiltersChip => 'الفلاتر';

  @override
  String searchFiltersChipActive(int count) {
    return 'الفلاتر ($count)';
  }

  @override
  String get searchIdlePrompt => 'ابحث عن تجار ومصانع ومنتجات.\nاكتب كلمة أو اختر فلترًا للبدء.';

  @override
  String get searchNoResults => 'لم يتم العثور على نتائج. جرّب بحثًا مختلفًا أو عدّل الفلاتر.';

  @override
  String get searchLoadFailed => 'تعذّر تحميل نتائج البحث.';

  @override
  String get searchResultsLoadingLabel => 'جارٍ تحميل النتائج';

  @override
  String get discoverEmpty => 'لا يوجد ما يمكن اكتشافه بعد.\nعد قريبًا لترى أنشطة تجارية جديدة.';

  @override
  String get discoverLoadFailed => 'تعذّر تحميل صفحة الاستكشاف الآن.';

  @override
  String get searchFilterTitle => 'الفلاتر';

  @override
  String get searchFilterCategory => 'التصنيف';

  @override
  String get searchFilterCategoryAll => 'كل التصنيفات';

  @override
  String get searchFilterCategoriesFailed => 'تعذّر تحميل التصنيفات.';

  @override
  String get searchFilterCountry => 'الدولة';

  @override
  String get searchFilterCity => 'المدينة';

  @override
  String get searchFilterBusinessType => 'نوع النشاط';

  @override
  String get searchFilterAny => 'الكل';

  @override
  String get searchFilterMinRating => 'الحد الأدنى للتقييم';

  @override
  String searchFilterMinRatingOption(int stars) {
    String _temp0 = intl.Intl.pluralLogic(
      stars,
      locale: localeName,
      other: '$stars نجمة فأكثر',
      many: '$stars نجمة فأكثر',
      few: '$stars نجوم فأكثر',
      two: 'نجمتان فأكثر',
      one: 'نجمة فأكثر',
      zero: '$stars نجمة فأكثر',
    );
    return '$_temp0';
  }

  @override
  String get searchFilterFeaturedOnly => 'المميّز فقط';

  @override
  String get searchFilterClear => 'مسح';

  @override
  String get searchFilterApply => 'تطبيق';

  @override
  String get productDetailTitle => 'المنتج';

  @override
  String productPriceHeadline(String price, String currency) {
    return 'ابتداءً من $price $currency';
  }

  @override
  String get productPriceNote => 'السعر تقريبي وقابل للتفاوض مباشرة مع النشاط التجاري. راسل النشاط التجاري للتأكيد.';

  @override
  String get productNotFoundMessage => 'لم يتم العثور على المنتج.\nربما تمت إزالته.';

  @override
  String get productLoadFailed => 'تعذّر تحميل هذا المنتج.';

  @override
  String get productNoDescription => 'لم يضف هذا النشاط التجاري وصفًا بعد.';

  @override
  String get productVariantsTitle => 'الخيارات';

  @override
  String get productMessageBusiness => 'مراسلة النشاط التجاري';

  @override
  String productShareText(String name) {
    return 'شاهد $name على Cavallo';
  }

  @override
  String get productLoadingLabel => 'جارٍ تحميل المنتج';

  @override
  String get commentsTitle => 'التعليقات';

  @override
  String get commentsInputHint => 'أضف تعليقًا...';

  @override
  String get commentsPostTooltip => 'نشر التعليق';

  @override
  String get commentsEmpty => 'لا توجد تعليقات بعد. كن أول من يعلّق.';

  @override
  String get commentsPendingReview => 'قيد المراجعة: مخفي عن المستخدمين الآخرين';

  @override
  String get commentsLoadMore => 'تحميل المزيد من التعليقات';

  @override
  String commentsAuthorFallback(String id) {
    return 'مستخدم رقم $id';
  }

  @override
  String get commentsLoadingLabel => 'جارٍ تحميل التعليقات';

  @override
  String get chatListTitle => 'الرسائل';

  @override
  String get chatListEmpty => 'لا توجد محادثات بعد';

  @override
  String get chatListNoMessages => 'لا توجد رسائل بعد';

  @override
  String get chatListUnknownUser => 'غير معروف';

  @override
  String get chatListPreviewPhoto => 'صورة';

  @override
  String get chatListPreviewVideo => 'فيديو';

  @override
  String get chatListPreviewSharedPost => 'شارك منشورًا';

  @override
  String get chatListPreviewSharedReel => 'شارك ريلًا';

  @override
  String get chatListPreviewSharedProduct => 'شارك منتجًا';

  @override
  String get chatListLoadingLabel => 'جارٍ تحميل المحادثات';

  @override
  String get chatListNewChatTest => 'محادثة جديدة (تجريبية)';

  @override
  String get chatTestDialogTitle => 'بدء محادثة تجريبية';

  @override
  String get chatTestUserIdLabel => 'رقم مستخدم الحساب الآخر';

  @override
  String get chatTestUserIdHint => 'مثال: 7';

  @override
  String get chatTestCancel => 'إلغاء';

  @override
  String get chatTestStart => 'بدء';

  @override
  String chatListUnreadLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة غير مقروءة',
      many: '$count رسالة غير مقروءة',
      few: '$count رسائل غير مقروءة',
      two: 'رسالتان غير مقروءتان',
      one: 'رسالة واحدة غير مقروءة',
      zero: 'لا رسائل غير مقروءة',
    );
    return '$_temp0';
  }

  @override
  String chatTestUserPlaceholder(int id) {
    return 'مستخدم رقم $id';
  }

  @override
  String get notifTitle => 'الإشعارات';

  @override
  String get notifSettingsTitle => 'إعدادات الإشعارات';

  @override
  String get notifLoadMoreFailed => 'تعذّر تحميل المزيد من الإشعارات.';

  @override
  String get notifLoadFailed => 'تعذّر تحميل إشعاراتك.';

  @override
  String get notifEmpty => 'لا توجد إشعارات بعد.';

  @override
  String get notifSectionToday => 'اليوم';

  @override
  String get notifSectionThisWeek => 'هذا الأسبوع';

  @override
  String get notifSectionEarlier => 'سابقًا';

  @override
  String get notifUnreadLabel => 'غير مقروء';

  @override
  String get notifLoadingLabel => 'جارٍ تحميل الإشعارات';

  @override
  String get notifPrefsSectionHeader => 'أخطرني بشأن';

  @override
  String get notifPrefChatTitle => 'رسائل المحادثات';

  @override
  String get notifPrefChatSubtitle => 'رسائل جديدة في محادثاتك.';

  @override
  String get notifPrefModerationTitle => 'مراجعة المحتوى';

  @override
  String get notifPrefModerationSubtitle => 'عند الموافقة على محتواك أو رفضه.';

  @override
  String get notifPrefSocialTitle => 'النشاط الاجتماعي';

  @override
  String get notifPrefSocialSubtitle => 'متابعون وتعليقات وإعجابات ومشاركات وتقييمات جديدة.';

  @override
  String get notifPrefsSaveFailed => 'تعذّر حفظ تفضيلك. حاول مرة أخرى.';

  @override
  String get notifPrefsLoadFailed => 'تعذّر تحميل إعدادات الإشعارات.';

  @override
  String get notifPrefsSystemFooter => 'تنبيهات النظام المهمة تصلك دائمًا.';

  @override
  String get consoleNavProducts => 'المنتجات';

  @override
  String get consoleNavContent => 'المنشورات والريلز';

  @override
  String get consoleNavStories => 'القصص';

  @override
  String get consoleNavAnalytics => 'التحليلات';

  @override
  String get consoleDashStories => 'القصص النشطة';

  @override
  String get consoleDashFollowers => 'متابعون جدد';

  @override
  String consoleDashRange(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'آخر $days يوم',
      many: 'آخر $days يومًا',
      few: 'آخر $days أيام',
      two: 'آخر يومين',
      one: 'آخر يوم',
      zero: 'آخر $days يوم',
    );
    return '$_temp0';
  }

  @override
  String get consoleDashValueUnavailable => '–';

  @override
  String get consoleProductsTitle => 'منتجاتي';

  @override
  String get consoleProductsCreate => 'إنشاء جديد';

  @override
  String get consoleProductsEmpty => 'لا توجد منتجات بعد.\nاضغط «إنشاء جديد» لإضافة أول منتج لك.';

  @override
  String get consoleProductsLoadFailed => 'تعذّر تحميل منتجاتك.';

  @override
  String get consoleProductsDeleteTitle => 'حذف المنتج؟';

  @override
  String consoleProductsDeleteBody(String name) {
    return 'سيتم إزالة «$name» من منتجاتك. لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get consoleProductsDeleteFailed => 'تعذّر حذف هذا المنتج.';

  @override
  String consoleProductVariants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خيار',
      many: '$count خيارًا',
      few: '$count خيارات',
      two: 'خياران',
      one: 'خيار واحد',
      zero: '$count خيار',
    );
    return '$_temp0';
  }

  @override
  String get consoleProductInactive => 'غير نشط';

  @override
  String get consoleEdit => 'تعديل';

  @override
  String get consoleDelete => 'حذف';

  @override
  String get consoleCancel => 'إلغاء';

  @override
  String get consoleContentTitle => 'محتواي';

  @override
  String get consoleContentNewPost => 'منشور جديد';

  @override
  String get consoleContentNewReel => 'ريل جديد';

  @override
  String get consoleContentEmpty => 'لا توجد منشورات أو ريلز بعد.\nاضغط «منشور جديد» أو «ريل جديد» لمشاركة أول محتوى لك.';

  @override
  String get consoleContentLoadFailed => 'تعذّر تحميل محتواك.';

  @override
  String get consoleTypePost => 'منشور';

  @override
  String get consoleTypeReel => 'ريل';

  @override
  String get consoleStatusUnderReview => 'قيد المراجعة';

  @override
  String get consoleStatusLive => 'تم النشر';

  @override
  String consoleStatusRejectedWithReason(String reason) {
    return 'مرفوض: $reason';
  }

  @override
  String get consoleStatusNoReasonGiven => 'لم يُذكر سبب';

  @override
  String get consoleStatusProcessing => 'جارٍ معالجة الفيديو…';

  @override
  String get consoleStatusProcessingFailed => 'تعذّرت معالجة الفيديو';

  @override
  String get consoleStoriesCreate => 'إنشاء قصة';

  @override
  String get consoleStoriesEmpty => 'لا توجد قصص بعد.\nاضغط «إنشاء قصة» لمشاركة أول قصة لك.';

  @override
  String get consoleStoriesLoadFailed => 'تعذّر تحميل قصصك.';

  @override
  String consoleStoryNumber(int id) {
    return 'قصة رقم $id';
  }

  @override
  String get consoleStoryPublished => 'تم النشر';

  @override
  String get consoleStoryPending => 'قيد المراجعة';

  @override
  String get consoleStoryRejected => 'مرفوضة';

  @override
  String get consoleStoryExpired => 'منتهية';

  @override
  String get consoleStoryUnknown => 'غير معروفة';

  @override
  String consoleStoryReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String consoleStoryTimeLeftHM(int hours, int minutes) {
    return 'متبقّي $hours س $minutes د';
  }

  @override
  String consoleStoryTimeLeftM(int minutes) {
    return 'متبقّي $minutes د';
  }

  @override
  String get consoleStoryTimeLeftLess => 'متبقّي أقل من دقيقة';

  @override
  String get commonRefresh => 'تحديث';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get moderationQueueTitle => 'قائمة المراجعة';

  @override
  String get moderationQueueEmpty => 'القائمة فارغة.\nلا يوجد شيء بانتظار المراجعة.';

  @override
  String get moderationNotAllowed => 'ليست لحسابك صلاحية مراجعة المحتوى. إذا كنت بحاجة إليها، فاطلب من المسؤول إضافة حسابك إلى مجموعة Moderator.';

  @override
  String get moderationQueueLoadFailed => 'تعذّر تحميل قائمة المراجعة.';

  @override
  String moderationSummaryPending(int count) {
    return '$count بانتظار المراجعة';
  }

  @override
  String moderationSummaryPendingFast(int count, int fast) {
    return '$count بانتظار المراجعة · $fast مسار سريع';
  }

  @override
  String get moderationNoPreview => 'لا توجد معاينة';

  @override
  String get moderationPriorityFast => 'مسار سريع';

  @override
  String get moderationPriorityNormal => 'عادي';

  @override
  String get moderationAgeUnderMinute => 'أقل من دقيقة';

  @override
  String moderationAgeMinutes(int minutes) {
    return '$minutes د';
  }

  @override
  String moderationAgeHours(int hours) {
    return '$hours س';
  }

  @override
  String moderationAgeHoursMinutes(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String moderationAgeDays(int days) {
    return '$days يوم';
  }

  @override
  String moderationAgeDaysHours(int days, int hours) {
    return '$days يوم $hours س';
  }

  @override
  String moderationAgeOverdue(String age) {
    return '$age · متأخر';
  }

  @override
  String get moderationContentTypePost => 'منشور';

  @override
  String get moderationContentTypeReel => 'ريل';

  @override
  String get moderationContentTypeStory => 'قصة';

  @override
  String get moderationContentTypeUnknown => 'غير معروف';

  @override
  String get moderationReviewTitle => 'مراجعة المحتوى';

  @override
  String get moderationPreview => 'المعاينة';

  @override
  String get moderationDetailType => 'النوع';

  @override
  String get moderationDetailSubmittedBy => 'أُرسل بواسطة';

  @override
  String get moderationDetailPriority => 'الأولوية';

  @override
  String get moderationDetailWaiting => 'مدة الانتظار';

  @override
  String get moderationDetailQueueItem => 'عنصر القائمة';

  @override
  String get moderationWaitingNote => 'مدة الانتظار محسوبة حتى آخر تحديث للقائمة.';

  @override
  String get moderationReject => 'رفض';

  @override
  String get moderationApprove => 'موافقة';

  @override
  String get moderationItemApproved => 'تمت الموافقة على العنصر';

  @override
  String get moderationItemRejected => 'تم رفض العنصر';

  @override
  String get moderationApproveFailed => 'تعذّرت الموافقة على هذا العنصر. حاول مرة أخرى.';

  @override
  String get moderationRejectFailed => 'تعذّر رفض هذا العنصر. حاول مرة أخرى.';

  @override
  String get moderationAlreadyHandled => 'تمت معالجة هذا العنصر بواسطة شخص آخر أو لم يعد موجودًا. تمت إزالته من قائمتك.';

  @override
  String get moderationRejectTitle => 'رفض المحتوى';

  @override
  String get moderationRejectNote => 'سيرى النشاط التجاري هذا السبب.';

  @override
  String get moderationRejectReasonLabel => 'السبب (مطلوب)';

  @override
  String get moderationRejectReasonRequired => 'السبب مطلوب.';

  @override
  String get analyticsLoadFailed => 'تعذّر تحميل التحليلات.';

  @override
  String analyticsEmpty(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'لم يتم تسجيل أي نشاط خلال آخر $days يوم بعد.',
      many: 'لم يتم تسجيل أي نشاط خلال آخر $days يومًا بعد.',
      few: 'لم يتم تسجيل أي نشاط خلال آخر $days أيام بعد.',
      two: 'لم يتم تسجيل أي نشاط خلال آخر يومين بعد.',
      one: 'لم يتم تسجيل أي نشاط خلال آخر يوم بعد.',
      zero: 'لم يتم تسجيل أي نشاط خلال آخر $days يوم بعد.',
    );
    return '$_temp0';
  }

  @override
  String analyticsDaysWithData(int withData, int days) {
    return 'أيام بها بيانات: $withData من $days';
  }

  @override
  String get analyticsUtcNote => 'تُحتسب الأيام بالتوقيت العالمي المنسّق (UTC). الأيام التي لا يوجد لها سجل لا تُرسم على أنها صفر.';

  @override
  String get analyticsChartFollowersTitle => 'المتابعون الجدد حسب اليوم';

  @override
  String analyticsChartFollowersSemantics(int days, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'المتابعون الجدد: $total إجمالًا خلال $days يوم',
      many: 'المتابعون الجدد: $total إجمالًا خلال $days يومًا',
      few: 'المتابعون الجدد: $total إجمالًا خلال $days أيام',
      two: 'المتابعون الجدد: $total إجمالًا خلال يومين',
      one: 'المتابعون الجدد: $total إجمالًا خلال يوم واحد',
      zero: 'المتابعون الجدد: $total إجمالًا خلال $days يوم',
    );
    return '$_temp0';
  }

  @override
  String get analyticsChartLikesTitle => 'الإعجابات المستلمة حسب اليوم';

  @override
  String analyticsChartLikesSemantics(int days, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'الإعجابات المستلمة: $total إجمالًا خلال $days يوم',
      many: 'الإعجابات المستلمة: $total إجمالًا خلال $days يومًا',
      few: 'الإعجابات المستلمة: $total إجمالًا خلال $days أيام',
      two: 'الإعجابات المستلمة: $total إجمالًا خلال يومين',
      one: 'الإعجابات المستلمة: $total إجمالًا خلال يوم واحد',
      zero: 'الإعجابات المستلمة: $total إجمالًا خلال $days يوم',
    );
    return '$_temp0';
  }

  @override
  String get analyticsRatingsHeading => 'التقييمات';

  @override
  String get analyticsRatingEmpty => 'لم يتم تسجيل أي تقييم بعد، لذلك لا يوجد اتجاه تقييم لرسمه.';

  @override
  String get analyticsChartRatingTitle => 'متوسط التقييم حسب اليوم';

  @override
  String analyticsChartRatingSemantics(int days, String average) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'متوسط التقييم: الأحدث $average خلال $days يوم',
      many: 'متوسط التقييم: الأحدث $average خلال $days يومًا',
      few: 'متوسط التقييم: الأحدث $average خلال $days أيام',
      two: 'متوسط التقييم: الأحدث $average خلال يومين',
      one: 'متوسط التقييم: الأحدث $average خلال يوم واحد',
      zero: 'متوسط التقييم: الأحدث $average خلال $days يوم',
    );
    return '$_temp0';
  }

  @override
  String get analyticsRatingNote => 'كل نقطة هي متوسط التقييم المحفوظ عند تجميع ذلك اليوم. الأيام السابقة لأول تقييم لا تُرسم.';

  @override
  String get analyticsCatalogHeading => 'حجم الكتالوج';

  @override
  String analyticsCatalogAsOf(int day, int month) {
    return 'حتى $day/$month (UTC). هذه إجماليات سجّلها التجميع اليومي، وليست تغيّرات يومية.';
  }

  @override
  String analyticsRangeDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يومًا',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم',
      zero: '$days يوم',
    );
    return '$_temp0';
  }

  @override
  String get analyticsNewFollowers => 'متابعون جدد';

  @override
  String get analyticsLikesReceived => 'الإعجابات المستلمة';

  @override
  String get analyticsCommentsReceived => 'التعليقات المستلمة';

  @override
  String get analyticsStoryViews => 'مشاهدات القصص';

  @override
  String get analyticsNewRatings => 'تقييمات جديدة';

  @override
  String get analyticsAverageRating => 'متوسط التقييم';

  @override
  String get analyticsActiveProducts => 'المنتجات النشطة';

  @override
  String get analyticsPublishedPosts => 'المنشورات المنشورة';

  @override
  String get analyticsPublishedReels => 'الريلز المنشورة';

  @override
  String get bizOnboardTitle => 'أكمل ملف نشاطك التجاري';

  @override
  String get bizFieldName => 'اسم النشاط التجاري';

  @override
  String get bizFieldPhone => 'رقم الهاتف (اختياري)';

  @override
  String get bizFieldPhoneInvalid => 'أدخل رقم هاتف صالحًا للدولة المحددة.';

  @override
  String get bizFieldDescription => 'الوصف (اختياري)';

  @override
  String get bizOnboardSubmit => 'إكمال الملف';

  @override
  String get bizProfileTitle => 'ملف النشاط التجاري';

  @override
  String get bizProfileBackHome => 'العودة إلى الرئيسية';

  @override
  String get bizProfileIncomplete => 'لم تكمل ملف نشاطك التجاري بعد.';

  @override
  String get bizProfileNoChanges => 'لا توجد تغييرات للحفظ.';

  @override
  String get bizProfileUpdated => 'تم تحديث ملف النشاط التجاري.';

  @override
  String get bizProfileSave => 'حفظ التغييرات';

  @override
  String get commonRemove => 'إزالة';

  @override
  String get contentPostNotFound => 'لم يتم العثور على المنشور.\nربما تمت إزالته.';

  @override
  String get contentReelNotFound => 'لم يتم العثور على الريل.\nربما تمت إزالته.';

  @override
  String get contentReelPlaybackSoon => 'تشغيل الفيديو — قريبًا';

  @override
  String get contentFormImageLabel => 'صورة (اختياري)';

  @override
  String get contentFormVideoLabel => 'فيديو';

  @override
  String get contentFormChooseImage => 'اختيار صورة';

  @override
  String get contentFormChangeImage => 'تغيير الصورة';

  @override
  String get contentFormChooseVideo => 'اختيار فيديو';

  @override
  String get contentFormChangeVideo => 'تغيير الفيديو';

  @override
  String get contentFormCaption => 'النص التوضيحي';

  @override
  String get postFormTitle => 'منشور جديد';

  @override
  String get postFormReviewNote => 'ستتم مراجعة منشورك قبل أن يظهر للعملاء.';

  @override
  String get postFormSubmit => 'نشر';

  @override
  String get reelFormTitle => 'ريل جديد';

  @override
  String get reelFormReviewNote => 'تتم معالجة الفيديو أولًا ثم مراجعته قبل أن يظهر للعملاء. ستجد حالته في قائمة المحتوى الخاصة بك.';

  @override
  String get reelFormSubmit => 'نشر الريل';

  @override
  String get productFormImageLabel => 'صورة المنتج (اختياري)';

  @override
  String get productFormVariantName => 'اسم الخيار (مثل: المقاس)';

  @override
  String get productFormVariantValue => 'القيمة (مثل: كبير)';

  @override
  String get productFormRemoveVariant => 'إزالة الخيار';

  @override
  String get productFormAddVariant => 'إضافة خيار';

  @override
  String get productFormName => 'الاسم';

  @override
  String get productFormDescription => 'الوصف';

  @override
  String get productFormPrice => 'السعر';

  @override
  String get productFormCurrency => 'العملة';

  @override
  String get productFormActive => 'نشط (ظاهر للعملاء)';

  @override
  String get productFormCategoryRequired => 'التصنيف مطلوب.';

  @override
  String get productFormCurrencyRequired => 'العملة مطلوبة.';

  @override
  String get socialMoreOptions => 'المزيد من الخيارات';

  @override
  String get socialReport => 'إبلاغ';

  @override
  String get socialReportThanks => 'شكرًا لك، تم إرسال بلاغك.';

  @override
  String get socialReportWhy => 'ما سبب الإبلاغ عن هذا المحتوى؟';

  @override
  String get socialReportDetails => 'تفاصيل (اختياري)';

  @override
  String get socialReportSubmit => 'إرسال';

  @override
  String get socialReasonSpam => 'محتوى مزعج';

  @override
  String get socialReasonInappropriate => 'محتوى غير لائق';

  @override
  String get socialReasonMisleading => 'مضلِّل';

  @override
  String get socialReasonOther => 'أخرى';

  @override
  String get storyUploadStarted => 'بدأ رفع القصة.';

  @override
  String get storyNoMediaSelected => 'لم يتم اختيار صورة أو فيديو بعد.';

  @override
  String get storyAddMediaFirst => 'أضف صورة أو فيديو أولًا.';

  @override
  String get storyAddPhoto => 'إضافة صورة';

  @override
  String get storyAddVideo => 'إضافة فيديو';

  @override
  String get storyPostButton => 'نشر القصة';

  @override
  String get storyUploadDiscard => 'تجاهل';

  @override
  String storyUploadUploading(int attempt) {
    return 'جارٍ رفع القصة... (المحاولة $attempt من 5)';
  }

  @override
  String storyUploadRetrying(int attempt) {
    return 'انقطع الاتصال — تتم إعادة محاولة رفع القصة... (المحاولة $attempt من 5)';
  }

  @override
  String get storyUploadFailed => 'فشل رفع القصة.';

  @override
  String storyUploadFailedWithReason(String reason) {
    return 'فشل رفع القصة: $reason';
  }

  @override
  String get pushBannerView => 'عرض';

  @override
  String get validationBusinessNameRequired => 'اسم النشاط التجاري مطلوب.';

  @override
  String get validationCountryRequired => 'الدولة مطلوبة.';

  @override
  String get validationCityRequired => 'المدينة مطلوبة.';

  @override
  String get businessProfileLoadError => 'تعذّر تحميل ملف نشاطك التجاري.';

  @override
  String get postLoadError => 'تعذّر تحميل هذا المنشور.';

  @override
  String get reelLoadError => 'تعذّر تحميل هذا الريل.';

  @override
  String get commonGenericError => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get validationCaptionRequired => 'النص التوضيحي مطلوب.';

  @override
  String get reelVideoRequired => 'الفيديو مطلوب.';

  @override
  String get productFormEditTitle => 'تعديل المنتج';

  @override
  String get productFormCreate => 'إنشاء منتج';

  @override
  String get productFormSaveChanges => 'حفظ التغييرات';

  @override
  String get validationProductNameRequired => 'الاسم مطلوب.';

  @override
  String get validationDescriptionRequired => 'الوصف مطلوب.';

  @override
  String get validationPriceRequired => 'السعر مطلوب.';

  @override
  String get validationPriceInvalid => 'أدخل سعرًا صحيحًا (مثال: 199.99).';

  @override
  String get chatThreadFallbackTitle => 'محادثة';

  @override
  String get chatConnectionOnline => 'متصل';

  @override
  String get chatConnectionConnecting => 'جارٍ الاتصال…';

  @override
  String get chatConnectionReconnecting => 'جارٍ إعادة الاتصال…';

  @override
  String get chatConnectionOffline => 'غير متصل';

  @override
  String get chatThreadTyping => 'جارٍ الكتابة…';

  @override
  String get chatThreadEmpty => 'لا توجد رسائل بعد — ابدأ بالتحية!';

  @override
  String get chatComposerHint => 'اكتب رسالة…';

  @override
  String get chatAttachPhoto => 'صورة';

  @override
  String get chatAttachVideo => 'فيديو';

  @override
  String chatPhotoTooLarge(int maxMb) {
    return 'الصورة كبيرة جدًا (الحد الأقصى $maxMb ميغابايت).';
  }

  @override
  String chatVideoTooLarge(int maxMb) {
    return 'الفيديو كبير جدًا (الحد الأقصى $maxMb ميغابايت).';
  }

  @override
  String get chatBubbleRetrying => 'جارٍ إعادة المحاولة…';

  @override
  String get chatBubbleFailedTapRetry => 'تعذّر الإرسال · اضغط لإعادة المحاولة';

  @override
  String get chatShareVia => 'مشاركة عبر…';

  @override
  String get chatShareToConversation => 'المشاركة في محادثة';

  @override
  String get chatSharePickerEmpty => 'لا توجد محادثات بعد.\nابدأ محادثة من تبويب المحادثات أولًا.';

  @override
  String get chatSharePickerLoadError => 'تعذّر تحميل محادثاتك.';

  @override
  String get chatShareFailed => 'تعذّرت المشاركة. حاول مرة أخرى.';

  @override
  String get sharedContentTypePost => 'منشور';

  @override
  String get sharedContentTypeReel => 'ريل';

  @override
  String get sharedContentTypeProduct => 'منتج';

  @override
  String get sharedContentUnavailable => 'هذا المحتوى لم يعد متاحًا';
}
