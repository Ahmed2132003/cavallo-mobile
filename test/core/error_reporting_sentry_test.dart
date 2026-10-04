import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:social_commerce_app/core/config/app_config.dart';
import 'package:social_commerce_app/core/error_reporting.dart';

/// Part P-105 STEP 4. Nothing here leaves the process: the Sentry client used
/// below is a real one, but its beforeSend hook captures the event and drops it.
void main() {
  group('AppConfig Sentry values (plain test run = dev, no dart-define)', () {
    test('sentryDsn is empty and sentryEnabled is false', () {
      expect(AppConfig.sentryDsn, isEmpty);
      expect(AppConfig.sentryEnabled, isFalse);
    });
  });

  group('reportError -> Sentry', () {
    test('is safe when Sentry is not initialized (dev and default tests)', () {
      expect(
        () => reportError(StateError('no sentry'), StackTrace.current),
        returnsNormally,
      );
    });

    test('forwards the error to Sentry.captureException', () async {
      final captured = <SentryEvent>[];
      await Sentry.init((options) {
        options.dsn = 'https://publickey@o0.ingest.example.invalid/1';
        options.beforeSend = (event, hint) {
          captured.add(event);
          return null; // drop the event: nothing is sent anywhere
        };
      });
      addTearDown(Sentry.close);

      reportError(StateError('p105-sentry-test'), StackTrace.current);

      // reportError is fire-and-forget (void), so wait for the async pipeline.
      for (var i = 0; i < 100 && captured.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(captured, hasLength(1));
      final exceptions = captured.single.exceptions;
      expect(exceptions, isNotNull);
      expect(exceptions!.first.value, contains('p105-sentry-test'));
    });
  });
}
