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
}
