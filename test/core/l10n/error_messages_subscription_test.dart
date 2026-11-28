import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/l10n/error_messages.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/l10n/app_localizations_ar.dart';
import 'package:social_commerce_app/l10n/app_localizations_en.dart';

/// Part FL-01: subscription error codes -> localized text (ar + en).
void main() {
  final Map<String, AppLocalizations> locales = <String, AppLocalizations>{
    'en': AppLocalizationsEn(),
    'ar': AppLocalizationsAr(),
  };

  // code sent by the backend, the failure type the interceptor gives it, and
  // the getter that must be used.
  final List<(String, ApiFailure, String Function(AppLocalizations))> cases =
      <(String, ApiFailure, String Function(AppLocalizations))>[
        (
          'SUBSCRIPTION_REQUIRED',
          const AuthFailure(message: 'm', code: 'SUBSCRIPTION_REQUIRED'),
          (AppLocalizations l) => l.errorSubscriptionRequired,
        ),
        (
          'STORAGE_QUOTA_EXCEEDED',
          const AuthFailure(message: 'm', code: 'STORAGE_QUOTA_EXCEEDED'),
          (AppLocalizations l) => l.errorStorageQuotaExceeded,
        ),
        (
          'downgrade_blocked_usage',
          const UnknownFailure(message: 'm', code: 'downgrade_blocked_usage'),
          (AppLocalizations l) => l.errorDowngradeBlockedUsage,
        ),
        (
          'downgrade_already_pending',
          const UnknownFailure(message: 'm', code: 'downgrade_already_pending'),
          (AppLocalizations l) => l.errorDowngradeAlreadyPending,
        ),
      ];

  for (final MapEntry<String, AppLocalizations> locale in locales.entries) {
    group('localizedApiError (${locale.key})', () {
      for (final (
            String code,
            ApiFailure failure,
            String Function(AppLocalizations) text,
          )
          in cases) {
        test('$code maps to its own text, not the type fallback', () {
          final String result = localizedApiError(locale.value, failure);
          expect(result, text(locale.value));
          expect(result, isNotEmpty);
          expect(result, isNot(locale.value.errorUnknown));
          expect(result, isNot(locale.value.errorNotAuthorized));
        });
      }

      test('code matching is case-insensitive', () {
        final AppLocalizations l10n = locale.value;
        for (final String code in <String>[
          'DOWNGRADE_BLOCKED_USAGE',
          'Downgrade_Blocked_Usage',
          'downgrade_blocked_usage',
        ]) {
          expect(
            localizedApiError(l10n, UnknownFailure(message: 'm', code: code)),
            l10n.errorDowngradeBlockedUsage,
          );
        }
      });

      test('existing codes are unaffected by the normalisation', () {
        final AppLocalizations l10n = locale.value;
        expect(
          localizedApiError(
            l10n,
            const AuthFailure(message: 'm', code: 'PERMISSION_DENIED'),
          ),
          l10n.errorPermissionDenied,
        );
        expect(
          localizedApiError(
            l10n,
            const NetworkFailure(
              message: 'm',
              code: ApiErrorCodes.networkError,
            ),
          ),
          l10n.errorNetwork,
        );
        expect(
          localizedApiError(
            l10n,
            const UnknownFailure(message: 'm', code: 'something_new'),
          ),
          l10n.errorUnknown,
        );
      });
    });
  }

  test('the four subscription texts are distinct from each other', () {
    for (final AppLocalizations l10n in locales.values) {
      final Set<String> texts = <String>{
        l10n.errorSubscriptionRequired,
        l10n.errorStorageQuotaExceeded,
        l10n.errorDowngradeBlockedUsage,
        l10n.errorDowngradeAlreadyPending,
      };
      expect(texts, hasLength(4));
    }
  });
}
