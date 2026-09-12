import 'package:flutter/foundation.dart';

/// Single funnel point for every uncaught error in the app.
///
/// Wired from `main.dart`'s bootstrap sequence (P-008) to both
/// `FlutterError.onError` (framework/widget errors) and
/// `PlatformDispatcher.instance.onError` (everything else, e.g. errors
/// thrown outside the Flutter framework or inside async gaps not caught
/// by a zone).
///
/// The body is intentionally trivial for now (just logs). Its signature —
/// `void reportError(Object error, StackTrace stack)` — is the stable
/// contract Part P-021 (Sentry / crash-reporting integration, Phase 21)
/// will fill in with a real `Sentry.captureException(error, stackTrace:
/// stack)` call. No call site anywhere in the app should need to change
/// when that happens.
// TODO(Phase 21): replace the body with Sentry.captureException —
// signature must not change.
void reportError(Object error, StackTrace stack) {
  debugPrint('[reportError] $error\n$stack');
}