import 'user_entity.dart';

/// Part P-020 scope: the domain-facing contract every future auth UI
/// (Part P-021) and the Dio refresh-interceptor wiring (Part P-022)
/// depend on. The implementation (auth_repository_impl.dart) is the only
/// thing that knows this is backed by HTTP/DTOs/secure storage.
///
/// ### Deviation from the original P-020 part spec — documented, not
/// silent
/// The part spec (PROJECT_PROGRESS.md's P-020 entry) assumed a single
/// `AuthResponseDto` with `access`/`refresh`/"whatever minimal user
/// fields the backend returns" and asked for `Future<User> login(...)`.
/// The spec's own "BEFORE CODING" step required confirming the real
/// backend contract instead of guessing — doing that against
/// `accounts/serializers.py` + `accounts/views.py` (Parts P-017/P-018)
/// found:
///
/// * `POST /api/v1/auth/register/` → `{id, email, account_type}` —
///   **no tokens**. Confirmed in PROJECT_PROGRESS.md's P-017 section:
///   "لا يتم إصدار JWT ولا تسجيل دخول تلقائي بعد التسجيل" (no JWT is
///   issued and there is no automatic login after registration).
/// * `POST /api/v1/auth/login/` and `POST /api/v1/auth/refresh/` both →
///   `{access, refresh}` only — **no user fields at all** (confirmed
///   against `login.json`/the real login response and
///   `LoginView.post`/`RefreshView`).
///
/// So a single `Future<User> login(...)` signature would have forced
/// this layer to either fabricate `id`/`accountType` from nothing or
/// decode the JWT for a bare `user_id` claim and guess the rest — both
/// are "guessing field names/values," which the spec explicitly forbids.
/// Instead:
/// * [register] is the only method that returns a [User] directly from
///   its own response, because it's the only endpoint that actually
///   returns user fields in the same call.
/// * [login] and [refresh] return `Future<void>` — they only persist the
///   token pair. Real user identity after either call comes from
///   [fetchMe], below.
///
/// ### `fetchMe()` — the accountType placeholder fix
///
/// Part P-021a originally had to fabricate a placeholder `User`
/// (`id: -1`, `accountType: AccountType.customer`) after [login]/restore,
/// since no `/me/`-style endpoint existed yet — flagged explicitly at the
/// time as "nothing should ever branch on this until a real fix lands."
/// `GET /api/v1/auth/me/` now exists on the backend (returns
/// `{id, email, account_type}` for the authenticated user, confirmed
/// against `accounts/views.py`'s `MeView`), so [fetchMe] replaces that
/// placeholder with real data. `SessionNotifier` (presentation layer)
/// calls this after [login] succeeds and during session restore instead
/// of fabricating anything.
abstract class AuthRepository {
  /// Calls `POST /api/v1/auth/register/`. Does NOT persist any tokens
  /// (the backend issues none on this endpoint — see this file's
  /// docstring) and does NOT log the user in. Throws via the underlying
  /// `DioException.error` (an `ApiFailure`, per Part P-004) on failure —
  /// e.g. a `ValidationFailure` with `fields['email']` set for a
  /// duplicate email.
  Future<User> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required AccountType accountType,
  });

  /// Calls `POST /api/v1/auth/login/`. On success, persists the returned
  /// `access`/`refresh` pair via `SecureTokenStorage.saveTokens` before
  /// returning. Returns nothing else — see this file's docstring for
  /// why there is no `User` to return here; call [fetchMe] afterward for
  /// real identity data.
  Future<void> login({required String email, required String password});

  /// Calls `POST /api/v1/auth/refresh/` using the currently stored
  /// refresh token, and persists the rotated `access`/`refresh` pair the
  /// backend returns (`ROTATE_REFRESH_TOKENS`/`BLACKLIST_AFTER_ROTATION`
  /// are both on — Part P-018 — so the old refresh token is blacklisted
  /// server-side the moment this succeeds).
  ///
  /// Standalone/callable on its own in this part — wiring this into
  /// DioClient's error-interceptor automatic-retry-on-401 flow is Part
  /// P-022, not this one.
  ///
  /// Throws [StateError] if there is no refresh token currently stored
  /// (nothing to refresh) before ever making a network call.
  Future<void> refresh();

  /// Calls `POST /api/v1/auth/logout/` with the currently stored refresh
  /// token (the access token is attached automatically by
  /// `AuthInterceptor`, since `LogoutView` requires
  /// `IsAuthenticated` — Part P-018). Local tokens are always cleared via
  /// `SecureTokenStorage.clear()` afterward, regardless of whether the
  /// backend call itself succeeded, so a network failure during logout
  /// never leaves stale tokens on the device.
  ///
  /// If the backend call itself failed, that failure is still rethrown
  /// to the caller *after* local cleanup has already happened — since
  /// server-side blacklisting matters for security even though local
  /// cleanup always happens regardless (this part's explicit scope
  /// decision, per its own spec).
  ///
  /// No-ops (clears local state, makes no network call) if there is no
  /// refresh token currently stored — there is nothing to blacklist.
  Future<void> logout();

  /// Calls `GET /api/v1/auth/me/` — requires a valid access token
  /// (attached automatically by `AuthInterceptor`, same as [logout]).
  /// Returns the authenticated user's real `id`/`email`/`accountType`.
  ///
  /// Does NOT catch/re-wrap `DioException`, matching every other method
  /// on this interface — a 401 (expired/invalid token) surfaces to the
  /// caller exactly like any other `ApiFailure`, with `.error` already
  /// typed as `AuthFailure` (Part P-004). `SessionNotifier` is the layer
  /// that decides what a 401 here means for session state, not this
  /// repository.
  Future<User> fetchMe();
}