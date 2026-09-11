import 'package:dio/dio.dart';

import '../../config/app_config.dart';

/// Part P-004 scope: request/response logging, dev-only.
///
/// Safe to attach unconditionally to the interceptor chain in every build
/// — it checks [AppConfig.environment] itself on every call, so staging
/// and prod builds silently no-op instead of leaking request/response
/// bodies (which may contain tokens or PII) into release logs.
class LoggingInterceptor extends Interceptor {
  bool get _enabled => AppConfig.environment == AppEnvironment.dev;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (_enabled) {
      // ignore: avoid_print
      print('[HTTP] --> ${options.method} ${options.uri}');
      if (options.data != null) {
        // ignore: avoid_print
        print('[HTTP]     body: ${options.data}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (_enabled) {
      // ignore: avoid_print
      print(
        '[HTTP] <-- ${response.statusCode} '
        '${response.requestOptions.uri}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (_enabled) {
      // ignore: avoid_print
      print(
        '[HTTP] xx  ${err.requestOptions.uri} -> '
        '${err.response?.statusCode ?? err.type}: ${err.message}',
      );
    }
    handler.next(err);
  }
}
