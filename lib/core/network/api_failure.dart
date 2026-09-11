/// Part P-004 scope: typed failure model for the network layer.
///
/// Every feature's data layer should catch [DioException] (from
/// package:dio) and read `.error`, which [ErrorInterceptor] guarantees is
/// always one of these variants once the request has passed through
/// `dioClientProvider`'s interceptor chain — never a raw [DioException] or
/// a raw HTTP status code.
///
/// This layer is intentionally feature-agnostic: it knows nothing about
/// auth, products, chat, etc. It only knows how to describe "what kind of
/// thing went wrong with an HTTP call."
sealed class ApiFailure {
  const ApiFailure({required this.message});

  /// Human-readable message, preferring the backend's own `error.message`
  /// when available, falling back to a sane default otherwise.
  final String message;
}

/// Backend rejected the request due to invalid input (HTTP 400).
///
/// [fields] mirrors the backend's `error.fields` object exactly:
/// `{"email": ["already exists"]}` becomes `{'email': ['already exists']}`.
/// Empty map when the backend didn't send field-level detail.
final class ValidationFailure extends ApiFailure {
  const ValidationFailure({required super.message, required this.fields});

  final Map<String, List<String>> fields;
}

/// Request was unauthenticated or unauthorized (HTTP 401 or 403).
///
/// Deliberately does not distinguish 401 vs 403 as separate variants —
/// both mean "the caller cannot proceed as-is," and callers that need the
/// distinction (e.g. P-022's token-refresh trigger on 401 specifically)
/// should inspect the original DioException's response status code, not
/// this failure type.
final class AuthFailure extends ApiFailure {
  const AuthFailure({required super.message});
}

/// No usable response was received: connection error, timeout, no
/// connectivity, DNS failure, TLS/certificate problems, etc.
final class NetworkFailure extends ApiFailure {
  const NetworkFailure({required super.message});
}

/// Backend responded but failed on its own side (HTTP 5xx).
final class ServerFailure extends ApiFailure {
  const ServerFailure({required super.message});
}

/// Anything that doesn't fit the categories above: an unexpected status
/// code, a response body that isn't the expected error envelope shape, a
/// cancelled request, etc.
final class UnknownFailure extends ApiFailure {
  const UnknownFailure({required super.message});
}
