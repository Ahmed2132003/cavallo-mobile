import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/cavallo_app_bar.dart';
import 'package:social_commerce_app/core/widgets/cavallo_logo.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// The Cavallo logo is on every screen: `CavalloAppBar` shows it, and no
/// screen may build a plain `AppBar` (which would have no logo).

Widget _host(Widget home, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    theme: AppTheme.light,
    home: home,
  );
}

void main() {
  testWidgets('shows the logo and keeps the title and the screen actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Scaffold(
          appBar: CavalloAppBar(
            title: const Text('Some page'),
            actions: <Widget>[
              IconButton(
                key: const Key('screen-action'),
                icon: const Icon(Icons.refresh),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(CavalloLogo.logoKey), findsOneWidget);
    expect(find.text('Cavallo'), findsOneWidget);
    expect(find.text('Some page'), findsOneWidget);
    expect(find.byKey(const Key('screen-action')), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('shows the logo with no actions and in Arabic', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Scaffold(appBar: CavalloAppBar(title: Text('Some page'))),
        locale: const Locale('ar'),
      ),
    );

    expect(find.byKey(CavalloLogo.logoKey), findsOneWidget);
    expect(find.text('Cavallo'), findsOneWidget);
  });

  test('has the same height as a plain AppBar, with and without a bottom', () {
    const CavalloAppBar plain = CavalloAppBar();
    expect(plain.preferredSize, AppBar().preferredSize);

    const PreferredSize bottom = PreferredSize(
      preferredSize: Size.fromHeight(48),
      child: SizedBox(),
    );
    const CavalloAppBar withBottom = CavalloAppBar(bottom: bottom);
    expect(withBottom.preferredSize, AppBar(bottom: bottom).preferredSize);
  });

  test('no screen builds a plain AppBar', () {
    // HomeTopBar draws the logo itself; CavalloAppBar wraps the real AppBar.
    const Set<String> allowed = <String>{
      'lib/core/shell/home_top_bar.dart',
      'lib/core/widgets/cavallo_app_bar.dart',
    };
    final RegExp plainAppBar = RegExp(r'(?<![A-Za-z0-9_])AppBar\(');
    final List<String> offenders = <String>[];

    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final String path = entity.path.replaceAll('\\', '/');
      if (allowed.contains(path)) continue;
      final List<String> lines = entity.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (plainAppBar.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use CavalloAppBar (core/widgets/cavallo_app_bar.dart) so the '
          'Cavallo logo is on every screen.',
    );
  });
}
