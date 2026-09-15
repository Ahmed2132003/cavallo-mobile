import 'dart:async';

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
/// Part P-022B: what happens when the refresh call itself fails — the
/// refresh token has also expired/is invalid (session invalidation).
/// Part P-022C (this part): concurrency hardening — a single-flight lock so
/// that N simultaneous 401s produce exactly **one** refresh call.
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
///   3b. on failure: clears [SecureTokenStorage], invalidates the session
///       via [_invalidateSession], and rejects the caller with an
///       [AuthFailure] — see [_handleRefreshFailure].
///
/// ### Single-flight lock (Part P-022C)
/// Steps 1–3 above are guarded by [_refreshCompleter], an instance-level
/// `Completer<bool>?`:
///   * the first 401 to arrive while no refresh is in flight **owns** the
///     cycle: it creates the completer and runs the P-022A/P-022B logic
///     unchanged;
///   * every other 401 arriving while that completer is non-null simply
///     `await`s it, then either retries with whatever token the single
///     refresh produced (`true`) or receives the same [AuthFailure]
///     (`false`) — it never starts a refresh of its own, and never
///     re-clears storage / re-invalidates the session, so a failed refresh
///     still invalidates exactly once no matter how many requests were
///     waiting;
///   * the completer is reset to `null` the moment it resolves, so a later,
///     independent 401 (after this cycle is over) starts a **fresh** cycle
///     instead of reusing a stale, already-completed one.
///
/// This lock only works if a single [RefreshInterceptor] **instance** is
/// registered once on the shared client — which is exactly what
/// `dioClientProvider` (`dio_client.dart`) does: it constructs the
/// interceptor once per Dio instance, and `dioClientProvider` itself is a
/// cached Riverpod `Provider`, so every concurrent request in the app goes
/// through the same instance and therefore observes the same in-flight
/// completer. Constructing a new interceptor per request would silently
/// defeat it.
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

  /// Part P-022C — the single-flight lock itself.
  ///
  /// Non-null exactly while one refresh cycle is in flight. Completes with
  /// `true` when that refresh produced a usable access token (already
  /// persisted to [SecureTokenStorage] by the time waiters wake up), and
  /// `false` when it failed (storage already cleared and the session already
  /// invalidated exactly once, by the owner).
  ///
  /// Never `await`ed while holding it across a gap without also resetting it
  /// in [_completeRefreshCycle] — see that method for the ordering rule that
  /// keeps a completed completer from ever being reused.
  Completer<bool>? _refreshCompleter;

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
    // another refresh. Untouched by Part P-022B/P-022C on purpose (see both
    // parts' architecture rules): a 401 on `/auth/refresh/` itself is this
    // guard's job — it runs *before* the single-flight lock below, so the
    // refresh path never takes, waits on, or completes the lock.
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

    // ---- Part P-022C: single-flight lock ---------------------------------
    // Someone else is already refreshing: wait for their result instead of
    // starting a second refresh call (the "refresh stampede" this part
    // exists to prevent). Read synchronously, before any `await`, so two
    // 401s landing in the same event-loop turn can never both see `null`.
    final inFlight = _refreshCompleter;
    if (inFlight != null) {
      bool refreshed;
      try {
        refreshed = await inFlight.future;
      } catch (_) {
        refreshed = false;
      }

      if (!refreshed) {
        // The single shared refresh failed. The owner has already cleared
        // storage and invalidated the session exactly once — waiters must
        // NOT repeat either, only surface the same final AuthFailure.
        handler.reject(_authFailureFor(err));
        return;
      }

      await _retryWithStoredToken(err, handler);
      return;
    }

    // Nobody is refreshing — this request owns the cycle. The completer is
    // published here, synchronously, *before* the first `await` below.
    final completer = Completer<bool>();
    _refreshCompleter = completer;
    // ----------------------------------------------------------------------

    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        // Nothing to refresh with — functionally identical to a failed
        // refresh from the caller's point of view.
        _completeRefreshCycle(completer, false);
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
          _completeRefreshCycle(completer, false);
          await _handleRefreshFailure(err, handler);
          return;
        }

        await _tokenStorage.saveTokens(access: newAccess, refresh: newRefresh);

        // Release the waiters as soon as the new token pair is persisted —
        // deliberately *before* this request's own retry, so all the queued
        // requests retry in parallel rather than serially behind the owner,
        // and so a failure of *this* request's retry (its own concern) can
        // never be mistaken for a failure of the shared refresh.
        _completeRefreshCycle(completer, true);

        final retryOptions =
            err.requestOptions
              ..headers['Authorization'] = 'Bearer $newAccess'
              ..extra[_retriedFlag] = true;

        final retried = await _dio.fetch<dynamic>(retryOptions);
        handler.resolve(retried);
      } on DioException catch (_) {
        // The refresh call itself failed (e.g. the refresh token has also
        // expired/is invalid) — this is Part P-022B's core scenario.
        // No-op if the cycle was already completed with `true` above (i.e.
        // it was the retry, not the refresh, that threw).
        _completeRefreshCycle(completer, false);
        await _handleRefreshFailure(err, handler);
      }
    } finally {
      // Safety net: whatever path was taken (including an unexpected throw),
      // the lock is never left held and no waiter is ever left hanging.
      _completeRefreshCycle(completer, false);
    }
  }

  /// Part P-022C — ends the single-flight cycle owned by [completer].
  ///
  /// Order matters: the instance-level lock is released **first**, so that a
  /// waiter woken by `complete` (or any brand-new 401 arriving afterwards)
  /// can never observe an already-completed completer and wait forever on
  /// it. Both operations are idempotent, so this is safe to call more than
  /// once on the same completer (the `finally` safety net in [onError] does
  /// exactly that).
  void _completeRefreshCycle(Completer<bool> completer, bool refreshed) {
    if (identical(_refreshCompleter, completer)) {
      _refreshCompleter = null;
    }
    if (!completer.isCompleted) {
      completer.complete(refreshed);
    }
  }

  /// Part P-022C — retry path for a request that *waited* on someone else's
  /// refresh. Mirrors the owner's own retry (same `Authorization` header
  /// rewrite, same [_retriedFlag]) but reads the freshly-persisted token
  /// from [SecureTokenStorage] rather than from a local variable, since the
  /// refresh call that produced it happened in another request's stack.
  Future<void> _retryWithStoredToken(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final accessToken = await _tokenStorage.getAccessToken();

    final retryOptions = err.requestOptions..extra[_retriedFlag] = true;
    if (accessToken != null && accessToken.isNotEmpty) {
      retryOptions.headers['Authorization'] = 'Bearer $accessToken';
    }

    try {
      final retried = await _dio.fetch<dynamic>(retryOptions);
      handler.resolve(retried);
    } on DioException catch (retryErr) {
      // The shared refresh succeeded but *this* request still failed — that
      // is this request's own error, not a session problem, so it is passed
      // down the chain (to `ErrorInterceptor`) for normal mapping rather
      // than being turned into an AuthFailure here.
      handler.next(retryErr);
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
  ///
  /// Part P-022C note: only ever reached by the request that **owns** the
  /// refresh cycle (or by a request the lock never applied to, i.e. an
  /// already-retried one). Waiters get the same [AuthFailure] via
  /// [_authFailureFor] directly, without re-running (a) or (b) — that is
  /// what keeps "clear + invalidate exactly once" true under concurrency.
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