import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// Part P-112: `context.l10n` - the short way for a screen to reach its texts.
///
/// In the running app the localization delegates are always installed
/// (`main.dart`), so this returns the texts of the active language. If a
/// widget is ever built WITHOUT the delegates (a bare `MaterialApp` in an old
/// widget test), it falls back to English instead of crashing, so those tests
/// keep working. Tests that check a language install the delegates explicitly.
extension AppL10nContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}
