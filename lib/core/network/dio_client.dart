import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/secure_token_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/refresh_interceptor.dart';

/// Part P-004 scope: the single, reusable Dio client every feature's data
/// layer depends on.
///
/// Injectable signature for reading the current auth token. Part P-005
/// (secure storage) must expose a function matching this exact signature
/// — e.g. `secureStorage.readAuthToken` — and override
/// [authTokenGetterProvider] with it. This typedef/provider pair itself
/// needed no change for Part P-022A (token refresh) to land — see
/// [RefreshInterceptor]'s addition to [dioClientProvider]'s interceptor
/// chain below instead.
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
///
/// [RefreshInterceptor] (Part P-022A) is appended *last*, i.e. after
/// [ErrorInterceptor], on purpose: Dio runs `onError` in the reverse order
/// of this list (last-added sees an error first), so appending it last
/// means it gets first look at a raw 401 before [ErrorInterceptor] maps
/// it to an [ApiFailure]. If it silently refreshes and retries, the
/// caller never sees that intermediate 401 at all; if it can't handle the
/// error, it calls `handler.next(err)`, which still hands the error off
/// to [ErrorInterceptor] for the usual mapping.
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
  final tokenStorage = ref.watch(secureTokenStorageProvider);

  dio.interceptors.addAll([
    LoggingInterceptor(),
    AuthInterceptor(getToken: getToken),
    ErrorInterceptor(),
    RefreshInterceptor(dio: dio, tokenStorage: tokenStorage),
  ]);

  return dio;
});
