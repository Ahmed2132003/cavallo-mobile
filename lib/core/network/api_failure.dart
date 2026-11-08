/// Part P-004 scope: typed failure model for the network layer.
///
/// Every feature's data layer should catch [DioException] (from
/// package:dio) and read `.error`, which [ErrorInterceptor] guarantees is
/// always one of these variants once the request has passed through
/// `dioClientProvider`'s interceptor chain - never a raw [DioException] or
/// a raw HTTP status code.
///
/// This layer is intentionally feature-agnostic: it knows nothing about
/// auth, products, chat, etc. It only knows how to describe "what kind of
/// thing went wrong with an HTTP call."
///
/// Part P-112: every failure now also carries the stable [code] (the
/// backend's `error.code`, or one of the client-side [ApiErrorCodes]).
/// [message] is kept for logs and tests ONLY - it is raw backend / developer
/// English and must never be shown to a user. UI code turns a failure into
/// text through `localizedApiError` (`core/l10n/error_messages.dart`).
sealed class ApiFailure {
  const ApiFailure({required this.message, this.code});

  /// Raw message (backend `error.message` or a developer default).
  /// NOT for display to users - see the class comment.
  final String message;

  /// Stable machine code: the backend envelope's `error.code`
  /// (e.g. `THROTTLED`), a client-side [ApiErrorCodes] value, or `null`
  /// when the response carried no envelope at all.
  final String? code;
}

/// Codes the CLIENT assigns when there is no backend envelope to read.
abstract final class ApiErrorCodes {
  static const String networkError = 'NETWORK_ERROR';
  static const String badCertificate = 'BAD_CERTIFICATE';
  static const String cancelled = 'CANCELLED';

  /// Used for an HTTP 429 that came without a backend envelope; matches the
  /// backend's own code for the same situation.
  static const String throttled = 'THROTTLED';
}

/// Backend rejected the request due to invalid input (HTTP 400).
///
/// [fields] mirrors the backend's `error.fields` object exactly:
/// `{"email": ["already exists"]}` becomes `{'email': ['already exists']}`.
/// Empty map when the backend didn't send field-level detail.
final class ValidationFailure extends ApiFailure {
  const ValidationFailure({
    required super.message,
    required this.fields,
    super.code,
  });

  final Map<String, List<String>> fields;
}

/// Request was unauthenticated or unauthorized (HTTP 401 or 403).
///
/// Deliberately does not distinguish 401 vs 403 as separate variants -
/// both mean "the caller cannot proceed as-is," and callers that need the
/// distinction (e.g. P-022's token-refresh trigger on 401 specifically)
/// should inspect the original DioException's response status code, not
/// this failure type.
final class AuthFailure extends ApiFailure {
  const AuthFailure({required super.message, super.code});
}

/// No usable response was received: connection error, timeout, no
/// connectivity, DNS failure, TLS/certificate problems, etc.
final class NetworkFailure extends ApiFailure {
  const NetworkFailure({required super.message, super.code});
}

/// Backend responded but failed on its own side (HTTP 5xx).
final class ServerFailure extends ApiFailure {
  const ServerFailure({required super.message, super.code});
}

/// Anything that doesn't fit the categories above: an unexpected status
/// code, a response body that isn't the expected error envelope shape, a
/// cancelled request, etc.
final class UnknownFailure extends ApiFailure {
  const UnknownFailure({required super.message, super.code, this.retryAfter});

  /// A failure for an error that is not an [ApiFailure] at all (a bug or an
  /// unexpected exception). The text is for developers only:
  /// `localizedApiError` never shows [message] and maps this to
  /// `errorUnknown`.
  const UnknownFailure.unexpected()
    : this(message: 'An unexpected error occurred.');

  /// How long the server asked the client to wait (`Retry-After` header of
  /// an HTTP 429). `null` for every other failure, and for a 429 whose
  /// header was missing or not a plain number of seconds.
  ///
  /// A 429 is deliberately NOT a new [ApiFailure] subtype: it keeps arriving
  /// as an [UnknownFailure] with `code == 'THROTTLED'` (pinned by
  /// `error_interceptor_code_test.dart`), and `localizedApiError` already
  /// turns that code into the localized "try again later" text. Adding a
  /// sealed subtype would break every exhaustive `switch (failure)` in the
  /// app. [retryAfter] is the only new piece of information.
  final Duration? retryAfter;
}
