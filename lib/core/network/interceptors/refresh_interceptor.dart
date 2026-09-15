import 'package:dio/dio.dart';

import '../../storage/secure_token_storage.dart';
import '../api_failure.dart';

/// Signature for invalidating the app's session from a non-widget context.
/// [RefreshInterceptor] is not a widget and has no `Ref` of its own, so it
/// depends on this plain callback rather than importing `sessionProvider`
/// directly — that import would both reach into feature code from
/// `core/network` (against the architecture's feature-agnostic-core rule)
/// and create a circular dependency, since `sessionProvider` itself depends
/// on `authRepositoryProvider`, which depends on `dioClientProvider`.
///
/// The real callback is wired in at the composition root
/// (`main.dart`, via `sessionInvalidatorProvider` in `dio_client.dart`) —
/// see that provider's own doc comment for the full wiring, mirroring the
/// exact pattern Part P-004/P-022A already established for
/// `AuthTokenGetter`/`authTokenGetterProvider`.
typedef SessionInvalidator = Future<void> Function();

/// Part P-022A: silent token refresh + transparent retry (happy path).
/// Part P-022B (this part): what happens when the refresh call itself
/// fails — the refresh token has also expired/is invalid.
///
/// On a 401 for any request *other than* the refresh endpoint itself, this
/// interceptor:
///   1. reads the refresh token from [SecureTokenStorage];
///   2. calls `POST /api/v1/auth/refresh/` through a **separate,
///      interceptor-free** [Dio] instance (never the app client — that would
///      be an infinite-recursion footgun);
///   3a. on success: saves the returned token pair, retries the original
///       request with the new access token, and resolves the caller with
///       that result, so the caller never sees the intermediate 401;
///   3b. on failure (this part's scope): clears [SecureTokenStorage],
///       invalidates the session via [_invalidateSession], and rejects the
///       caller with an [AuthFailure] — see [_handleRefreshFailure].
///
/// Explicitly NOT handled here (by design, see the part spec):
///   * concurrent 401s / single-flight lock → Part P-022C
class RefreshInterceptor extends Interceptor {
  RefreshInterceptor({
    required Dio dio,
    required SecureTokenStorage tokenStorage,
    Dio? refreshDio,
    SessionInvalidator? invalidateSession,
  }) : _dio = dio,
       _tokenStorage = tokenStorage,
       _invalidateSession = invalidateSession ?? (() async {}),
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

  /// Invalidates the app-level session (Part P-022B). Defaults to a no-op
  /// so every pre-existing call site/test that constructs
  /// [RefreshInterceptor] directly (Test A, Test C) keeps compiling and
  /// passing unmodified — only the real app (via `dioClientProvider`) and
  /// this part's new failure-path tests (Test B) pass a real one in.
  final SessionInvalidator _invalidateSession;

  /// User-facing message for the [AuthFailure] a caller receives once a
  /// refresh has genuinely failed and the session has been invalidated.
  static const _refreshFailedMessage =
      'Your session has expired. Please log in again.';

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
    // another refresh. Untouched by Part P-022B on purpose (see the part's
    // own architecture rule): a 401 on `/auth/refresh/` itself is this
    // guard's job, not the new failure-handling path below — it just lets
    // the original 401 propagate exactly as P-022A left it.
    if (_isRefreshPath(err.requestOptions.path)) {
      handler.next(err);
      return;
    }

    // Recursion guard #2: an already-retried request must not be retried
    // again (a retry goes back through the full interceptor chain). If it
    // 401s again here, the token we just refreshed was itself rejected —
    // that's a genuine refresh-failure case, handled below like any other.
    if (err.requestOptions.extra[_retriedFlag] == true) {
      await _handleRefreshFailure(err, handler);
      return;
    }

    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      // Nothing to refresh with — functionally identical to a failed
      // refresh from the caller's point of view.
      await _handleRefreshFailure(err, handler);
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
        // The refresh endpoint responded, but not with a usable access
        // token — treat this the same as a failed refresh call.
        await _handleRefreshFailure(err, handler);
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
      // The refresh call itself failed (e.g. the refresh token has also
      // expired/is invalid) — this is Part P-022B's core scenario.
      await _handleRefreshFailure(err, handler);
    }
  }

  /// The refresh has genuinely failed (or could never be attempted). Per
  /// Part P-022B's scope:
  ///   (a) clears [SecureTokenStorage] — no stale tokens survive;
  ///   (b) invalidates the session via [_invalidateSession], so the
  ///       router's redirect guard sends the user to `/login`;
  ///   (c) rejects [originalErr]'s caller with an [AuthFailure], instead of
  ///       letting the raw 401 fall through to `ErrorInterceptor` — this
  ///       guarantees a clear, consistent message regardless of what the
  ///       original endpoint's own 401 body happened to contain.
  Future<void> _handleRefreshFailure(
    DioException originalErr,
    ErrorInterceptorHandler handler,
  ) async {
    await _tokenStorage.clear();
    await _invalidateSession();
    // `callFollowingErrorInterceptor` defaults to false — this deliberately
    // skips ErrorInterceptor, since the AuthFailure below is already final.
    handler.reject(_authFailureFor(originalErr));
  }

  /// Wraps [originalErr] as a new [DioException] carrying an [AuthFailure]
  /// in `.error`, mirroring the shape `ErrorInterceptor` itself produces
  /// (Part P-004) so every caller can keep pattern-matching on
  /// `dioException.error` exactly as it already does.
  DioException _authFailureFor(DioException originalErr) {
    const failure = AuthFailure(message: _refreshFailedMessage);
    return DioException(
      requestOptions: originalErr.requestOptions,
      response: originalErr.response,
      type: originalErr.type,
      error: failure,
      message: failure.message,
      stackTrace: originalErr.stackTrace,
    );
  }

  /// True when [path] points at the refresh endpoint, whether it was given
  /// as a relative path or as a full absolute URL.
  bool _isRefreshPath(String path) {
    final normalized = path.startsWith('http') ? Uri.parse(path).path : path;
    return normalized == refreshPath || normalized.endsWith(refreshPath);
  }
}
