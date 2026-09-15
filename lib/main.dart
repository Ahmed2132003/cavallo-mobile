import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_theme.dart';
import 'core/error_reporting.dart';
import 'core/network/dio_client.dart';
import 'core/storage/secure_token_storage.dart';
import 'features/auth/presentation/session_provider.dart';
import 'routing/app_router.dart';

/// Composition root for the app.
///
/// Bootstrap sequence, finalized in P-008, extended in P-021b:
/// 1. `WidgetsFlutterBinding.ensureInitialized()` — required before any
///    platform-channel call (including the error hooks below).
/// 2. Uncaught Flutter framework errors (`FlutterError.onError`) and
///    everything else (`PlatformDispatcher.instance.onError`) are funneled
///    into the single [reportError] function in `core/error_reporting.dart`.
///    Nothing here calls a real crash-reporting SDK yet — that's Phase 21.
/// 3. `runApp(ProviderScope(child: SocialCommerceApp()))` — exactly one
///    [ProviderScope] for the whole app; no feature should create its own
///    nested one.
/// 4. **(New in P-021b)** [SocialCommerceApp] no longer mounts
///    [MaterialApp.router] immediately — it first waits for
///    [sessionProvider]'s cold-start [SessionNotifier.build] (the token
///    restore, Part P-021a) to resolve, showing a minimal loading UI in
///    the meantime. Only once that initial resolution completes does the
///    real [GoRouter] (whose own redirect guard, also P-021b, now depends
///    on [sessionProvider]) get mounted. This is what the original P-021
///    spec's Part 2 asked for verbatim: "show a splash/loading state
///    until it resolves."
///
/// [AppTheme] was applied app-wide in P-006. As of P-007, navigation goes
/// through the single [GoRouter] instance exposed by [appRouterProvider] —
/// no feature should build a separate `Navigator`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    reportError(details.exception, details.stack ?? StackTrace.empty);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    reportError(error, stack);
    return true;
  };

  runApp(
    ProviderScope(
      overrides: [
        // Closes a gap flagged during P-022A: [authTokenGetterProvider]'s
        // own default (in dio_client.dart) is intentionally a no-op
        // returning null — that default is asserted directly by
        // dio_client_test.dart and must stay that way. The *real* app
        // needs the real getter, so it's wired here in the composition
        // root instead, reading through the same [secureTokenStorageProvider]
        // that [RefreshInterceptor] (Part P-022A) already writes new
        // tokens into after a silent refresh.
        authTokenGetterProvider.overrideWith((ref) {
          final tokenStorage = ref.watch(secureTokenStorageProvider);
          return () => tokenStorage.getAccessToken();
        }),
      ],
      child: const SocialCommerceApp(),
    ),
  );
}

class SocialCommerceApp extends ConsumerStatefulWidget {
  const SocialCommerceApp({super.key});

  @override
  ConsumerState<SocialCommerceApp> createState() => _SocialCommerceAppState();
}

class _SocialCommerceAppState extends ConsumerState<SocialCommerceApp> {
  /// Latches to `true` the first time [sessionProvider]'s cold-start
  /// restore (`SessionNotifier.build()`, Part P-021a) resolves — success
  /// or failure, doesn't matter, just "no longer the very first load."
  ///
  /// Deliberately NOT re-derived from `session.isLoading` on every
  /// `build()` call below: `SessionNotifier.login()`/`logout()` (Part
  /// P-021a) also set `state` back to a bare `AsyncValue.loading()` with
  /// no previous value retained (see that file's own docstring re:
  /// `copyWithPrevious` being `@internal` on this Riverpod version) —
  /// which would be indistinguishable from the cold-start restore if this
  /// flag weren't sticky, and would wrongly tear down the whole router
  /// (LoginScreen included, mid-submit) back to this bootstrap spinner
  /// every single time someone taps "Log in" or "Log out."
  bool _bootstrapped = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (!_bootstrapped) {
      if (session.isLoading) {
        return MaterialApp(
          title: 'Social Commerce Discovery Platform',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      // Falls through the first time build() resolves (AsyncData or
      // AsyncError alike) and never re-enters the branch above again.
      _bootstrapped = true;
    }

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Social Commerce Discovery Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: router,
    );
  }
}