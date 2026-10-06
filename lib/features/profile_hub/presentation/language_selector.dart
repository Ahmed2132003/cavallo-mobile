import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_reporting.dart';
import '../../../core/l10n/locale_provider.dart';
import '../data/language_preference_repository.dart';

/// Part P-113 (STEP 3A): the Language selector of the Profile & Settings
/// hub - Arabic / English.
///
/// A thin view over [localeProvider] (P-112). The selected segment is the
/// language the app is ACTUALLY using ([resolveActiveLocale]), so when the
/// setting is still "follow the device" the segment of the device language is
/// shown as selected.
///
/// Each language is written in its own language on purpose, in both
/// directions of the app: a person who cannot read the current language must
/// still be able to find their own. That is why these two labels are constants
/// and not ARB messages.
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  /// The Arabic name of the Arabic language, written as escapes so the source
  /// file is plain ASCII.
  static const String arabicName = '\u0627\u0644\u0639\u0631\u0628\u064a\u0629';

  static const String englishName = 'English';

  /// Key of the segmented control.
  static const Key selectorKey = Key('hub-language-selector');

  /// Key of the segment label for [languageCode] ("ar" or "en").
  static Key optionKey(String languageCode) =>
      Key('hub-language-$languageCode');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Locale? chosen = ref.watch(localeProvider);
    final List<Locale> device = ref.watch(deviceLocalesGetterProvider)();
    final String active = resolveActiveLocale(chosen, device).languageCode;

    Widget label(String languageCode, String text) {
      return Text(
        text,
        key: optionKey(languageCode),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        key: selectorKey,
        showSelectedIcon: false,
        segments: <ButtonSegment<String>>[
          ButtonSegment<String>(value: 'ar', label: label('ar', arabicName)),
          ButtonSegment<String>(value: 'en', label: label('en', englishName)),
        ],
        selected: <String>{active},
        onSelectionChanged: (Set<String> selection) {
          applyLanguageChoice(ref, selection.first);
        },
      ),
    );
  }
}

/// Applies a language chosen in Settings.
///
/// 1. Switches the app immediately and persists the choice locally
///    (`localeProvider`, P-112). This always happens first and is never undone.
/// 2. Then tells the backend through `PATCH /api/v1/auth/me/`, so server-side
///    texts (push notifications, localized names) follow the same language.
///    If that call fails the local choice is KEPT and the error is reported:
///    the language also reaches the server through the device-registration
///    locale, so a failed PATCH must never flip the screen back.
///
/// A language other than "ar" or "en" is ignored. Both providers are read
/// before the first await, so the call stays safe even if the widget that
/// started it is gone by the time the network answers.
Future<void> applyLanguageChoice(WidgetRef ref, String languageCode) async {
  if (!supportedLanguageCodes.contains(languageCode)) {
    return;
  }
  final LocaleNotifier localeNotifier = ref.read(localeProvider.notifier);
  final LanguagePreferenceRepository repository = ref.read(
    languagePreferenceRepositoryProvider,
  );

  await localeNotifier.setLocale(Locale(languageCode));
  try {
    await repository.savePreferredLanguage(languageCode);
  } catch (error, stack) {
    reportError(error, stack);
  }
}
