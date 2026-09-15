import 'package:dio/dio.dart';

import '../../storage/secure_token_storage.dart';

/// Part P-022A: silent token refresh + transparent retry (happy path only).
///
/// On a 401 for any request *other than* the refresh endpoint itself, this
/// interceptor:
///   1. reads the refresh token from [SecureTokenStorage];
///   2. calls `POST /api/v1/auth/refresh/` through a **separate,
///      interceptor-free** [Dio] instance (never the app client — that would
///      be an infinite-recursion footgun);
///   3. saves the returned token pair;
///   4. retries the original request with the new access token and resolves
///      the caller with that result, so the caller never sees the
///      intermediate 401.
///
/// Explicitly NOT handled here (by design, see the part spec):
///   * refresh failure → session invalidation  → Part P-022B
///   * concurrent 401s / single-flight lock    → Part P-022C
class RefreshInterceptor extends Interceptor {
  RefreshInterceptor({
    required Dio dio,
    required SecureTokenStorage tokenStorage,
    Dio? refreshDio,
  }) : _dio = dio,
       _tokenStorage = tokenStorage,
       _refreshDio =
           refreshDio ??
           Dio(
             BaseOptions(
               baseUrl: dio.options.baseUrl,
               connectTimeout: dio.options.connectTimeout,
               receiveTimeout: dio.options.receiveTimeout,
               sendTimeout: dio.options.sendTimeout,
             ),
           );

  /// The real backend refresh path (confirmed against
  /// `AuthRepositoryImpl._refreshPath` in P-020 — the master plan's
  /// `/auth/refresh/` is the shorthand, the deployed route is this one).
  ///
  /// Declared here rather than imported from the auth feature on purpose:
  /// `dioClientProvider` is a dependency of `AuthRepositoryImpl`, so
  /// depending on it from `core/network` would be circular.
  static const String refreshPath = '/api/v1/auth/refresh/';

  /// Marker put on a retried request so a retry that 401s again cannot
  /// loop back into another refresh attempt.
  static const String _retriedFlag = 'p022a_refresh_retried';

  final Dio _dio;
  final SecureTokenStorage _tokenStorage;

  /// A dedicated Dio with **zero** interceptors attached — used only for the
  /// refresh call itself. Injectable purely for testability; the default
  /// value satisfies the "separate, interceptor-free instance" rule exactly.
  final Dio _refreshDio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Not an auth problem — nothing for us to do.
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Recursion guard #1: the refresh endpoint itself must never trigger
    // another refresh.
    if (_isRefreshPath(err.requestOptions.path)) {
      // TODO(P-022B): handle refresh failure / session invalidation here.
      handler.next(err);
      return;
    }

    // Recursion guard #2: an already-retried request must not be retried
    // again (a retry goes back through the full interceptor chain).
    if (err.requestOptions.extra[_retriedFlag] == true) {
      // TODO(P-022B): handle refresh failure / session invalidation here.
      handler.next(err);
      return;
    }

    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      // TODO(P-022B): handle refresh failure / session invalidation here.
      handler.next(err);
      return;
    }

    try {
      final refreshResponse = await _refreshDio.post<Map<String, dynamic>>(
        refreshPath,
        data: <String, dynamic>{'refresh': refreshToken},
      );

      final data = refreshResponse.data;
      final newAccess = data?['access'] as String?;
      final newRefresh = data?['refresh'] as String? ?? refreshToken;

      if (newAccess == null || newAccess.isEmpty) {
        // TODO(P-022B): handle refresh failure / session invalidation here.
        handler.next(err);
        return;
      }

      await _tokenStorage.saveTokens(access: newAccess, refresh: newRefresh);

      final retryOptions =
          err.requestOptions
            ..headers['Authorization'] = 'Bearer $newAccess'
            ..extra[_retriedFlag] = true;

      final retried = await _dio.fetch<dynamic>(retryOptions);
      handler.resolve(retried);
    } on DioException catch (_) {
      // TODO(P-022B): handle refresh failure / session invalidation here.
      // For now the ORIGINAL 401 is propagated untouched: no token is
      // cleared, no session provider is invalidated.
      handler.next(err);
    }
  }

  /// True when [path] points at the refresh endpoint, whether it was given
  /// as a relative path or as a full absolute URL.
  bool _isRefreshPath(String path) {
    final normalized = path.startsWith('http') ? Uri.parse(path).path : path;
    return normalized == refreshPath || normalized.endsWith(refreshPath);
  }
}
