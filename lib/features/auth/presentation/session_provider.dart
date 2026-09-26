import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../../social/presentation/social_interaction_provider.dart';
import '../data/auth_repository_impl.dart';
import '../domain/auth_repository.dart';
import '../domain/user_entity.dart';

/// Part P-021a scope (Part 1 of 3 of the original P-021 scope): the
/// single global source of truth for "who is logged in," per
/// architecture Section 13's state-management-boundaries table. Part
/// P-021b wired [sessionProvider] into the router's Phase-3 redirect
/// guard and built LoginScreen; Part P-021c built RegisterScreen.
///
/// `null` state means unauthenticated. A non-null [User] means
/// authenticated. Loading/error states follow Riverpod's normal
/// [AsyncValue] conventions (e.g. a widget can show a spinner while
/// [state] is [AsyncLoading]).
///
/// ### accountType placeholder — now resolved, not a workaround
///
/// This class originally (Part P-021a) had to fabricate a placeholder
/// `User` (`id: -1`, `accountType: AccountType.customer`) after
/// [login]/session restore, since no endpoint existed yet to fetch the
/// real signed-in user's identity — flagged explicitly at the time as
/// "nothing should ever branch on this until a real fix lands," and
/// repeatedly re-flagged by every part downstream (P-028A/B/C) as the
/// single blocker preventing a real business-account router gate.
///
/// `GET /api/v1/auth/me/` now exists on the backend
/// (`AuthRepository.fetchMe()`, confirmed against the real
/// `accounts/views.py`'s `MeView`) and returns the authenticated user's
/// real `id`/`email`/`accountType`. [_restoreSession] and [login] both
/// call it now — there is no longer a placeholder anywhere in this
/// class, and code elsewhere (e.g. router redirect guards) can safely
/// branch on `user.accountType`.
///
/// ### `register()` does not authenticate — by design, not oversight
///
/// `AuthRepository.register()` returns a real `User`, but the register
/// endpoint issues no tokens (confirmed in `AuthRepository`'s own
/// docstring) — so calling it does not actually log anyone in. This
/// class's [register] therefore does NOT touch [state]; it only forwards
/// to `AuthRepository.register` and hands back the real `User` it
/// returns. Per Part P-021c's own decision, `RegisterScreen` chains a
/// [login] call after a successful [register] to sign the user in
/// immediately — which now also transitively fetches their real
/// `accountType` via [login]'s own call to [fetchMe], below.
class SessionNotifier extends AsyncNotifier<User?> {
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  SecureTokenStorage get _tokenStorage => ref.read(secureTokenStorageProvider);

  @override
  Future<User?> build() => _restoreSession();

  /// Restore attempted on provider initialization (app start / first
  /// read). Checks [SecureTokenStorage] for an existing access token; if
  /// present, fetches the real signed-in user via
  /// `AuthRepository.fetchMe()`.
  ///
  /// If the stored token is no longer valid, `fetchMe()` fails with a
  /// `DioException` whose `.error` is an [AuthFailure] (401/403, Part
  /// P-004) — that specific case is treated exactly like an expired
  /// session: locally-stored tokens are cleared (mirroring [logout]'s
  /// own "always clear locally" convention) and this resolves to `null`
  /// (unauthenticated), not an error. Any *other* failure (network
  /// error, 5xx, an unexpected shape) is NOT swallowed here — it
  /// propagates and this provider's state becomes [AsyncError], since a
  /// transient network blip is a real problem to surface, not silently
  /// a logged-out user.
  Future<User?> _restoreSession() async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      return null;
    }

    try {
      return await _authRepository.fetchMe();
    } on DioException catch (error) {
      if (error.error is AuthFailure) {
        await _tokenStorage.clear();
        return null;
      }
      rethrow;
    }
  }

  /// Calls `AuthRepository.login`, then fetches the real signed-in user
  /// via `AuthRepository.fetchMe()` and transitions [state] to it on
  /// success. On failure of either call, [state] becomes [AsyncError]
  /// and the original exception is rethrown to the caller, so
  /// LoginScreen (Part P-021b) can both react to [state] reactively
  /// *and* catch the exception directly for inline field errors (e.g. a
  /// `ValidationFailure`'s `fields['email']`, per Part P-004).
  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue<User?>.loading();
    try {
      await _authRepository.login(email: email, password: password);
      final user = await _authRepository.fetchMe();
      state = AsyncValue.data(user);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Calls `AuthRepository.register` and returns the real [User] it
  /// creates. Deliberately does NOT touch [state] — see this class's
  /// docstring for why registering does not, by itself, log anyone in.
  ///
  /// Any failure propagates directly to the caller unmodified — there is
  /// no session state to roll back, since none was ever changed.
  Future<User> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required AccountType accountType,
  }) {
    return _authRepository.register(
      email: email,
      password: password,
      passwordConfirm: passwordConfirm,
      accountType: accountType,
    );
  }

  /// Calls `AuthRepository.logout`. `AuthRepository.logout()` always
  /// clears locally-stored tokens before rethrowing any backend failure
  /// (see its own docstring) — so [state] always ends up unauthenticated
  /// (`null`) here, success or failure, matching what actually happened
  /// on-device. A `finally` block (mirroring `AuthRepositoryImpl.logout`'s
  /// own use of the same pattern) guarantees this without swallowing a
  /// backend failure: if the call above throws, that exception still
  /// propagates to the caller after [state] has been updated, so a
  /// future screen can show e.g. "signed out on this device, but the
  /// server logout failed" messaging if it wants to.
  ///
  /// Part BUGFIX-058: also force-clears every live
  /// `contentInteractionProvider`/`businessFollowProvider` instance
  /// (`social_interaction_provider.dart`) in the same `finally` block, so
  /// a still-mounted `ContentActionRow`/`FollowButton` never keeps showing
  /// the just-logged-out account's Like/Save/Follow state to whichever
  /// account signs in next in this same running app session. This is
  /// unconditional (success or failure of the backend call above) because
  /// the local session is unauthenticated either way. Paired with making
  /// both providers `.autoDispose` (same file) — that reclaims a key once
  /// nothing is watching it; this guarantees immediate correctness even
  /// for a key some still-mounted widget is actively watching right now.
  Future<void> logout() async {
    state = const AsyncValue<User?>.loading();
    try {
      await _authRepository.logout();
    } finally {
      state = const AsyncValue.data(null);
      ref.invalidate(contentInteractionProvider);
      ref.invalidate(businessFollowProvider);
    }
  }

  /// Part P-022B: the "minimal invalidation entrypoint" a non-widget
  /// context (namely `RefreshInterceptor`, via `SessionInvalidator` /
  /// `sessionInvalidatorProvider` in `core/network/dio_client.dart`) needs
  /// when a token refresh definitively fails.
  ///
  /// Synchronously resets [state] to unauthenticated (`null`) — the same
  /// end state [logout] reaches, minus the backend call and the local
  /// `AsyncLoading` transition, since by the time this is invoked the
  /// caller (`RefreshInterceptor`) has already decided the session is
  /// unrecoverable and is about to reject the in-flight request with an
  /// `AuthFailure`. Deliberately does **not** touch [SecureTokenStorage]
  /// itself — the caller is expected to have already cleared it (or to do
  /// so independently); this method's only job is to flip in-memory state
  /// so the router's redirect guard (Part P-021b) reacts immediately and
  /// sends the user to `/login`.
  void invalidateSession() {
    state = const AsyncValue.data(null);
  }
}

/// Exposes [SessionNotifier] to the rest of the app, per this project's
/// established Riverpod pattern (`authRepositoryProvider`,
/// `secureTokenStorageProvider`) — a plain `AsyncNotifierProvider`, no
/// code-gen (`pubspec.yaml` pins `flutter_riverpod: 3.3.2` with no
/// `riverpod_generator`/`riverpod_annotation` dependency, confirmed
/// before writing this file — not assumed). NOT `.autoDispose` — this is
/// meant to live for the whole app session, per architecture Section 13.
final sessionProvider = AsyncNotifierProvider<SessionNotifier, User?>(
  SessionNotifier.new,
);