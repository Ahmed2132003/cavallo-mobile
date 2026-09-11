import 'package:dio/dio.dart';

/// Part P-004 scope: attaches `Authorization: Bearer <token>` to every
/// outgoing request when a token is available.
///
/// Deliberately takes the token read as an injected function rather than
/// importing P-005's secure-storage class directly — P-005 doesn't exist
/// yet, and this keeps P-004 testable in isolation. Once P-005 lands, its
/// storage wrapper only needs to expose a function matching this exact
/// signature:
///
/// ```dart
/// Future<String?> Function() // e.g. secureStorage.readAuthToken
/// ```
///
/// and it can be handed straight to [AuthInterceptor]'s constructor (see
/// `authTokenGetterProvider` in dio_client.dart) with no changes to this
/// file.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required Future<String?> Function() getToken})
    : _getToken = getToken;

  final Future<String?> Function() _getToken;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
