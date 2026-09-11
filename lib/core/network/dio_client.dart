import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Part P-004 scope: the single, reusable Dio client every feature's data
/// layer depends on.
///
/// Injectable signature for reading the current auth token. Part P-005
/// (secure storage) must expose a function matching this exact signature
/// — e.g. `secureStorage.readAuthToken` — and override
/// [authTokenGetterProvider] with it. Part P-022 (token refresh) calls
/// into whatever P-005 builds behind this same signature; nothing in this
/// file needs to change for either of those parts to land.
typedef AuthTokenGetter = Future<String?> Function();

/// Placeholder token getter until P-005 wires up secure storage.
/// Always resolves to null, so [AuthInterceptor] simply skips attaching
/// an Authorization header — a safe default for any code exercising this
/// provider before P-005 exists.
final authTokenGetterProvider = Provider<AuthTokenGetter>((ref) {
  return () async => null;
});

/// The shared Dio instance for the whole app.
///
/// A `Provider` (not a singleton/global) specifically so it can be
/// overridden in tests via `ProviderContainer(overrides: [...])` or
/// `ProviderScope(overrides: [...])` without any feature code, backend,
/// or real network access required.
///
/// Interceptor order matters and mirrors the part spec exactly:
/// logging (dev-only, sees the raw request/response) → auth (attaches
/// the token before the request goes out) → error (runs last so it sees
/// the final outcome, including anything the earlier interceptors did).
final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  final getToken = ref.watch(authTokenGetterProvider);

  dio.interceptors.addAll([
    LoggingInterceptor(),
    AuthInterceptor(getToken: getToken),
    ErrorInterceptor(),
  ]);

  return dio;
});
