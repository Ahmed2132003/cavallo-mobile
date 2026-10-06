import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/l10n/l10n_context.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-112 STEP 6: `context.l10n`.
///
/// ASCII only on purpose: Arabic text is a \uXXXX escape.
void main() {
  testWidgets('without delegates it falls back to English (old widget tests)', (
    tester,
  ) async {
    String? retry;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            retry = context.l10n.commonRetry;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(retry, 'Retry');
  });

  testWidgets('with delegates it follows the active language', (tester) async {
    String? retry;
    Future<void> pump(Locale locale) => tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            retry = context.l10n.commonRetry;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await pump(const Locale('en'));
    await tester.pumpAndSettle();
    expect(retry, 'Retry');

    await pump(const Locale('ar'));
    await tester.pumpAndSettle();
    expect(retry, '\u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629');
  });
}
