import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../l10n/app_localizations.dart';

/// Part P-113 (STEP 3A): the Appearance selector of the Profile & Settings
/// hub - System / Light / Dark.
///
/// A thin view over [themeModeProvider] (P-111). It keeps no state of its own:
/// the selected segment is always the provider's value, and a tap calls
/// `setThemeMode`, which switches the whole app at once and persists the
/// choice.
class AppearanceSelector extends ConsumerWidget {
  const AppearanceSelector({super.key});

  /// Key of the segmented control.
  static const Key selectorKey = Key('hub-appearance-selector');

  /// Key of the segment label for [mode] (handy for tests).
  static Key optionKey(ThemeMode mode) =>
      Key('hub-appearance-${themeModeToStored(mode)}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeMode current = ref.watch(themeModeProvider);

    Widget label(ThemeMode mode, String text) {
      return Text(
        text,
        key: optionKey(mode),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        key: selectorKey,
        showSelectedIcon: false,
        segments: <ButtonSegment<ThemeMode>>[
          ButtonSegment<ThemeMode>(
            value: ThemeMode.system,
            label: label(ThemeMode.system, l10n.hubAppearanceSystem),
          ),
          ButtonSegment<ThemeMode>(
            value: ThemeMode.light,
            label: label(ThemeMode.light, l10n.hubAppearanceLight),
          ),
          ButtonSegment<ThemeMode>(
            value: ThemeMode.dark,
            label: label(ThemeMode.dark, l10n.hubAppearanceDark),
          ),
        ],
        selected: <ThemeMode>{current},
        onSelectionChanged: (Set<ThemeMode> selection) {
          ref.read(themeModeProvider.notifier).setThemeMode(selection.first);
        },
      ),
    );
  }
}
