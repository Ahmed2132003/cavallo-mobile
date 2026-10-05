import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/theme/theme_mode_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P-111 STEP 2: stored value parsing', () {
    test('every ThemeMode round-trips', () {
      for (final ThemeMode mode in ThemeMode.values) {
        expect(themeModeFromStored(themeModeToStored(mode)), mode);
      }
    });

    test('null, junk and wrong types mean system', () {
      expect(themeModeFromStored(null), ThemeMode.system);
      expect(themeModeFromStored(''), ThemeMode.system);
      expect(themeModeFromStored('banana'), ThemeMode.system);
      expect(themeModeFromStored('DARK'), ThemeMode.system);
      expect(themeModeFromStored(42), ThemeMode.system);
      expect(themeModeFromStored(<String, dynamic>{'a': 1}), ThemeMode.system);
    });
  });

  group('P-111 STEP 2: preloadThemeMode (persistence across restarts)', () {
    test('nothing stored means system', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await preloadThemeMode(), ThemeMode.system);
    });

    test('restores light, dark and system', () async {
      for (final ThemeMode mode in ThemeMode.values) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          themeModeCacheKey: '"${themeModeToStored(mode)}"',
        });
        expect(await preloadThemeMode(), mode);
      }
    });

    test('corrupt stored values are treated as system', () async {
      for (final String junk in <String>['{{{', '"banana"', '42', 'null']) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          themeModeCacheKey: junk,
        });
        expect(await preloadThemeMode(), ThemeMode.system, reason: junk);
      }
    });
  });

  group('P-111 STEP 2: themeModeProvider', () {
    test('starts from initialThemeModeProvider', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        themeModeCacheKey: '"light"',
      });
      final ThemeMode initial = await preloadThemeMode();
      final ProviderContainer container = ProviderContainer(
        overrides: [initialThemeModeProvider.overrideWithValue(initial)],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('setThemeMode updates state and persists one string key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(themeModeCacheKey), '"dark"');

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.system);
      expect(prefs.getString(themeModeCacheKey), '"system"');
      expect(await preloadThemeMode(), ThemeMode.system);
    });
  });

  group('P-111 STEP 2: live switching in a MaterialApp', () {
    Widget app(void Function(WidgetRef ref) capture) {
      return ProviderScope(
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            capture(ref);
            return MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: ref.watch(themeModeProvider),
              home: Builder(
                builder:
                    (BuildContext context) =>
                        Text(Theme.of(context).brightness.name),
              ),
            );
          },
        ),
      );
    }

    testWidgets('changing ThemeMode switches the whole app live', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      late WidgetRef ref;
      await tester.pumpWidget(app((WidgetRef r) => ref = r));
      expect(find.text('light'), findsOneWidget);

      unawaited(
        ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
      );
      await tester.pumpAndSettle();
      expect(find.text('dark'), findsOneWidget);

      unawaited(
        ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
      );
      await tester.pumpAndSettle();
      expect(find.text('light'), findsOneWidget);
    });

    testWidgets('system mode follows the OS brightness live', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      late WidgetRef ref;

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(app((WidgetRef r) => ref = r));
      expect(ref.read(themeModeProvider), ThemeMode.system);
      expect(find.text('light'), findsOneWidget);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(find.text('dark'), findsOneWidget);
    });
  });
}
