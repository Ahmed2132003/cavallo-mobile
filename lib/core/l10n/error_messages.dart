import 'package:dio/dio.dart';

import '../../l10n/app_localizations.dart';
import '../network/api_failure.dart';

/// Part P-112: the ONE function that turns a network failure into text a user
/// may read.
///
/// * The raw backend `message` (English, developer-oriented) is NEVER shown.
///   The stable `code` of the unified error envelope picks the localized text;
///   when there is no code, the failure TYPE picks a sensible one.
/// * [error] may be an [ApiFailure], a [DioException] whose `.error` is an
///   [ApiFailure] (what `dioClientProvider` throws), or anything else (which
///   becomes the generic "unexpected error" text).
/// * Field-level validation texts (`ValidationFailure.fields`) are NOT handled
///   here - they are backend sentences without codes. Screens decide how to
///   present them (P-112 STEP 8 for login / register).
String localizedApiError(AppLocalizations l10n, Object? error) {
  final ApiFailure? failure = _unwrap(error);
  if (failure == null) {
    return l10n.errorUnknown;
  }

  switch (failure.code) {
    case 'AUTHENTICATION_FAILED':
      return l10n.errorAuthentication;
    case 'PERMISSION_DENIED':
      return l10n.errorPermissionDenied;
    case 'NOT_FOUND':
      return l10n.errorNotFound;
    case 'METHOD_NOT_ALLOWED':
    case 'NOT_ACCEPTABLE':
    case 'UNSUPPORTED_MEDIA_TYPE':
    case 'PARSE_ERROR':
      return l10n.errorBadRequest;
    case 'THROTTLED':
      return l10n.errorThrottled;
    case 'CONFLICT':
      return l10n.errorConflict;
    case 'SERVICE_UNAVAILABLE':
      return l10n.errorServiceUnavailable;
    case 'VALIDATION_ERROR':
      return l10n.errorValidation;
    case 'SERVER_ERROR':
      return l10n.errorServer;
    case ApiErrorCodes.networkError:
      return l10n.errorNetwork;
    case ApiErrorCodes.badCertificate:
      return l10n.errorSecureConnection;
    case ApiErrorCodes.cancelled:
      return l10n.errorCancelled;
    default:
      break;
  }

  // No (known) code: fall back on what kind of failure it is.
  return switch (failure) {
    NetworkFailure() => l10n.errorNetwork,
    ServerFailure() => l10n.errorServer,
    AuthFailure() => l10n.errorNotAuthorized,
    ValidationFailure() => l10n.errorValidation,
    UnknownFailure() => l10n.errorUnknown,
  };
}

ApiFailure? _unwrap(Object? error) {
  if (error is ApiFailure) {
    return error;
  }
  if (error is DioException && error.error is ApiFailure) {
    return error.error as ApiFailure;
  }
  return null;
}
