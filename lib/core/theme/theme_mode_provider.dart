import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../error_reporting.dart';
import '../storage/cache_storage.dart';

/// Part P-111: the ThemeMode setting (System / Light / Dark).
///
/// * Persisted through the existing [CacheStorage] (shared_preferences) under
///   ONE string key. An unknown, missing or corrupt value means "system".
/// * Loaded BEFORE the first frame: `main()` awaits [preloadThemeMode] and
///   injects the result through [initialThemeModeProvider], so the app never
///   flashes light and then switches to dark on launch.
/// * [themeModeProvider] is the only owner of theme state. Screens call
///   `ref.read(themeModeProvider.notifier).setThemeMode(...)` and never keep
///   their own copy.

/// The single cache key. Value stored (JSON string): "system" | "light" | "dark".
const String themeModeCacheKey = 'app.theme_mode';

String themeModeToStored(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

/// Anything that is not exactly "light" or "dark" is [ThemeMode.system].
ThemeMode themeModeFromStored(Object? raw) {
  if (raw is String) {
    if (raw == 'light') {
      return ThemeMode.light;
    }
    if (raw == 'dark') {
      return ThemeMode.dark;
    }
  }
  return ThemeMode.system;
}

/// Reads the stored mode from [cache]. Never throws: a corrupt entry
/// (invalid JSON, wrong type) is treated as "system".
Future<ThemeMode> loadStoredThemeMode(CacheStorage cache) async {
  try {
    final Object? raw = await cache.get<Object?>(themeModeCacheKey);
    return themeModeFromStored(raw);
  } catch (_) {
    return ThemeMode.system;
  }
}

/// Called from `main()` before `runApp`. Never throws.
Future<ThemeMode> preloadThemeMode() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return await loadStoredThemeMode(SharedPreferencesCacheStorage(prefs));
  } catch (error, stack) {
    reportError(error, stack);
    return ThemeMode.system;
  }
}

/// The value read before the first frame. `main()` overrides it; tests and any
/// bare `ProviderScope` get [ThemeMode.system].
final Provider<ThemeMode> initialThemeModeProvider = Provider<ThemeMode>(
  (Ref ref) => ThemeMode.system,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  /// Switches the whole app immediately, then persists the choice. A failed
  /// write is reported but never reverts the in-memory choice.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state) {
      return;
    }
    state = mode;
    try {
      final CacheStorage cache = await ref.read(cacheStorageProvider.future);
      await cache.set<String>(themeModeCacheKey, themeModeToStored(mode));
    } catch (error, stack) {
      reportError(error, stack);
    }
  }
}

final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
