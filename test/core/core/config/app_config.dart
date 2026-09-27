import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Part P-003 scope: config layer only.
///
/// Reads values passed at build/run time via `--dart-define` (see CONFIG.md
/// for the exact invocation pattern), with sane dev defaults so the app runs
/// out of the box with zero flags. This does not wire up networking itself
/// (Dio client setup is P-010+) — it only exposes where those values live.

/// Which backend environment this build is pointed at.
enum AppEnvironment { dev, staging, prod }

class AppConfig {
  AppConfig._();

  /// The environment this build was compiled for.
  ///
  /// Pass via `--dart-define=ENVIRONMENT=staging` (or `prod`). Defaults to
  /// `dev` so a plain `flutter run` with no flags behaves as local dev.
  static AppEnvironment get environment {
    const raw = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');
    switch (raw) {
      case 'staging':
        return AppEnvironment.staging;
      case 'prod':
        return AppEnvironment.prod;
      case 'dev':
      default:
        return AppEnvironment.dev;
    }
  }

  /// The backend API base URL for this build.
  ///
  /// Always overridable directly with `--dart-define=API_BASE_URL=...` —
  /// this takes priority over everything below, and is the only way to
  /// reach a backend from a real device on the local network (neither
  /// `localhost` nor `10.0.2.2` works there; use the host machine's LAN
  /// IP instead, e.g. `http://192.168.1.23:8095`).
  ///
  /// Without an explicit override, the dev default picks a sane value per
  /// platform, since "localhost" means different things to different
  /// targets when the backend runs in Docker on the host machine (Django
  /// dev server exposed at host port 8095 — see P-000's port table in
  /// PROJECT_PROGRESS.md, updated in P-021b after a host port collision
  /// with an unrelated Wondershare service on 8090):
  ///   - Android emulator: `localhost` refers to the emulator itself, not
  ///     the host machine, so it must use the special alias `10.0.2.2`.
  ///   - iOS Simulator and desktop: `localhost` correctly reaches the host
  ///     machine directly.
  /// Staging/prod builds should always pass `API_BASE_URL` explicitly
  /// rather than relying on any default here.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    switch (environment) {
      case AppEnvironment.dev:
        return _devDefaultBaseUrl;
      case AppEnvironment.staging:
      case AppEnvironment.prod:
        // No default on purpose — staging/prod must pass API_BASE_URL
        // explicitly. Falling back silently here would risk a
        // staging/prod build quietly talking to a local dev backend.
        throw StateError(
          'API_BASE_URL must be passed explicitly via --dart-define for '
          'the ${environment.name} environment.',
        );
    }
  }

  static const int _devBackendPort = 8095;

  static String get _devDefaultBaseUrl {
    if (kIsWeb) {
      // dart:io's Platform isn't available on web at all.
      return 'http://localhost:$_devBackendPort';
    }
    if (Platform.isAndroid) {
      // 10.0.2.2 is the Android emulator's alias for the host machine.
      // A real Android device on the same network still needs an explicit
      // --dart-define=API_BASE_URL=http://<host-lan-ip>:8095 override.
      return 'http://10.0.2.2:$_devBackendPort';
    }
    return 'http://localhost:$_devBackendPort';
  }
}