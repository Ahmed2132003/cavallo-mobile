import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/l10n/error_messages.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-112 STEP 4: error codes become localized text; the raw backend
/// message is never shown.
const String _raw = 'RAW BACKEND ENGLISH MESSAGE';

void main() {
  late AppLocalizations en;
  late AppLocalizations ar;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  ApiFailure withCode(String? code) =>
      UnknownFailure(message: _raw, code: code);

  /// code -> the l10n getter that must be chosen (looked up per language).
  final Map<String, String Function(AppLocalizations)> byCode =
      <String, String Function(AppLocalizations)>{
        'AUTHENTICATION_FAILED': (l) => l.errorAuthentication,
        'PERMISSION_DENIED': (l) => l.errorPermissionDenied,
        'NOT_FOUND': (l) => l.errorNotFound,
        'METHOD_NOT_ALLOWED': (l) => l.errorBadRequest,
        'NOT_ACCEPTABLE': (l) => l.errorBadRequest,
        'UNSUPPORTED_MEDIA_TYPE': (l) => l.errorBadRequest,
        'PARSE_ERROR': (l) => l.errorBadRequest,
        'THROTTLED': (l) => l.errorThrottled,
        'CONFLICT': (l) => l.errorConflict,
        'SERVICE_UNAVAILABLE': (l) => l.errorServiceUnavailable,
        'VALIDATION_ERROR': (l) => l.errorValidation,
        'SERVER_ERROR': (l) => l.errorServer,
        ApiErrorCodes.networkError: (l) => l.errorNetwork,
        ApiErrorCodes.badCertificate: (l) => l.errorSecureConnection,
        ApiErrorCodes.cancelled: (l) => l.errorCancelled,
      };

  test('every known backend/client code maps to its localized text', () {
    for (final MapEntry<String, String Function(AppLocalizations)> entry
        in byCode.entries) {
      for (final AppLocalizations l10n in <AppLocalizations>[en, ar]) {
        expect(
          localizedApiError(l10n, withCode(entry.key)),
          entry.value(l10n),
          reason: '${entry.key} (${l10n.localeName})',
        );
      }
    }
  });

  test('the raw backend message is never returned', () {
    final List<ApiFailure> failures = <ApiFailure>[
      const ValidationFailure(message: _raw, fields: {}, code: 'VALIDATION_ERROR'),
      const AuthFailure(message: _raw, code: 'AUTHENTICATION_FAILED'),
      const ServerFailure(message: _raw),
      const NetworkFailure(message: _raw),
      const UnknownFailure(message: _raw),
      const ValidationFailure(message: _raw, fields: {}),
      const AuthFailure(message: _raw),
      withCode('SOMETHING_NEW_FROM_THE_BACKEND'),
      withCode(null),
    ];
    for (final ApiFailure failure in failures) {
      for (final AppLocalizations l10n in <AppLocalizations>[en, ar]) {
        expect(
          localizedApiError(l10n, failure),
          isNot(contains(_raw)),
          reason: '${failure.runtimeType} / ${failure.code}',
        );
      }
    }
  });

  test('without a (known) code the failure type decides', () {
    for (final AppLocalizations l10n in <AppLocalizations>[en, ar]) {
      expect(
        localizedApiError(l10n, const NetworkFailure(message: _raw)),
        l10n.errorNetwork,
      );
      expect(
        localizedApiError(l10n, const ServerFailure(message: _raw)),
        l10n.errorServer,
      );
      expect(
        localizedApiError(l10n, const AuthFailure(message: _raw)),
        l10n.errorNotAuthorized,
      );
      expect(
        localizedApiError(
          l10n,
          const ValidationFailure(message: _raw, fields: {}),
        ),
        l10n.errorValidation,
      );
      expect(
        localizedApiError(l10n, const UnknownFailure(message: _raw)),
        l10n.errorUnknown,
      );
      expect(
        localizedApiError(l10n, withCode('SOMETHING_NEW_FROM_THE_BACKEND')),
        l10n.errorUnknown,
      );
    }
  });

  test('a DioException carrying an ApiFailure is unwrapped', () {
    final DioException exception = DioException(
      requestOptions: RequestOptions(path: '/x'),
      error: const UnknownFailure(message: _raw, code: 'THROTTLED'),
    );
    expect(localizedApiError(ar, exception), ar.errorThrottled);
    expect(localizedApiError(en, exception), en.errorThrottled);
  });

  test('anything else is the generic unexpected-error text', () {
    expect(localizedApiError(en, null), en.errorUnknown);
    expect(localizedApiError(en, StateError('boom')), en.errorUnknown);
    expect(localizedApiError(ar, 'a string'), ar.errorUnknown);
    expect(
      localizedApiError(
        ar,
        DioException(requestOptions: RequestOptions(path: '/x')),
      ),
      ar.errorUnknown,
    );
  });

  test('every error text is really translated (Arabic differs from English)', () {
    final List<String Function(AppLocalizations)> getters =
        <String Function(AppLocalizations)>[
          (l) => l.errorNetwork,
          (l) => l.errorSecureConnection,
          (l) => l.errorServer,
          (l) => l.errorAuthentication,
          (l) => l.errorNotAuthorized,
          (l) => l.errorPermissionDenied,
          (l) => l.errorNotFound,
          (l) => l.errorBadRequest,
          (l) => l.errorValidation,
          (l) => l.errorThrottled,
          (l) => l.errorConflict,
          (l) => l.errorServiceUnavailable,
          (l) => l.errorCancelled,
          (l) => l.errorUnknown,
        ];
    final RegExp arabicLetters = RegExp('[\u0600-\u06FF]');
    for (final String Function(AppLocalizations) getter in getters) {
      expect(getter(ar), isNot(getter(en)));
      expect(arabicLetters.hasMatch(getter(ar)), isTrue, reason: getter(ar));
    }
  });
}
