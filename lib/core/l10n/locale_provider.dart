import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../error_reporting.dart';
import '../storage/cache_storage.dart';

/// Part P-112: the app language setting (Follow device / Arabic / English).
///
/// * `Locale?` state: `null` means "follow the device"; otherwise `ar` or
///   `en` (language code only, never a country).
/// * Default rule (Phase 23 overview): the device language when it is `ar`
///   or `en`, otherwise Arabic. [resolveActiveLocale] is the ONE place that
///   implements it; MaterialApp and the Accept-Language interceptor both use
///   it, so the UI language and the language sent to the backend can never
///   disagree.
/// * Persisted through the existing [CacheStorage] under ONE string key and
///   loaded BEFORE the first frame (`main()` awaits [preloadLocale]), exactly
///   like the ThemeMode setting of P-111.
/// * [localeProvider] is the only owner of the language state.

/// The single cache key. Value stored (JSON string): "system" | "ar" | "en".
const String localeCacheKey = 'app.locale';

/// The two languages the product supports.
const List<String> supportedLanguageCodes = <String>['ar', 'en'];

/// Used when the device language is neither Arabic nor English.
const Locale fallbackLocale = Locale('ar');

/// `null` (follow device) is stored as "system".
String localeToStored(Locale? locale) =>
    locale == null ? 'system' : locale.languageCode;

/// Anything that is not exactly "ar" or "en" (missing, junk, wrong type,
/// "system") means "follow the device" (`null`).
Locale? localeFromStored(Object? raw) {
  if (raw is String && supportedLanguageCodes.contains(raw)) {
    return Locale(raw);
  }
  return null;
}

/// The language the app actually uses right now.
///
/// 1. the user's explicit choice, when it is `ar` or `en`;
/// 2. else the PRIMARY device language, when it is `ar` or `en`;
/// 3. else Arabic.
///
/// Always returns a bare language [Locale] (`ar` or `en`).
Locale resolveActiveLocale(Locale? selected, List<Locale> deviceLocales) {
  if (selected != null &&
      supportedLanguageCodes.contains(selected.languageCode)) {
    return Locale(selected.languageCode);
  }
  if (deviceLocales.isNotEmpty &&
      supportedLanguageCodes.contains(deviceLocales.first.languageCode)) {
    return Locale(deviceLocales.first.languageCode);
  }
  return fallbackLocale;
}

/// Plugs the default rule into `MaterialApp.localeListResolutionCallback`
/// (used only while no explicit `locale` is set, i.e. "follow device").
Locale resolveLocaleList(
  List<Locale>? locales,
  Iterable<Locale> supportedLocales,
) {
  return resolveActiveLocale(null, locales ?? const <Locale>[]);
}

/// Reads the stored choice from [cache]. Never throws: a corrupt entry
/// (invalid JSON, wrong type) means "follow the device".
Future<Locale?> loadStoredLocale(CacheStorage cache) async {
  try {
    final Object? raw = await cache.get<Object?>(localeCacheKey);
    return localeFromStored(raw);
  } catch (_) {
    return null;
  }
}

/// Called from `main()` before `runApp`. Never throws.
Future<Locale?> preloadLocale() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return await loadStoredLocale(SharedPreferencesCacheStorage(prefs));
  } catch (error, stack) {
    reportError(error, stack);
    return null;
  }
}

/// The value read before the first frame. `main()` overrides it; tests and
/// any bare `ProviderScope` get `null` (follow device).
final Provider<Locale?> initialLocaleProvider = Provider<Locale?>(
  (Ref ref) => null,
);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => ref.watch(initialLocaleProvider);

  /// Switches the whole app immediately, then persists the choice. `null`
  /// means "follow the device". A language other than `ar`/`en` is treated
  /// as `null`. A failed write is reported but never reverts the in-memory
  /// choice.
  Future<void> setLocale(Locale? locale) async {
    final Locale? next = localeFromStored(locale?.languageCode);
    if (next == state) {
      return;
    }
    state = next;
    try {
      final CacheStorage cache = await ref.read(cacheStorageProvider.future);
      await cache.set<String>(localeCacheKey, localeToStored(next));
    } catch (error, stack) {
      reportError(error, stack);
    }
  }
}

final NotifierProvider<LocaleNotifier, Locale?> localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

/// The device's preferred languages. A provider so tests can fake the device.
typedef DeviceLocalesGetter = List<Locale> Function();

final Provider<DeviceLocalesGetter> deviceLocalesGetterProvider =
    Provider<DeviceLocalesGetter>((Ref ref) {
      return () => PlatformDispatcher.instance.locales;
    });

/// Plain callback that returns the active language code ("ar" or "en").
/// Same pattern as `authTokenGetterProvider`: the Dio interceptor receives
/// this function and never holds a [Ref].
typedef ActiveLanguageCodeGetter = String Function();

final Provider<ActiveLanguageCodeGetter> activeLanguageCodeGetterProvider =
    Provider<ActiveLanguageCodeGetter>((Ref ref) {
      return () {
        final List<Locale> device = ref.read(deviceLocalesGetterProvider)();
        return resolveActiveLocale(
          ref.read(localeProvider),
          device,
        ).languageCode;
      };
    });
