import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_theme.dart';
import 'core/error_reporting.dart';
import 'routing/app_router.dart';

/// Composition root for the app.
///
/// Bootstrap sequence, finalized in P-008:
/// 1. `WidgetsFlutterBinding.ensureInitialized()` — required before any
///    platform-channel call (including the error hooks below).
/// 2. Uncaught Flutter framework errors (`FlutterError.onError`) and
///    everything else (`PlatformDispatcher.instance.onError`) are funneled
///    into the single [reportError] function in `core/error_reporting.dart`.
///    Nothing here calls a real crash-reporting SDK yet — that's Phase 21.
/// 3. `runApp(ProviderScope(child: SocialCommerceApp()))` — exactly one
///    [ProviderScope] for the whole app; no feature should create its own
///    nested one.
///
/// [AppTheme] was applied app-wide in P-006. As of P-007, navigation goes
/// through the single [GoRouter] instance exposed by [appRouterProvider] —
/// [SocialCommerceApp] is a [ConsumerWidget] so it can watch that provider
/// and pass it to [MaterialApp.router]. No feature should build a separate
/// `Navigator`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    reportError(details.exception, details.stack ?? StackTrace.empty);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    reportError(error, stack);
    return true;
  };

  runApp(const ProviderScope(child: SocialCommerceApp()));
}

class SocialCommerceApp extends ConsumerWidget {
  const SocialCommerceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Social Commerce Discovery Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: router,
    );
  }
}