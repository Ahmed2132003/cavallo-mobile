import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_token_storage.dart';
import '../data/auth_repository_impl.dart';
import '../domain/auth_repository.dart';
import '../domain/user_entity.dart';

/// Part P-021a scope (Part 1 of 3 of the original P-021 scope): the
/// single global source of truth for "who is logged in," per
/// architecture Section 13's state-management-boundaries table. Part
/// P-021b will wire [sessionProvider] into the router's Phase-3 redirect
/// guard and build LoginScreen; Part P-021c will build RegisterScreen.
/// This file builds ONLY [SessionNotifier] — no router changes, no
/// screens, and nothing here calls [sessionProvider] yet.
///
/// `null` state means unauthenticated. A non-null [User] means
/// authenticated. Loading/error states follow Riverpod's normal
/// [AsyncValue] conventions (e.g. a widget can show a spinner while
/// [state] is [AsyncLoading]).
///
/// ### ⚠️ Known simplification — flagged for review, not silent
///
/// The original part spec assumed [login]/[_restoreSession] could
/// "optimistically set state to an authenticated `User`," and explicitly
/// allowed, as a fallback, reconstructing "a minimal User from what's
/// available" if no lightweight profile endpoint exists yet.
///
/// Having read the real `AuthRepository` (Part P-020) before writing any
/// code here — rather than guessing — here is exactly what's available:
///
/// * `POST /api/v1/auth/login/` and `POST /api/v1/auth/refresh/` return
///   **only** `{access, refresh}` — no user fields at all
///   (`AuthRepository.login`/`refresh` both return `Future<void>`,
///   confirmed in that file's own module docstring).
/// * There is no `/me/` endpoint and no JWT-decoding infrastructure
///   anywhere in the app yet — both are called out as open items in
///   `AuthRepository`'s own docstring.
/// * `User` (`user_entity.dart`) has three **required, non-nullable**
///   fields (`id`, `email`, `accountType`) — there is no "unknown yet"
///   representation on that type, and this part is not scoped to add
///   one (its own "Files Expected" lists only this file).
///
/// So whenever this class needs to represent "authenticated" as a
/// non-null `User` without a real profile to back it, it uses
/// [_placeholderAuthenticatedUser] — clearly named, documented at its
/// own declaration, and built from values ([_placeholderUserId],
/// [_placeholderAccountType]) that are explicitly fake. **Nothing should
/// ever branch on those two fields** (e.g. no
/// `if (user.accountType == business)` feature-gating) until a real fix
/// lands — most likely a backend `/me/` endpoint, the same open item
/// `AuthRepository` already flags. This mirrors the "flag it explicitly,
/// don't silently guess" convention this project's backend side uses
/// throughout PROJECT_PROGRESS.md.
///
/// [login]'s placeholder is slightly less fake than
/// [_restoreSession]'s: the caller just typed the real email into a
/// login form, so `email` on the resulting placeholder is accurate.
/// `id`/`accountType` are still fabricated in both cases.
///
/// ### `register()` does not authenticate — by design, not oversight
///
/// `AuthRepository.register()` returns a real `User`, but the register
/// endpoint issues no tokens (confirmed in `AuthRepository`'s own
/// docstring) — so calling it does not actually log anyone in. This
/// class's [register] therefore does NOT touch [state]; it only forwards
/// to `AuthRepository.register` and hands back the real `User` it
/// returns. Per Part P-020's own handoff notes, whether "register and
/// land signed in" should also chain a [login] call afterward is an
/// explicitly open UX decision left to Part P-021c's RegisterScreen —
/// not decided here.
class SessionNotifier extends AsyncNotifier<User?> {
  /// Fake but clearly-labeled placeholder id used only by
  /// [_placeholderAuthenticatedUser] — see this class's docstring. Real
  /// backend ids are positive (Postgres auto-increment starting at 1),
  /// so `-1` can never collide with a genuine id.
  static const _placeholderUserId = -1;

  /// Fake but clearly-labeled placeholder account type used only by
  /// [_placeholderAuthenticatedUser] — see this class's docstring.
  /// `customer` (the lower-privilege of the two roles) is used
  /// deliberately, so that if this placeholder is ever accidentally
  /// branched on before the real fix lands, it fails toward *less*
  /// access rather than more.
  static const _placeholderAccountType = AccountType.customer;

  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  SecureTokenStorage get _tokenStorage => ref.read(secureTokenStorageProvider);

  @override
  Future<User?> build() => _restoreSession();

  /// Silent, best-effort restore attempted on provider initialization
  /// (app start / first read). Checks [SecureTokenStorage] for an
  /// existing access token; if present, optimistically treats the
  /// session as authenticated (see this class's docstring re:
  /// [_placeholderAuthenticatedUser]) and lets the first real API call's
  /// 401 — once Part P-022's refresh-retry interceptor exists — sort out
  /// an actually-expired token. Token *validity* is explicitly not this
  /// part's problem to solve, only "does a token exist" — per the
  /// part's own spec.
  Future<User?> _restoreSession() async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      return null;
    }
    return _placeholderAuthenticatedUser();
  }

  /// Calls `AuthRepository.login`, then transitions [state] to an
  /// authenticated placeholder [User] (see this class's docstring) on
  /// success. On failure, [state] becomes [AsyncError] and the original
  /// exception is rethrown to the caller, so a future LoginScreen (Part
  /// P-021b) can both react to [state] reactively *and* catch the
  /// exception directly for inline field errors (e.g. a
  /// `ValidationFailure`'s `fields['email']`, per Part P-004).
  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue<User?>.loading();
    try {
      await _authRepository.login(email: email, password: password);
      state = AsyncValue.data(_placeholderAuthenticatedUser(email: email));
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
  Future<void> logout() async {
    state = const AsyncValue<User?>.loading();
    try {
      await _authRepository.logout();
    } finally {
      state = const AsyncValue.data(null);
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

  /// Builds the fake-but-clearly-labeled "authenticated" placeholder
  /// described in this class's docstring. [email] is genuinely accurate
  /// when the caller just typed it into a login form ([login]); left at
  /// its default (empty string) when nothing at all is known beyond "a
  /// token exists" ([_restoreSession]).
  User _placeholderAuthenticatedUser({String email = ''}) {
    return User(
      id: _placeholderUserId,
      email: email,
      accountType: _placeholderAccountType,
    );
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
