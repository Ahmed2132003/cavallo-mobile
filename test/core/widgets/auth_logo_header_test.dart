import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/auth_logo_header.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-117: AuthLogoHeader. The tests never depend on the real PNG: the
/// image may or may not load in the test environment, and the widget must
/// behave the same (errorBuilder / empty frame).
final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));

/// Serves the real asset manifest but fails every other asset (the logo
/// PNG), to prove a missing logo never throws.
class _FailingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') {
      return rootBundle.load(key);
    }
    return Future<ByteData>.error(FlutterError('missing asset $key'));
  }
}

Widget _host({
  Locale locale = const Locale('en'),
  bool dark = false,
  bool disableAnimations = false,
  double size = 104,
  AssetBundle? bundle,
}) {
  Widget home = Scaffold(body: Center(child: AuthLogoHeader(size: size)));
  if (bundle != null) {
    home = DefaultAssetBundle(bundle: bundle, child: home);
  }
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: dark ? AppTheme.dark : AppTheme.light,
    builder: (context, child) {
      if (!disableAnimations) return child!;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      );
    },
    home: home,
  );
}

Finder _inHeader(Finder matching) =>
    find.descendant(of: find.byType(AuthLogoHeader), matching: matching);

double _opacity(WidgetTester tester) =>
    tester
        .widget<FadeTransition>(_inHeader(find.byType(FadeTransition)).first)
        .opacity
        .value;

double _scale(WidgetTester tester) =>
    tester
        .widget<ScaleTransition>(_inHeader(find.byType(ScaleTransition)).first)
        .scale
        .value;

void main() {
  setUp(AuthLogoHeader.debugResetEntrance);

  group('AuthLogoHeader', () {
    testWidgets('renders an Image, the hero and a semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Hero && w.tag == kAuthLogoHeroTag),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(_en.appTitle), findsOneWidget);
      handle.dispose();
    });

    testWidgets('plays once and pumpAndSettle finishes in the final state', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacity(tester), greaterThan(0));
      expect(_opacity(tester), lessThan(1));

      await tester.pumpAndSettle();

      expect(_opacity(tester), 1.0);
      expect(_scale(tester), closeTo(1.0, 0.0001));
    });

    testWidgets('a later instance starts in the final state', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());

      await tester.pumpWidget(_host());

      expect(_opacity(tester), 1.0);
      expect(_scale(tester), closeTo(1.0, 0.0001));
    });

    testWidgets('disableAnimations: final state from the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(_host(disableAnimations: true));

      expect(_opacity(tester), 1.0);
      expect(_scale(tester), closeTo(1.0, 0.0001));
    });

    for (final bool dark in <bool>[false, true]) {
      testWidgets('${dark ? 'dark' : 'light'} theme builds without errors', (
        tester,
      ) async {
        await tester.pumpWidget(_host(dark: dark));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(Image), findsOneWidget);
      });
    }

    for (final (Locale locale, TextDirection direction)
        in <(Locale, TextDirection)>[
          (const Locale('en'), TextDirection.ltr),
          (const Locale('ar'), TextDirection.rtl),
        ]) {
      testWidgets('${locale.languageCode}: direction and semantics label', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_host(locale: locale));
        await tester.pumpAndSettle();

        expect(
          Directionality.of(tester.element(find.byType(AuthLogoHeader))),
          direction,
        );
        expect(
          find.bySemanticsLabel(lookupAppLocalizations(locale).appTitle),
          findsOneWidget,
        );
        handle.dispose();
      });
    }

    testWidgets('uses the requested size', (tester) async {
      await tester.pumpWidget(_host(size: 88));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(_inHeader(find.byType(AnimatedContainer))),
        const Size(88, 88),
      );
    });

    testWidgets('shrinks while the keyboard is open', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final Size size = tester.getSize(
        _inHeader(find.byType(AnimatedContainer)),
      );
      expect(size.width, lessThan(104));
      expect(size.width, greaterThan(0));
    });

    testWidgets('a logo that fails to load falls back without an exception', (
      tester,
    ) async {
      await tester.pumpWidget(_host(bundle: _FailingBundle()));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      expect(find.byKey(AuthLogoHeader.fallbackKey), findsOneWidget);
      expect(
        tester.getSize(find.byKey(AuthLogoHeader.fallbackKey)),
        const Size(104, 104),
      );
    });
  });
}
