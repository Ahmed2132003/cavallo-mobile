import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_commerce_app/core/l10n/locale_provider.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-112 STEP 4: the MaterialApp wiring (same arguments main.dart uses)
/// really flips language AND direction, live, and applies the default rule.
const Key _textKey = Key('minutes');
const Key _directionKey = Key('direction');

class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      locale: ref.watch(localeProvider),
      localeListResolutionCallback: resolveLocaleList,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _Probe(),
    );
  }
}

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Text(
            AppLocalizations.of(context).relativeMinutesAgo(2),
            key: _textKey,
          ),
          Text('${Directionality.of(context)}', key: _directionKey),
        ],
      ),
    );
  }
}

String _textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required List<Locale> device,
    Locale? stored,
  }) async {
    tester.platformDispatcher.localesTestValue = device;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final ProviderContainer container = ProviderContainer(
      overrides: [initialLocaleProvider.overrideWithValue(stored)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _TestApp()),
    );
    await tester.pump();
    return container;
  }

  testWidgets('English device: English text, left-to-right', (tester) async {
    await pumpApp(tester, device: const <Locale>[Locale('en', 'US')]);
    expect(_textOf(tester, _textKey), '2 minutes ago');
    expect(_textOf(tester, _directionKey), 'TextDirection.ltr');
  });

  testWidgets('Arabic device: Arabic text, right-to-left', (tester) async {
    await pumpApp(tester, device: const <Locale>[Locale('ar', 'EG')]);
    expect(_textOf(tester, _textKey), '\u0645\u0646\u0630 \u062f\u0642\u064a\u0642\u062a\u064a\u0646');
    expect(_textOf(tester, _directionKey), 'TextDirection.rtl');
  });

  testWidgets('French device falls back to Arabic (default rule)', (tester) async {
    await pumpApp(tester, device: const <Locale>[Locale('fr')]);
    expect(_textOf(tester, _textKey), '\u0645\u0646\u0630 \u062f\u0642\u064a\u0642\u062a\u064a\u0646');
    expect(_textOf(tester, _directionKey), 'TextDirection.rtl');
  });

  testWidgets('a stored choice beats the device language', (tester) async {
    await pumpApp(
      tester,
      device: const <Locale>[Locale('en')],
      stored: const Locale('ar'),
    );
    expect(_textOf(tester, _directionKey), 'TextDirection.rtl');
  });

  testWidgets('switching language flips text and direction live', (tester) async {
    final ProviderContainer container = await pumpApp(
      tester,
      device: const <Locale>[Locale('en')],
    );
    expect(_textOf(tester, _directionKey), 'TextDirection.ltr');

    await tester.runAsync(
      () => container.read(localeProvider.notifier).setLocale(const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(_textOf(tester, _textKey), '\u0645\u0646\u0630 \u062f\u0642\u064a\u0642\u062a\u064a\u0646');
    expect(_textOf(tester, _directionKey), 'TextDirection.rtl');

    await tester.runAsync(
      () => container.read(localeProvider.notifier).setLocale(const Locale('en')),
    );
    await tester.pumpAndSettle();
    expect(_textOf(tester, _textKey), '2 minutes ago');
    expect(_textOf(tester, _directionKey), 'TextDirection.ltr');

    await tester.runAsync(
      () => container.read(localeProvider.notifier).setLocale(null),
    );
    await tester.pumpAndSettle();
    expect(_textOf(tester, _textKey), '2 minutes ago'); // the device is English
  });
}
