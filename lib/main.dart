import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/config/app_config.dart';
import 'core/l10n/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/error_reporting.dart';
import 'core/network/dio_client.dart';
import 'core/storage/secure_token_storage.dart';
import 'features/auth/presentation/session_provider.dart';
import 'features/notifications/presentation/push_notification_handler.dart';
import 'features/notifications/presentation/push_session_bridge.dart';
import 'l10n/app_localizations.dart';
import 'routing/app_router.dart';

/// Part P-111: the ThemeMode read from storage BEFORE the first frame
/// (set once in main(), consumed by the ProviderScope override below).
ThemeMode _initialThemeMode = ThemeMode.system;

/// Part P-112: the saved language read from storage BEFORE the first frame
/// (`null` = follow the device). Consumed by the ProviderScope override below.
Locale? _initialLocale;

/// Composition root for the app.
///
/// Bootstrap sequence, finalized in P-008, extended in P-021b:
/// 1. `WidgetsFlutterBinding.ensureInitialized()` — required before any
///    platform-channel call (including the error hooks below).
/// 2. Uncaught Flutter framework errors (`FlutterError.onError`) and
///    everything else (`PlatformDispatcher.instance.onError`) are funneled
///    into the single [reportError] function in `core/error_reporting.dart`.
///    Sentry (Part P-105): in staging/prod builds that were given a DSN
///    (`AppConfig.sentryEnabled`), the whole bootstrap below runs inside
///    `SentryFlutter.init(appRunner: ...)`. The two hooks are installed
///    inside that appRunner, after Sentry has installed its own, so ours
///    replace Sentry's and every uncaught error still reaches Sentry exactly
///    once, through [reportError]. Dev builds and tests never initialize
///    Sentry, so [reportError] is a no-op there.
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
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Part P-111: read the saved ThemeMode BEFORE the first frame, so a user
  // who chose Dark never sees a light flash on launch. Never throws
  // (corrupt or missing value = system).
  _initialThemeMode = await preloadThemeMode();

  // Part P-112: same idea for the language, so a user who chose Arabic
  // never sees English flash on launch. Never throws.
  _initialLocale = await preloadLocale();

  if (AppConfig.sentryEnabled) {
    await SentryFlutter.init((options) {
      options.dsn = AppConfig.sentryDsn;
      options.environment = AppConfig.environment.name;
      options.tracesSampleRate = 0.0; // errors only, no performance traces
      options.sendDefaultPii = false;
      options.addIntegration(_DetachSentryIsolateListener());
    }, appRunner: _installErrorHooksAndRunApp);
  } else {
    _installErrorHooksAndRunApp();
  }
}

/// Sentry registers an `Isolate.addErrorListener` (IsolateErrorIntegration).
/// While that listener exists the Dart VM hands uncaught async errors to it
/// instead of [PlatformDispatcher.onError], so they reach Sentry as a
/// type-less `String` and bypass [reportError]. This integration runs after
/// it (integrations run in list order), closes and removes it, so the P-008
/// hook below is the single path for those errors (P-105).
class _DetachSentryIsolateListener implements Integration<SentryOptions> {
  @override
  void call(Hub hub, SentryOptions options) {
    final listeners =
        options.integrations.whereType<IsolateErrorIntegration>().toList();
    for (final integration in listeners) {
      integration.close();
      options.removeIntegration(integration);
    }
  }

  @override
  void close() {}
}

/// Installs the single [FlutterError.onError] / [PlatformDispatcher] hooks
/// (P-008) and starts the app. Must run AFTER `SentryFlutter.init` when
/// Sentry is enabled, see the note on [main].
void _installErrorHooksAndRunApp() {
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
        initialThemeModeProvider.overrideWithValue(_initialThemeMode),
        initialLocaleProvider.overrideWithValue(_initialLocale),
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
        // Part P-022B: closes the equivalent gap for session invalidation.
        // [RefreshInterceptor] has no [Ref] of its own (it isn't a
        // widget/provider), so it depends on the plain
        // `SessionInvalidator` callback via `sessionInvalidatorProvider`
        // (default no-op in `dio_client.dart`) — wired here, in the
        // composition root, to the real `SessionNotifier.invalidateSession`,
        // exactly mirroring the `authTokenGetterProvider` override above.
        sessionInvalidatorProvider.overrideWith((ref) {
          return () async {
            ref.read(sessionProvider.notifier).invalidateSession();
          };
        }),
      ],
      // Part P-081: registers/unregisters the FCM device token as the
      // session changes (initialize after login, stop on logout). Wrapped
      // here in main(), not inside SocialCommerceApp, so widget tests that
      // pump SocialCommerceApp directly never touch Firebase.
      // Part P-082: foreground banner + notification-tap navigation.
      child: const PushSessionBridge(
        child: PushNotificationHandler(child: SocialCommerceApp()),
      ),
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
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    if (!_bootstrapped) {
      if (session.isLoading) {
        return MaterialApp(
          onGenerateTitle:
              (BuildContext context) => AppLocalizations.of(context).appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          locale: locale,
          localeListResolutionCallback: resolveLocaleList,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
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
      onGenerateTitle:
          (BuildContext context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: locale,
      localeListResolutionCallback: resolveLocaleList,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      scaffoldMessengerKey: ref.watch(rootScaffoldMessengerKeyProvider),
    );
  }
}
