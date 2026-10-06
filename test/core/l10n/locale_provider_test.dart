import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_commerce_app/core/l10n/locale_provider.dart';

/// Part P-112 STEP 4: the language setting, its persistence and the default
/// rule (device language if ar/en, otherwise Arabic).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('stored value parsing', () {
    test('ar and en round-trip', () {
      for (final String code in supportedLanguageCodes) {
        expect(localeFromStored(localeToStored(Locale(code))), Locale(code));
      }
    });

    test('null is stored as "system" and read back as null', () {
      expect(localeToStored(null), 'system');
      expect(localeFromStored('system'), isNull);
    });

    test('missing, junk and wrong types mean follow-the-device', () {
      expect(localeFromStored(null), isNull);
      expect(localeFromStored(''), isNull);
      expect(localeFromStored('fr'), isNull);
      expect(localeFromStored('AR'), isNull);
      expect(localeFromStored('ar-EG'), isNull);
      expect(localeFromStored(42), isNull);
      expect(localeFromStored(<String, dynamic>{'a': 1}), isNull);
    });
  });

  group('resolveActiveLocale (the default rule)', () {
    test('an explicit Arabic or English choice always wins', () {
      expect(
        resolveActiveLocale(const Locale('ar'), const <Locale>[Locale('en')]),
        const Locale('ar'),
      );
      expect(
        resolveActiveLocale(const Locale('en'), const <Locale>[Locale('ar')]),
        const Locale('en'),
      );
    });

    test('follow device: an Arabic or English device keeps its language', () {
      expect(
        resolveActiveLocale(null, const <Locale>[Locale('en', 'US')]),
        const Locale('en'),
      );
      expect(
        resolveActiveLocale(null, const <Locale>[Locale('ar', 'EG')]),
        const Locale('ar'),
      );
    });

    test('follow device: any other device language becomes Arabic', () {
      expect(
        resolveActiveLocale(null, const <Locale>[Locale('fr')]),
        const Locale('ar'),
      );
      // Only the PRIMARY device language counts.
      expect(
        resolveActiveLocale(null, const <Locale>[Locale('fr'), Locale('en')]),
        const Locale('ar'),
      );
    });

    test('follow device: no device locales at all becomes Arabic', () {
      expect(resolveActiveLocale(null, const <Locale>[]), const Locale('ar'));
    });

    test('an unsupported explicit choice is ignored', () {
      expect(
        resolveActiveLocale(const Locale('fr'), const <Locale>[Locale('en')]),
        const Locale('en'),
      );
    });

    test('result is always a bare language locale', () {
      expect(
        resolveActiveLocale(const Locale('ar', 'EG'), const <Locale>[]),
        const Locale('ar'),
      );
    });
  });

  group('preloadLocale (persistence across restarts)', () {
    test('nothing stored means follow the device', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await preloadLocale(), isNull);
    });

    test('restores ar and en', () async {
      for (final String code in supportedLanguageCodes) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          localeCacheKey: '"$code"',
        });
        expect(await preloadLocale(), Locale(code));
      }
    });

    test('"system" and corrupt values mean follow the device', () async {
      for (final String junk in <String>[
        '"system"',
        '{{{',
        '"banana"',
        '42',
        'null',
      ]) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          localeCacheKey: junk,
        });
        expect(await preloadLocale(), isNull, reason: junk);
      }
    });
  });

  group('localeProvider', () {
    test('starts from initialLocaleProvider', () {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer container = ProviderContainer(
        overrides: [initialLocaleProvider.overrideWithValue(const Locale('en'))],
      );
      addTearDown(container.dispose);
      expect(container.read(localeProvider), const Locale('en'));
    });

    test('setLocale updates the state and survives a "restart"', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(localeProvider.notifier).setLocale(const Locale('ar'));
      expect(container.read(localeProvider), const Locale('ar'));
      expect(await preloadLocale(), const Locale('ar'));

      await container.read(localeProvider.notifier).setLocale(const Locale('en'));
      expect(container.read(localeProvider), const Locale('en'));
      expect(await preloadLocale(), const Locale('en'));
    });

    test('setLocale(null) goes back to following the device', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        localeCacheKey: '"ar"',
      });
      final ProviderContainer container = ProviderContainer(
        overrides: [initialLocaleProvider.overrideWithValue(const Locale('ar'))],
      );
      addTearDown(container.dispose);

      await container.read(localeProvider.notifier).setLocale(null);
      expect(container.read(localeProvider), isNull);
      expect(await preloadLocale(), isNull);
    });

    test('an unsupported language is treated as follow-the-device', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(localeProvider.notifier).setLocale(const Locale('fr'));
      expect(container.read(localeProvider), isNull);
    });
  });

  group('activeLanguageCodeGetterProvider (what Accept-Language sends)', () {
    ProviderContainer build({Locale? selected, required List<Locale> device}) {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          initialLocaleProvider.overrideWithValue(selected),
          deviceLocalesGetterProvider.overrideWithValue(() => device),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('follows the explicit choice', () {
      final ProviderContainer c = build(
        selected: const Locale('en'),
        device: const <Locale>[Locale('ar')],
      );
      expect(c.read(activeLanguageCodeGetterProvider)(), 'en');
    });

    test('follows an English device', () {
      final ProviderContainer c = build(device: const <Locale>[Locale('en', 'GB')]);
      expect(c.read(activeLanguageCodeGetterProvider)(), 'en');
    });

    test('a French device gets Arabic', () {
      final ProviderContainer c = build(device: const <Locale>[Locale('fr')]);
      expect(c.read(activeLanguageCodeGetterProvider)(), 'ar');
    });

    test('changes live when the user switches language', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer c = build(device: const <Locale>[Locale('fr')]);
      final ActiveLanguageCodeGetter getter = c.read(activeLanguageCodeGetterProvider);
      expect(getter(), 'ar');
      await c.read(localeProvider.notifier).setLocale(const Locale('en'));
      expect(getter(), 'en');
    });
  });
}
