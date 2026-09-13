import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../domain/auth_repository.dart';
import '../domain/user_entity.dart';
import 'dtos/login_request_dto.dart';
import 'dtos/logout_request_dto.dart';
import 'dtos/register_request_dto.dart';
import 'dtos/register_response_dto.dart';
import 'dtos/token_pair_dto.dart';

/// Part P-020 scope: the first real feature data layer built on top of
/// the Phase-1 core layer (`DioClient` from P-004, `SecureTokenStorage`
/// from P-005) — establishes the DTO → repository → domain-entity
/// pattern every future feature is expected to copy.
///
/// Deliberately thin: every method either calls the backend and maps the
/// DTO to a domain type, or reads/writes `SecureTokenStorage` — no
/// re-wrapping of [DioException]s. A failed call surfaces to the caller
/// as-is, with `.error` already a typed `ApiFailure` (Part P-004's
/// `ErrorInterceptor` guarantees this for anything that passed through
/// `dioClientProvider`'s interceptor chain) — callers should catch
/// [DioException] and read `.error`, exactly as `AuthRepository`'s
/// per-method docs describe.
///
/// See `AuthRepository`'s module docstring for the two places this
/// implementation deliberately diverges from the original P-020 part
/// spec's assumptions, confirmed against the real backend instead of
/// guessed.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required Dio dio,
    required SecureTokenStorage tokenStorage,
  }) : _dio = dio,
       _tokenStorage = tokenStorage;

  final Dio _dio;
  final SecureTokenStorage _tokenStorage;

  static const _registerPath = '/api/v1/auth/register/';
  static const _loginPath = '/api/v1/auth/login/';
  static const _refreshPath = '/api/v1/auth/refresh/';
  static const _logoutPath = '/api/v1/auth/logout/';

  @override
  Future<User> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required AccountType accountType,
  }) async {
    final requestDto = RegisterRequestDto(
      email: email,
      password: password,
      passwordConfirm: passwordConfirm,
      accountType: accountType.toWire(),
    );

    final response = await _dio.post<Map<String, dynamic>>(
      _registerPath,
      data: requestDto.toJson(),
    );

    final responseDto = RegisterResponseDto.fromJson(response.data!);

    // No `SecureTokenStorage.saveTokens` call here on purpose: the
    // register endpoint issues no tokens at all — see AuthRepository's
    // module docstring. The caller (Part P-021's UI) must call [login]
    // explicitly afterward if it wants the user signed in immediately.
    return User(
      id: responseDto.id,
      email: responseDto.email,
      accountType: AccountType.fromWire(responseDto.accountType),
    );
  }

  @override
  Future<void> login({required String email, required String password}) async {
    final requestDto = LoginRequestDto(email: email, password: password);

    final response = await _dio.post<Map<String, dynamic>>(
      _loginPath,
      data: requestDto.toJson(),
    );

    final tokens = TokenPairDto.fromJson(response.data!);
    await _tokenStorage.saveTokens(
      access: tokens.access,
      refresh: tokens.refresh,
    );
  }

  @override
  Future<void> refresh() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) {
      throw StateError(
        'AuthRepository.refresh() called with no refresh token stored — '
        'nothing to refresh.',
      );
    }

    final response = await _dio.post<Map<String, dynamic>>(
      _refreshPath,
      data: {'refresh': refreshToken},
    );

    // ROTATE_REFRESH_TOKENS + BLACKLIST_AFTER_ROTATION are both on
    // (Part P-018), so the backend always returns a *new* refresh token
    // here and blacklists the one just presented — the response is
    // therefore always saved in full, never merged with the old pair.
    final tokens = TokenPairDto.fromJson(response.data!);
    await _tokenStorage.saveTokens(
      access: tokens.access,
      refresh: tokens.refresh,
    );
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) {
      // Nothing stored to blacklist server-side; still clear defensively
      // (no-op if already clear) and return without a network call.
      await _tokenStorage.clear();
      return;
    }

    try {
      await _dio.post<Map<String, dynamic>>(
        _logoutPath,
        data: LogoutRequestDto(refresh: refreshToken).toJson(),
      );
    } finally {
      // Always runs, success or failure: a network failure during
      // logout must never leave stale tokens on the device (this part's
      // explicit scope decision). `finally` here — rather than a
      // try/catch that swallows and rethrows — so any exception from
      // the block above still propagates to the caller afterward
      // unmodified.
      await _tokenStorage.clear();
    }
  }
}

/// Exposes [AuthRepository] to the rest of the app via Riverpod, per
/// this project's established pattern (`dioClientProvider`,
/// `secureTokenStorageProvider`) — a `Provider`, not a singleton/global,
/// so it's overridable in tests and in Part P-021's widget tree.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    dio: ref.watch(dioClientProvider),
    tokenStorage: ref.watch(secureTokenStorageProvider),
  );
});
