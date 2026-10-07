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
  String get hubAppearanceSystem => 'النظام';

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
  String get hubEditBusinessProfile => 'تعديل ملف النشاط';

  @override
  String get hubProducts => 'المنتجات';

  @override
  String get hubContent => 'المحتوى';

  @override
  String get hubStories => 'القصص';

  @override
  String get hubAnalytics => 'التحليلات';

  @override
  String get hubFeaturedStatus => 'حالة التمييز';

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
  String get createSheetStory => 'ستوري';

  @override
  String get createSheetProduct => 'منتج';

  @override
  String get homeWordmark => 'Cavallo';

  @override
  String get homeNotificationsTooltip => 'الإشعارات';

  @override
  String get homeChatsTooltip => 'المحادثات';

  @override
  String get discoverSearchHint => 'ابحث عن أنشطة ومنتجات ومنشورات';

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
}
