import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_commerce_app/core/l10n/locale_provider.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/theme/theme_mode_provider.dart';
import 'package:social_commerce_app/features/profile_hub/data/language_preference_repository.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/appearance_selector.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/language_selector.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-113 (STEP 3A): the Appearance and Language selectors are thin views
/// over `themeModeProvider` (P-111) and `localeProvider` (P-112).

class _FakeLanguageRepository implements LanguagePreferenceRepository {
  final List<String> saved = <String>[];
  Object? error;

  @override
  Future<void> savePreferredLanguage(String languageCode) async {
    saved.add(languageCode);
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
  }
}

Widget _host(
  _FakeLanguageRepository repository, {
  List<Locale> device = const <Locale>[Locale('en')],
  Locale? initialLocale,
  ThemeMode initialThemeMode = ThemeMode.system,
}) {
  return ProviderScope(
    overrides: [
      languagePreferenceRepositoryProvider.overrideWithValue(repository),
      deviceLocalesGetterProvider.overrideWithValue(() => device),
      initialLocaleProvider.overrideWithValue(initialLocale),
      initialThemeModeProvider.overrideWithValue(initialThemeMode),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Column(
          children: <Widget>[AppearanceSelector(), LanguageSelector()],
        ),
      ),
    ),
  );
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(AppearanceSelector)),
  );
}

Set<ThemeMode> _selectedTheme(WidgetTester tester) {
  return tester
      .widget<SegmentedButton<ThemeMode>>(
        find.byKey(AppearanceSelector.selectorKey),
      )
      .selected;
}

Set<String> _selectedLanguage(WidgetTester tester) {
  return tester
      .widget<SegmentedButton<String>>(find.byKey(LanguageSelector.selectorKey))
      .selected;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('P-113 STEP 3A: AppearanceSelector', () {
    testWidgets('shows the three modes with the provider value selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_FakeLanguageRepository()));

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(_selectedTheme(tester), <ThemeMode>{ThemeMode.system});
    });

    testWidgets('starts from the persisted mode, not from System', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(_FakeLanguageRepository(), initialThemeMode: ThemeMode.dark),
      );

      expect(_selectedTheme(tester), <ThemeMode>{ThemeMode.dark});
    });

    testWidgets('tapping Dark then Light updates themeModeProvider', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_FakeLanguageRepository()));

      await tester.tap(find.byKey(AppearanceSelector.optionKey(ThemeMode.dark)));
      await tester.pumpAndSettle();
      expect(_container(tester).read(themeModeProvider), ThemeMode.dark);
      expect(_selectedTheme(tester), <ThemeMode>{ThemeMode.dark});

      await tester.tap(
        find.byKey(AppearanceSelector.optionKey(ThemeMode.light)),
      );
      await tester.pumpAndSettle();
      expect(_container(tester).read(themeModeProvider), ThemeMode.light);
      expect(_selectedTheme(tester), <ThemeMode>{ThemeMode.light});
    });

    testWidgets('can go back to System', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(_FakeLanguageRepository(), initialThemeMode: ThemeMode.dark),
      );

      await tester.tap(
        find.byKey(AppearanceSelector.optionKey(ThemeMode.system)),
      );
      await tester.pumpAndSettle();

      expect(_container(tester).read(themeModeProvider), ThemeMode.system);
    });
  });

  group('P-113 STEP 3A: LanguageSelector', () {
    testWidgets('each language is written in its own language', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_FakeLanguageRepository()));

      expect(find.text(LanguageSelector.arabicName), findsOneWidget);
      expect(find.text(LanguageSelector.englishName), findsOneWidget);
    });

    testWidgets('follow-device with an English device selects English', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_FakeLanguageRepository()));

      expect(_selectedLanguage(tester), <String>{'en'});
    });

    testWidgets('follow-device with another device language selects Arabic', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          _FakeLanguageRepository(),
          device: const <Locale>[Locale('fr')],
        ),
      );

      expect(_selectedLanguage(tester), <String>{'ar'});
    });

    testWidgets('an explicit choice wins over the device language', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          _FakeLanguageRepository(),
          device: const <Locale>[Locale('en')],
          initialLocale: const Locale('ar'),
        ),
      );

      expect(_selectedLanguage(tester), <String>{'ar'});
    });

    testWidgets('choosing Arabic switches the app and tells the backend', (
      WidgetTester tester,
    ) async {
      final _FakeLanguageRepository repository = _FakeLanguageRepository();
      await tester.pumpWidget(_host(repository));

      await tester.tap(find.byKey(LanguageSelector.optionKey('ar')));
      await tester.pumpAndSettle();

      expect(_container(tester).read(localeProvider), const Locale('ar'));
      expect(_selectedLanguage(tester), <String>{'ar'});
      expect(repository.saved, <String>['ar']);
    });

    testWidgets('choosing English after Arabic sends English', (
      WidgetTester tester,
    ) async {
      final _FakeLanguageRepository repository = _FakeLanguageRepository();
      await tester.pumpWidget(
        _host(repository, initialLocale: const Locale('ar')),
      );

      await tester.tap(find.byKey(LanguageSelector.optionKey('en')));
      await tester.pumpAndSettle();

      expect(_container(tester).read(localeProvider), const Locale('en'));
      expect(repository.saved, <String>['en']);
    });

    testWidgets('a failing backend call keeps the local choice', (
      WidgetTester tester,
    ) async {
      final _FakeLanguageRepository repository =
          _FakeLanguageRepository()..error = Exception('offline');
      await tester.pumpWidget(_host(repository));

      await tester.tap(find.byKey(LanguageSelector.optionKey('ar')));
      await tester.pumpAndSettle();

      expect(repository.saved, <String>['ar']);
      expect(_container(tester).read(localeProvider), const Locale('ar'));
      expect(_selectedLanguage(tester), <String>{'ar'});
      expect(tester.takeException(), isNull);
    });
  });
}
