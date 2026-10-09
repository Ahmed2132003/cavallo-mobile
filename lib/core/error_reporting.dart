import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Single funnel point for every uncaught error in the app.
///
/// Wired from `main.dart`'s bootstrap sequence (P-008) to both
/// `FlutterError.onError` (framework/widget errors) and
/// `PlatformDispatcher.instance.onError` (everything else, e.g. errors
/// thrown outside the Flutter framework or inside async gaps not caught
/// by a zone).
///
/// Part P-105: the body now forwards to `Sentry.captureException`. The
/// signature - `void reportError(Object error, StackTrace stack)` - is the
/// stable contract P-008 promised and is unchanged, so no call site anywhere
/// in the app needed to change.
///
/// Safe everywhere: when Sentry has not been initialized (dev builds, the
/// test run) `Sentry.captureException` does nothing. This function is the
/// last line of defence for errors, so it must never throw or leak an
/// unhandled async error of its own (that would loop back into
/// `PlatformDispatcher.instance.onError`, which calls this function).
///
/// The console line is kept for debug builds only, so local development
/// still shows every reported error.
void reportError(Object error, StackTrace stack) {
  if (kDebugMode) {
    debugPrint('[reportError] $error\n$stack');
  }
  try {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stack,
      ).then<void>((_) {}, onError: (Object _) {}),
    );
  } catch (_) {
    // Intentionally swallowed: reporting must never throw.
  }
}
