import 'package:dio/dio.dart';

import '../api_failure.dart';

/// Part P-004 scope: maps every [DioException] to a typed [ApiFailure] and
/// rethrows a new [DioException] carrying that failure in its `error`
/// field, so every caller downstream can pattern-match on
/// `dioException.error` instead of re-parsing status codes and response
/// bodies itself.
///
/// Must be the *last* interceptor added to the chain (see dio_client.dart)
/// so it sees the final outcome of the request, including anything the
/// auth/logging interceptors did first.
///
/// Parses the backend's unified error envelope (architecture Section 10):
/// ```json
/// {"error": {"code": "VALIDATION_ERROR", "message": "...", "fields": {"email": ["already exists"]}}}
/// ```
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final failure = _mapToFailure(err);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: failure,
        message: failure.message,
        stackTrace: err.stackTrace,
      ),
    );
  }

  ApiFailure _mapToFailure(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.transformTimeout:
        return const NetworkFailure(
          message: 'Network error. Please check your connection and try '
              'again.',
        );

      case DioExceptionType.badCertificate:
        return const NetworkFailure(
          message: 'A secure connection to the server could not be '
              'established.',
        );

      case DioExceptionType.cancel:
        return const UnknownFailure(message: 'Request was cancelled.');

      case DioExceptionType.badResponse:
        return _mapStatusCode(err);

      case DioExceptionType.unknown:
        // Dio buckets a lot of low-level socket/platform errors under
        // `unknown` rather than `connectionError` depending on platform.
        // Anything with no response body is functionally a network
        // problem from the caller's point of view.
        if (err.response == null) {
          return const NetworkFailure(
            message: 'Network error. Please check your connection and '
                'try again.',
          );
        }
        return UnknownFailure(
          message: err.message ?? 'An unexpected error occurred.',
        );
    }
  }

  ApiFailure _mapStatusCode(DioException err) {
    final statusCode = err.response?.statusCode;
    final envelope = _parseEnvelope(err.response?.data);

    if (statusCode == 400) {
      return ValidationFailure(
        message: envelope?.message ?? 'The request could not be validated.',
        fields: envelope?.fields ?? const {},
      );
    }

    if (statusCode == 401 || statusCode == 403) {
      return AuthFailure(
        message: envelope?.message ?? 'You are not authorized to do that.',
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return ServerFailure(
        message: envelope?.message ?? 'Something went wrong on our end. '
            'Please try again later.',
      );
    }

    return UnknownFailure(
      message: envelope?.message ??
          'An unexpected error occurred (status $statusCode).',
    );
  }

  /// Parses the backend's `{"error": {"code","message","fields"}}` shape.
  /// Returns null for anything that doesn't match — callers fall back to
  /// a generic message rather than throwing while handling an error.
  _ErrorEnvelope? _parseEnvelope(dynamic data) {
    if (data is! Map) return null;
    final error = data['error'];
    if (error is! Map) return null;

    final fieldsRaw = error['fields'];
    final fields = <String, List<String>>{};
    if (fieldsRaw is Map) {
      for (final entry in fieldsRaw.entries) {
        final value = entry.value;
        if (value is List) {
          fields[entry.key.toString()] =
              value.map((e) => e.toString()).toList();
        } else if (value != null) {
          fields[entry.key.toString()] = [value.toString()];
        }
      }
    }

    final rawMessage = error['message']?.toString();

    return _ErrorEnvelope(
      code: error['code']?.toString() ?? 'UNKNOWN',
      // Empty string is treated the same as "no message" so callers'
      // `envelope?.message ?? fallback` always gets a non-empty result.
      message: (rawMessage == null || rawMessage.isEmpty) ? null : rawMessage,
      fields: fields,
    );
  }
}

class _ErrorEnvelope {
  const _ErrorEnvelope({
    required this.code,
    required this.message,
    required this.fields,
  });

  final String code;
  final String? message;
  final Map<String, List<String>> fields;
}
