import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';

/// Part P-058: turns whatever a repository call threw into a short,
/// user-facing message. `ErrorInterceptor` (P-004) stores a typed
/// [ApiFailure] on `DioException.error`, so unwrap that first.
String socialErrorMessage(Object error) {
  final Object inner = (error is DioException && error.error != null)
      ? error.error!
      : error;
  if (inner is ApiFailure) return inner.message;
  return 'Something went wrong. Please try again.';
}