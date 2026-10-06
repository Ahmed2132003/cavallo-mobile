<#
.SYNOPSIS
  P-113 / STEP 3 / PART A - Profile & Settings hub (Appearance, Language,
  Business tools, Moderation count, Featured status, Log out confirmation).

.DESCRIPTION
  Creates the new files, replaces the STEP 1 placeholder of
  profile_hub_screen.dart, and appends the new keys to the end of both ARB
  files (nothing else in the ARB files is touched). Then runs
  `flutter gen-l10n` so the generated AppLocalizations files pick up the keys.

  - Run it from anywhere; pass the Flutter project folder with -MobileRoot.
  - Safe to run twice: if the ARB keys are already there they are not added
    again, and files that already come from this step are simply rewritten.
  - Every file it overwrites is first copied to a backup folder NEXT TO the
    project folder (never inside the repository, so it cannot be committed).
  - It never touches app_router.dart, the navigation manifest, the shell, or
    any other file that is not listed in the summary at the end.

.PARAMETER MobileRoot
  The Flutter project folder (the one that contains pubspec.yaml).

.PARAMETER SkipGenL10n
  Do not run `flutter gen-l10n` at the end (run it yourself afterwards).

.PARAMETER Force
  Overwrite files even when they do not look like the STEP 1 placeholder or
  an earlier run of this step.
#>
[CmdletBinding()]
param(
    [string]$MobileRoot = 'D:\Cavallo\social_commerce_app',
    [switch]$SkipGenL10n,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-Text([string]$path) {
    return [System.IO.File]::ReadAllText($path, $utf8NoBom)
}

function Save-Text([string]$path, [string]$text) {
    $t = $text -replace "`r`n", "`n"
    if (-not $t.EndsWith("`n")) { $t += "`n" }
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($path, $t, $utf8NoBom)
}

# ---------------------------------------------------------------
# 0. Preflight: make sure this is the right project in the right state
# ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $MobileRoot)) {
    throw "MobileRoot not found: $MobileRoot  (pass -MobileRoot <flutter project folder>)"
}
$root = (Resolve-Path -LiteralPath $MobileRoot).Path

$pubspecPath = Join-Path $root 'pubspec.yaml'
if (-not (Test-Path -LiteralPath $pubspecPath)) {
    throw "pubspec.yaml not found in $root"
}
if (-not ((Read-Text $pubspecPath) -match '(?m)^name:\s*social_commerce_app\s*$')) {
    throw "$pubspecPath is not the social_commerce_app project."
}

$required = @(
    'lib\routing\navigation_manifest.dart',
    'lib\routing\app_router.dart',
    'lib\routing\route_names.dart',
    'lib\core\shell\app_shell.dart',
    'lib\core\shell\app_bottom_bar.dart',
    'lib\core\theme\theme_mode_provider.dart',
    'lib\core\l10n\locale_provider.dart',
    'lib\core\l10n\formatters.dart',
    'lib\core\network\dio_client.dart',
    'lib\core\widgets\app_avatar.dart',
    'lib\core\widgets\featured_badge.dart',
    'lib\features\auth\presentation\session_provider.dart',
    'lib\features\business_profile\presentation\business_profile_provider.dart',
    'lib\features\moderation\presentation\moderation_provider.dart',
    'lib\features\moderation\domain\queue_item_entity.dart',
    'lib\features\profile_hub\presentation\profile_hub_screen.dart',
    'lib\l10n\app_en.arb',
    'lib\l10n\app_ar.arb'
)
$missing = @()
foreach ($rel in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $rel))) { $missing += $rel }
}
if ($missing.Count -gt 0) {
    throw ("These files are missing, so STEP 1 / STEP 2 of P-113 are not in this folder:`n  " + ($missing -join "`n  "))
}

$hubPath = Join-Path $root 'lib\features\profile_hub\presentation\profile_hub_screen.dart'
$hubCurrent = Read-Text $hubPath
$hubIsPlaceholder = $hubCurrent.Contains('TEMPORARY (P-113 STEP 1 fix)')
$hubIsStep3A = $hubCurrent.Contains('Part P-113 (STEP 3A)')
if ((-not $hubIsPlaceholder) -and (-not $hubIsStep3A) -and (-not $Force)) {
    throw "profile_hub_screen.dart is neither the STEP 1 placeholder nor a STEP 3A file. Nothing was changed. Use -Force to overwrite it anyway."
}

$enPath = Join-Path $root 'lib\l10n\app_en.arb'
$arPath = Join-Path $root 'lib\l10n\app_ar.arb'
$enText = Read-Text $enPath
$arText = Read-Text $arPath
$enHas = $enText.Contains('"hubTitle"')
$arHas = $arText.Contains('"hubTitle"')
if ($enHas -ne $arHas) {
    throw "app_en.arb and app_ar.arb disagree about the hub keys (hubTitle is in only one of them). Nothing was changed."
}
$arbAlreadyDone = $enHas

# ---------------------------------------------------------------
# Embedded content
# ---------------------------------------------------------------
$arbEn = @'
  "hubTitle": "Profile & Settings",
  "@hubTitle": {
    "description": "App bar title of the Profile and Settings hub (tab 5)."
  },
  "hubAccountTypeCustomer": "Customer",
  "@hubAccountTypeCustomer": {
    "description": "Account-type chip in the hub header: a Customer account."
  },
  "hubAccountTypeBusiness": "Business",
  "@hubAccountTypeBusiness": {
    "description": "Account-type chip in the hub header: a Business (Trader or Factory) account."
  },
  "hubAccountTypeStaff": "Staff",
  "@hubAccountTypeStaff": {
    "description": "Account-type chip in the hub header: a Staff or Moderator account."
  },
  "hubSaved": "Saved",
  "@hubSaved": {
    "description": "Hub row: opens the Saved screen."
  },
  "hubNotificationPreferences": "Notification preferences",
  "@hubNotificationPreferences": {
    "description": "Hub row: opens the notification preferences screen."
  },
  "hubSettingsGroup": "Settings",
  "@hubSettingsGroup": {
    "description": "Caption of the hub group that holds Appearance and Language."
  },
  "hubAppearance": "Appearance",
  "@hubAppearance": {
    "description": "Hub row title: the light or dark theme setting."
  },
  "hubAppearanceSystem": "System",
  "@hubAppearanceSystem": {
    "description": "Appearance option: follow the device theme."
  },
  "hubAppearanceLight": "Light",
  "@hubAppearanceLight": {
    "description": "Appearance option: always light."
  },
  "hubAppearanceDark": "Dark",
  "@hubAppearanceDark": {
    "description": "Appearance option: always dark."
  },
  "hubLanguage": "Language",
  "@hubLanguage": {
    "description": "Hub row title: the app language setting."
  },
  "hubBusinessTools": "Business tools",
  "@hubBusinessTools": {
    "description": "Caption of the hub group shown to Business accounts only."
  },
  "hubBusinessConsole": "Business console",
  "@hubBusinessConsole": {
    "description": "Hub row (Business): opens the business console."
  },
  "hubEditBusinessProfile": "Edit business profile",
  "@hubEditBusinessProfile": {
    "description": "Hub row (Business): opens the business profile editor."
  },
  "hubProducts": "Products",
  "@hubProducts": {
    "description": "Hub row (Business): the products list of the business console."
  },
  "hubContent": "Content",
  "@hubContent": {
    "description": "Hub row (Business): the posts and reels list of the business console."
  },
  "hubStories": "Stories",
  "@hubStories": {
    "description": "Hub row (Business): the stories list of the business console."
  },
  "hubAnalytics": "Analytics",
  "@hubAnalytics": {
    "description": "Hub row (Business): the analytics screen of the business console."
  },
  "hubFeaturedStatus": "Featured status",
  "@hubFeaturedStatus": {
    "description": "Hub row (Business): shows whether the business is currently Featured. Display only."
  },
  "hubFeaturedNo": "Not featured",
  "@hubFeaturedNo": {
    "description": "Value of the Featured status row when the business is not Featured."
  },
  "hubModeration": "Moderation",
  "@hubModeration": {
    "description": "Caption of the hub group shown to Staff accounts only."
  },
  "hubModerationQueue": "Moderation queue",
  "@hubModerationQueue": {
    "description": "Hub row (Staff): opens the moderation queue, with the pending count."
  },
  "hubAbout": "About",
  "@hubAbout": {
    "description": "Hub row: opens the About dialog."
  },
  "hubLogOut": "Log out",
  "@hubLogOut": {
    "description": "Hub row and confirm button: sign out of the account."
  },
  "hubLogOutConfirmTitle": "Log out?",
  "@hubLogOutConfirmTitle": {
    "description": "Title of the dialog that asks for confirmation before signing out."
  },
  "hubLogOutConfirmMessage": "You will need to sign in again to use your account.",
  "@hubLogOutConfirmMessage": {
    "description": "Body of the sign-out confirmation dialog."
  },
  "hubCancel": "Cancel",
  "@hubCancel": {
    "description": "Cancel button of the sign-out confirmation dialog."
  }
'@
$arbAr = @'
  "hubTitle": "\u0627\u0644\u062d\u0633\u0627\u0628 \u0648\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a",
  "hubAccountTypeCustomer": "\u0639\u0645\u064a\u0644",
  "hubAccountTypeBusiness": "\u0646\u0634\u0627\u0637 \u062a\u062c\u0627\u0631\u064a",
  "hubAccountTypeStaff": "\u0641\u0631\u064a\u0642 \u0627\u0644\u0639\u0645\u0644",
  "hubSaved": "\u0627\u0644\u0645\u062d\u0641\u0648\u0638\u0627\u062a",
  "hubNotificationPreferences": "\u062a\u0641\u0636\u064a\u0644\u0627\u062a \u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a",
  "hubSettingsGroup": "\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a",
  "hubAppearance": "\u0627\u0644\u0645\u0638\u0647\u0631",
  "hubAppearanceSystem": "\u0627\u0644\u0646\u0638\u0627\u0645",
  "hubAppearanceLight": "\u0641\u0627\u062a\u062d",
  "hubAppearanceDark": "\u062f\u0627\u0643\u0646",
  "hubLanguage": "\u0627\u0644\u0644\u063a\u0629",
  "hubBusinessTools": "\u0623\u062f\u0648\u0627\u062a \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a",
  "hubBusinessConsole": "\u0644\u0648\u062d\u0629 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a",
  "hubEditBusinessProfile": "\u062a\u0639\u062f\u064a\u0644 \u0645\u0644\u0641 \u0627\u0644\u0646\u0634\u0627\u0637",
  "hubProducts": "\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a",
  "hubContent": "\u0627\u0644\u0645\u062d\u062a\u0648\u0649",
  "hubStories": "\u0627\u0644\u0642\u0635\u0635",
  "hubAnalytics": "\u0627\u0644\u062a\u062d\u0644\u064a\u0644\u0627\u062a",
  "hubFeaturedStatus": "\u062d\u0627\u0644\u0629 \u0627\u0644\u062a\u0645\u064a\u064a\u0632",
  "hubFeaturedNo": "\u063a\u064a\u0631 \u0645\u0645\u064a\u0651\u0632",
  "hubModeration": "\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629",
  "hubModerationQueue": "\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629",
  "hubAbout": "\u0639\u0646 \u0627\u0644\u062a\u0637\u0628\u064a\u0642",
  "hubLogOut": "\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c",
  "hubLogOutConfirmTitle": "\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c\u061f",
  "hubLogOutConfirmMessage": "\u0633\u062a\u062d\u062a\u0627\u062c \u0625\u0644\u0649 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649 \u0644\u0627\u0633\u062a\u062e\u062f\u0627\u0645 \u062d\u0633\u0627\u0628\u0643.",
  "hubCancel": "\u0625\u0644\u063a\u0627\u0621"
'@
$sources = New-Object System.Collections.Generic.List[object]
$src0 = @'
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// Part P-113 (STEP 3A): tells the backend which language the signed-in user
/// chose in Settings.
///
/// Why a separate small repository (and not a new method on
/// `AuthRepository`): `AuthRepository` is implemented by several test fakes,
/// so adding an abstract method there would break them for no benefit. This
/// one call has nothing to do with login or tokens.
///
/// Backend contract (P-112, `accounts.views.MeView.patch`):
/// `PATCH /api/v1/auth/me/` with `{"preferred_language": "ar" | "en"}`. Any
/// other field in the body is ignored by the server. The response has the
/// same shape as `GET /api/v1/auth/me/`; nothing in it is needed here.
///
/// Failures surface as a `DioException` whose `.error` is an `ApiFailure`
/// (Part P-004), like every other repository in the app.
abstract class LanguagePreferenceRepository {
  Future<void> savePreferredLanguage(String languageCode);
}

class LanguagePreferenceRepositoryImpl implements LanguagePreferenceRepository {
  LanguagePreferenceRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String _mePath = '/api/v1/auth/me/';

  @override
  Future<void> savePreferredLanguage(String languageCode) async {
    await _dio.patch<Map<String, dynamic>>(
      _mePath,
      data: <String, String>{'preferred_language': languageCode},
    );
  }
}

final Provider<LanguagePreferenceRepository>
languagePreferenceRepositoryProvider = Provider<LanguagePreferenceRepository>((
  Ref ref,
) {
  return LanguagePreferenceRepositoryImpl(dio: ref.watch(dioClientProvider));
});
'@
$sources.Add(@{ Path = 'lib\features\profile_hub\data\language_preference_repository.dart'; Content = $src0; Replaces = $false })
$src1 = @'
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
'@
$sources.Add(@{ Path = 'lib\features\profile_hub\presentation\appearance_selector.dart'; Content = $src1; Replaces = $false })
$src2 = @'
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
'@
$sources.Add(@{ Path = 'lib\features\profile_hub\presentation\language_selector.dart'; Content = $src2; Replaces = $false })
$src3 = @'
import 'package:flutter/material.dart';

import '../../../core/l10n/rtl_helpers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/navigation_manifest.dart';

/// Part P-113 (STEP 3A): the building blocks of the Profile & Settings hub.
///
/// Presentation only: no routing, no providers. The hub screen decides which
/// rows exist and what a tap does.

/// The ids of the destinations the navigation manifest shows as a hub row for
/// [audience] (entries of kind `NavEntryKind.profileHubRow`).
///
/// The manifest is the single source of truth for navigation visibility, so
/// the hub renders a row only when its id is in this set, and a test fails if
/// the manifest lists a hub row the hub does not draw.
Set<String> hubRowIdsFor(NavAudience audience) {
  final Set<String> ids = <String>{};
  for (final NavDestination destination in kNavigationManifest) {
    final List<NavEntry> entries =
        destination.entries[audience] ?? const <NavEntry>[];
    for (final NavEntry entry in entries) {
      if (entry.kind == NavEntryKind.profileHubRow) {
        ids.add(destination.id);
      }
    }
  }
  return ids;
}

/// A titled block of rows on a surface card, with hairline dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, this.title, super.key});

  /// Small caption above the card. Null draws no caption.
  final String? title;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: colors.outline));
      }
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 8),
            child: Text(
              title!,
              style: text.titleSmall?.copyWith(color: colors.textSecondary),
            ),
          )
        else
          const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.symmetric(
              horizontal: BorderSide(color: colors.outline),
            ),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

/// One tappable row: icon, title, optional subtitle and trailing widget.
///
/// With an [onTap] and no [trailing], a chevron that points the right way in
/// both directions is drawn. [destructive] paints the row in the danger colour
/// (Log out).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Color tint = destructive ? colors.dangerText : colors.textPrimary;

    Widget? end = trailing;
    if (end == null && onTap != null) {
      end = DirectionalIcon(Icons.chevron_right, color: colors.textSecondary);
    }

    return ListTile(
      leading: Icon(icon, color: destructive ? colors.dangerText : null),
      title: Text(title, style: TextStyle(color: tint)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: end,
      onTap: onTap,
    );
  }
}

/// A row whose control lives under the title (Appearance, Language): icon and
/// title on the first line, the [child] selector below, full width.
class SettingsSelectorRow extends StatelessWidget {
  const SettingsSelectorRow({
    required this.icon,
    required this.title,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: text.bodyLarge)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
'@
$sources.Add(@{ Path = 'lib\features\profile_hub\presentation\settings_rows.dart'; Content = $src3; Replaces = $false })
$src4 = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_reporting.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/l10n/rtl_helpers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/featured_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/navigation_manifest.dart';
import '../../../routing/route_names.dart';
import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';
import '../../business_profile/domain/business_profile_entity.dart';
import '../../business_profile/presentation/business_profile_provider.dart';
import '../../moderation/domain/queue_item_entity.dart';
import '../../moderation/presentation/moderation_provider.dart';
import 'appearance_selector.dart';
import 'language_selector.dart';
import 'settings_rows.dart';

/// Part P-113 (STEP 3A): the BUSINESS profile of the signed-in Business
/// account, or null (not a Business account, still loading, or no profile).
///
/// A thin derived provider so the hub does not care how the profile is
/// fetched, and so tests can replace it with a plain value.
final hubBusinessProfileProvider = Provider.autoDispose<BusinessProfile?>((
  Ref ref,
) {
  final AsyncValue<BusinessProfile?> profile = ref.watch(
    businessProfileProvider,
  );
  return switch (profile) {
    AsyncData(:final value) => value,
    _ => null,
  };
});

/// Part P-113 (STEP 3A): how many items wait in the moderation queue.
///
/// Derived from the existing `moderationQueueProvider` (which already returns
/// only pending items). No new request and no polling is added: the count is
/// whatever that provider holds, and it is 0 while loading or on error.
final hubModerationPendingCountProvider = Provider.autoDispose<int>((Ref ref) {
  final AsyncValue<List<QueueItem>> queue = ref.watch(
    moderationQueueProvider,
  );
  return switch (queue) {
    AsyncData(:final value) => value.length,
    _ => 0,
  };
});

/// Part P-113 (STEP 3A): the Profile & Settings hub, tab 5 of the app shell.
///
/// Layout: a header (avatar, name or email, account-type chip), then grouped
/// rows in this order: Saved, Notification preferences, Appearance, Language,
/// Business tools (Business accounts), Moderation (Staff accounts, with the
/// pending count), About, Log out.
///
/// ## The manifest decides which rows exist
///
/// A row is drawn only when `hubRowIdsFor(audience)` (the
/// `NavEntryKind.profileHubRow` entries of the navigation manifest) contains
/// its id. The hub never shows a row the manifest does not list for that
/// account type, and `profile_hub_screen_test.dart` fails if the manifest
/// lists a hub row this screen does not draw. Two rows are NOT manifest
/// destinations and are drawn without a manifest entry: "Featured status"
/// (display only, Business accounts) and "About" (a dialog, not a route).
///
/// ## What it does NOT do
///
/// * It does not decide who may open a route. Account-type gating stays in the
///   router `redirect`; hiding a row is only a convenience on top of it.
/// * It adds no polling and no new request. It reads the existing session,
///   business profile and moderation queue providers.
/// * Saved and Moderation are tabs of the shell, so their rows switch tab
///   (`goNamed`). Every other row opens its screen above the shell
///   (`pushNamed`), so back returns to the hub.
class ProfileHubScreen extends ConsumerWidget {
  const ProfileHubScreen({super.key});

  /// Key of the row of destination [id] (a manifest id).
  static Key rowKey(String id) => Key('hub-row-$id');

  /// Id and key of the "About" row (not a manifest destination).
  static const String aboutId = 'about';

  static const Key headerKey = Key('hub-header');
  static const Key accountTypeChipKey = Key('hub-account-type');
  static const Key featuredStatusKey = Key('hub-featured-status');
  static const Key moderationBadgeKey = Key('hub-moderation-badge');
  static const Key logoutDialogKey = Key('hub-logout-dialog');
  static const Key logoutCancelKey = Key('hub-logout-cancel');
  static const Key logoutConfirmKey = Key('hub-logout-confirm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.appColors;

    final AsyncValue<User?> session = ref.watch(sessionProvider);
    final User? user = switch (session) {
      AsyncData(:final value) => value,
      _ => null,
    };

    if (user == null) {
      // A login or logout is in flight; the router redirect is about to move
      // the user. Draw an empty page instead of guessing a layout.
      return Scaffold(
        appBar: AppBar(title: Text(l10n.hubTitle)),
        body: const SizedBox.shrink(),
      );
    }

    final NavAudience audience = navAudienceForUser(user);
    final Set<String> ids = hubRowIdsFor(audience);
    final BusinessProfile? business =
        audience == NavAudience.business
            ? ref.watch(hubBusinessProfileProvider)
            : null;
    final int pendingCount =
        audience == NavAudience.staff
            ? ref.watch(hubModerationPendingCountProvider)
            : 0;

    Widget navRow(
      String id,
      IconData icon,
      String title,
      VoidCallback onTap, {
      Widget? trailing,
    }) {
      return SettingsRow(
        key: rowKey(id),
        icon: icon,
        title: title,
        trailing: trailing,
        onTap: onTap,
      );
    }

    final List<Widget> libraryRows = <Widget>[
      if (ids.contains(RouteNames.saved))
        navRow(
          RouteNames.saved,
          Icons.bookmark_border,
          l10n.hubSaved,
          () => context.goNamed(RouteNames.saved),
        ),
      if (ids.contains(RouteNames.notificationPreferences))
        navRow(
          RouteNames.notificationPreferences,
          Icons.notifications_none,
          l10n.hubNotificationPreferences,
          () => context.pushNamed(RouteNames.notificationPreferences),
        ),
    ];

    final List<Widget> settingsRows = <Widget>[
      if (ids.contains(kNavAppearanceId))
        SettingsSelectorRow(
          key: rowKey(kNavAppearanceId),
          icon: Icons.brightness_6_outlined,
          title: l10n.hubAppearance,
          child: const AppearanceSelector(),
        ),
      if (ids.contains(kNavLanguageId))
        SettingsSelectorRow(
          key: rowKey(kNavLanguageId),
          icon: Icons.language,
          title: l10n.hubLanguage,
          child: const LanguageSelector(),
        ),
    ];

    final List<Widget> businessRows = <Widget>[
      if (ids.contains(RouteNames.businessConsole))
        navRow(
          RouteNames.businessConsole,
          Icons.dashboard_outlined,
          l10n.hubBusinessConsole,
          () => context.pushNamed(RouteNames.businessConsole),
        ),
      if (ids.contains(RouteNames.businessProfileEdit))
        navRow(
          RouteNames.businessProfileEdit,
          Icons.storefront_outlined,
          l10n.hubEditBusinessProfile,
          () => context.pushNamed(RouteNames.businessProfileEdit),
        ),
      if (ids.contains(RouteNames.productList))
        navRow(
          RouteNames.productList,
          Icons.inventory_2_outlined,
          l10n.hubProducts,
          () => context.pushNamed(RouteNames.productList),
        ),
      if (ids.contains(RouteNames.contentList))
        navRow(
          RouteNames.contentList,
          Icons.photo_library_outlined,
          l10n.hubContent,
          () => context.pushNamed(RouteNames.contentList),
        ),
      if (ids.contains(RouteNames.storyList))
        navRow(
          RouteNames.storyList,
          Icons.auto_stories_outlined,
          l10n.hubStories,
          () => context.pushNamed(RouteNames.storyList),
        ),
      if (ids.contains(RouteNames.businessAnalytics))
        navRow(
          RouteNames.businessAnalytics,
          Icons.insights_outlined,
          l10n.hubAnalytics,
          () => context.pushNamed(RouteNames.businessAnalytics),
        ),
      // Display only (ADR-006): Featured is bought on the Web Dashboard, never
      // inside this app, so this row has no tap action.
      if (audience == NavAudience.business && business != null)
        SettingsRow(
          key: featuredStatusKey,
          icon: Icons.star_outline,
          title: l10n.hubFeaturedStatus,
          trailing:
              business.isFeatured
                  ? const FeaturedBadge()
                  : Text(
                    l10n.hubFeaturedNo,
                    style: TextStyle(color: colors.textSecondary),
                  ),
        ),
    ];

    final List<Widget> moderationRows = <Widget>[
      if (ids.contains(RouteNames.moderation))
        navRow(
          RouteNames.moderation,
          Icons.shield_outlined,
          l10n.hubModerationQueue,
          () => context.goNamed(RouteNames.moderation),
          trailing: _ModerationTrailing(count: pendingCount),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.hubTitle)),
      body: ListView(
        children: <Widget>[
          _HubHeader(user: user, audience: audience, business: business),
          if (libraryRows.isNotEmpty) SettingsGroup(children: libraryRows),
          if (settingsRows.isNotEmpty)
            SettingsGroup(title: l10n.hubSettingsGroup, children: settingsRows),
          if (businessRows.isNotEmpty)
            SettingsGroup(
              title: l10n.hubBusinessTools,
              children: businessRows,
            ),
          if (moderationRows.isNotEmpty)
            SettingsGroup(title: l10n.hubModeration, children: moderationRows),
          SettingsGroup(
            children: <Widget>[
              SettingsRow(
                key: rowKey(aboutId),
                icon: Icons.info_outline,
                title: l10n.hubAbout,
                onTap:
                    () => showAboutDialog(
                      context: context,
                      applicationName: l10n.appTitle,
                    ),
              ),
            ],
          ),
          if (ids.contains(kNavLogoutId))
            SettingsGroup(
              children: <Widget>[
                SettingsRow(
                  key: rowKey(kNavLogoutId),
                  icon: Icons.logout,
                  title: l10n.hubLogOut,
                  destructive: true,
                  onTap: () => _confirmLogout(context, ref),
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Asks for confirmation, then signs out through the session provider. The
  /// router redirect moves the user to the login screen as soon as the session
  /// becomes empty. A failing server call is reported, never shown: the local
  /// session is cleared either way (see `SessionNotifier.logout`).
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext dialogContext) => AlertDialog(
            key: logoutDialogKey,
            title: Text(l10n.hubLogOutConfirmTitle),
            content: Text(l10n.hubLogOutConfirmMessage),
            actions: <Widget>[
              TextButton(
                key: logoutCancelKey,
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.hubCancel),
              ),
              TextButton(
                key: logoutConfirmKey,
                style: TextButton.styleFrom(
                  foregroundColor: dialogContext.appColors.dangerText,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.hubLogOut),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(sessionProvider.notifier).logout();
    } catch (error, stack) {
      reportError(error, stack);
    }
  }
}

/// Header of the hub: avatar, name (the business name for a Business account,
/// otherwise the email), the email under a business name, and the account-type
/// chip.
class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.user,
    required this.audience,
    required this.business,
  });

  final User user;
  final NavAudience audience;
  final BusinessProfile? business;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    final String? businessName = business?.businessName;
    final String title =
        (businessName != null && businessName.trim().isNotEmpty)
            ? businessName
            : user.email;
    final bool showEmailLine = title != user.email;

    final String typeLabel = switch (audience) {
      NavAudience.customer => l10n.hubAccountTypeCustomer,
      NavAudience.business => l10n.hubAccountTypeBusiness,
      NavAudience.staff => l10n.hubAccountTypeStaff,
    };

    return Padding(
      key: ProfileHubScreen.headerKey,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Row(
        children: <Widget>[
          AppAvatar(name: title, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showEmailLine)
                  Text(
                    user.email,
                    style: text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Container(
                  key: ProfileHubScreen.accountTypeChipKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(typeLabel, style: text.labelMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Trailing part of the Moderation row: the pending count in a brand-blue
/// badge (only when above zero), then the direction-aware chevron.
class _ModerationTrailing extends StatelessWidget {
  const _ModerationTrailing({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final AppFormatters formatters = AppFormatters(context.l10n);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (count > 0) ...<Widget>[
          Badge(
            key: ProfileHubScreen.moderationBadgeKey,
            backgroundColor: colors.brand,
            textColor: colors.onBrand,
            label: Text(formatters.compactCount(count)),
          ),
          const SizedBox(width: 8),
        ],
        DirectionalIcon(Icons.chevron_right, color: colors.textSecondary),
      ],
    );
  }
}
'@
$sources.Add(@{ Path = 'lib\features\profile_hub\presentation\profile_hub_screen.dart'; Content = $src4; Replaces = $true })
$src5 = @'
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/profile_hub/data/language_preference_repository.dart';

/// Part P-113 (STEP 3A): the one call the Language selector makes to the
/// backend: `PATCH /api/v1/auth/me/` with `{"preferred_language": code}`.

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter({this.statusCode = 200});

  final int statusCode;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_CaptureAdapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  test('sends a PATCH to /api/v1/auth/me/ with only preferred_language', () async {
    final _CaptureAdapter adapter = _CaptureAdapter();
    final LanguagePreferenceRepositoryImpl repository =
        LanguagePreferenceRepositoryImpl(dio: _dio(adapter));

    await repository.savePreferredLanguage('en');

    expect(adapter.last, isNotNull);
    expect(adapter.last!.method, 'PATCH');
    expect(adapter.last!.path, '/api/v1/auth/me/');
    expect(adapter.last!.data, <String, String>{'preferred_language': 'en'});
  });

  test('sends Arabic as "ar"', () async {
    final _CaptureAdapter adapter = _CaptureAdapter();
    final LanguagePreferenceRepositoryImpl repository =
        LanguagePreferenceRepositoryImpl(dio: _dio(adapter));

    await repository.savePreferredLanguage('ar');

    expect(adapter.last!.data, <String, String>{'preferred_language': 'ar'});
  });

  test('a rejected request throws a DioException to the caller', () async {
    final LanguagePreferenceRepositoryImpl repository =
        LanguagePreferenceRepositoryImpl(
          dio: _dio(_CaptureAdapter(statusCode: 400)),
        );

    expect(
      repository.savePreferredLanguage('en'),
      throwsA(isA<DioException>()),
    );
  });
}
'@
$sources.Add(@{ Path = 'test\features\profile_hub\data\language_preference_repository_test.dart'; Content = $src5; Replaces = $false })
$src6 = @'
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
'@
$sources.Add(@{ Path = 'test\features\profile_hub\presentation\hub_selectors_test.dart'; Content = $src6; Replaces = $false })
$src7 = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/profile_hub_screen.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/settings_rows.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/navigation_manifest.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-113 (STEP 3A): widget tests of the Profile & Settings hub.
///
/// * the rows drawn for each account type are EXACTLY the rows the navigation
///   manifest lists as hub rows (plus the "About" row, which is not a
///   destination), so the hub and the manifest cannot drift apart;
/// * header, Business tools, Moderation badge and Featured status;
/// * every row opens the right route;
/// * Log out asks first and signs out only after the confirmation;
/// * the screen works in Arabic and mirrors.

const String _arTitle =
    '\u0627\u0644\u062d\u0633\u0627\u0628 '
    '\u0648\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a';
const String _arLogOut =
    '\u062a\u0633\u062c\u064a\u0644 '
    '\u0627\u0644\u062e\u0631\u0648\u062c';

class _FakeSession extends SessionNotifier {
  _FakeSession(this._user);

  final User? _user;
  int logoutCalls = 0;

  @override
  Future<User?> build() async => _user;

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncValue<User?>.data(null);
  }
}

const User _customer = User(
  id: 1,
  email: 'customer@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

const User _business = User(
  id: 2,
  email: 'business@example.com',
  accountType: AccountType.business,
  isModerator: false,
  isStaff: false,
);

const User _staff = User(
  id: 3,
  email: 'staff@example.com',
  accountType: AccountType.customer,
  isModerator: true,
  isStaff: false,
);

BusinessProfile _profile({bool featured = false}) {
  return BusinessProfile(
    id: 1,
    businessName: 'Roots Atelier',
    businessType: BusinessType.trader,
    country: 'EG',
    city: 'Cairo',
    isVerified: false,
    isFeatured: featured,
  );
}

/// Every destination a hub row can open, as a stub screen that prints
/// `stub:<route name>`, so a test can see where a tap landed.
GoRouter _stubRouter() {
  GoRoute stub(String name, String path) {
    return GoRoute(
      path: path,
      name: name,
      builder:
          (BuildContext context, GoRouterState state) =>
              Scaffold(body: Center(child: Text('stub:$name'))),
    );
  }

  return GoRouter(
    initialLocation: RouteNames.profilePath,
    routes: <RouteBase>[
      GoRoute(
        path: RouteNames.profilePath,
        name: RouteNames.profile,
        builder:
            (BuildContext context, GoRouterState state) =>
                const ProfileHubScreen(),
      ),
      stub(RouteNames.saved, RouteNames.savedPath),
      stub(RouteNames.moderation, RouteNames.moderationPath),
      stub(
        RouteNames.notificationPreferences,
        RouteNames.notificationPreferencesPath,
      ),
      stub(RouteNames.businessProfileEdit, RouteNames.businessProfileEditPath),
      stub(RouteNames.businessConsole, RouteNames.businessConsolePath),
      stub(RouteNames.productList, RouteNames.productListPath),
      stub(RouteNames.contentList, RouteNames.contentListPath),
      stub(RouteNames.storyList, RouteNames.storyListPath),
      stub(RouteNames.businessAnalytics, RouteNames.businessAnalyticsPath),
    ],
  );
}

Future<_FakeSession> _pump(
  WidgetTester tester, {
  required User user,
  BusinessProfile? business,
  int pending = 0,
  Locale locale = const Locale('en'),
}) async {
  // Tall surface so every row of the ListView is built.
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final _FakeSession session = _FakeSession(user);
  final GoRouter router = _stubRouter();
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => session),
        hubBusinessProfileProvider.overrideWithValue(business),
        hubModerationPendingCountProvider.overrideWithValue(pending),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

Finder _row(String id) => find.byKey(ProfileHubScreen.rowKey(id));

/// The ids of every hub row currently drawn.
Set<String> _drawnRowIds(WidgetTester tester) {
  const String prefix = 'hub-row-';
  final Finder rows = find.byWidgetPredicate((Widget widget) {
    final Key? key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
  });
  return tester
      .widgetList(rows)
      .map((Widget w) => (w.key! as ValueKey<String>).value.substring(prefix.length))
      .toSet();
}

void main() {
  group('P-113 STEP 3A: hub rows follow the navigation manifest', () {
    final Map<NavAudience, User> users = <NavAudience, User>{
      NavAudience.customer: _customer,
      NavAudience.business: _business,
      NavAudience.staff: _staff,
    };

    for (final MapEntry<NavAudience, User> entry in users.entries) {
      testWidgets(
        '${entry.key.name}: draws every manifest hub row and nothing else',
        (WidgetTester tester) async {
          await _pump(
            tester,
            user: entry.value,
            business:
                entry.key == NavAudience.business ? _profile() : null,
          );

          final Set<String> expected = <String>{
            ...hubRowIdsFor(entry.key),
            ProfileHubScreen.aboutId,
          };
          expect(_drawnRowIds(tester), expected);
        },
      );
    }

    test('the manifest lists at least Saved, notification preferences, '
        'appearance, language and log out for everyone', () {
      for (final NavAudience audience in NavAudience.values) {
        expect(
          hubRowIdsFor(audience),
          containsAll(<String>[
            RouteNames.saved,
            RouteNames.notificationPreferences,
            kNavAppearanceId,
            kNavLanguageId,
            kNavLogoutId,
          ]),
          reason: audience.name,
        );
      }
    });
  });

  group('P-113 STEP 3A: header and groups', () {
    testWidgets('Customer: email, Customer chip, no Business or Moderation', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _customer);

      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(find.text('customer@example.com'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ProfileHubScreen.accountTypeChipKey),
          matching: find.text('Customer'),
        ),
        findsOneWidget,
      );
      expect(find.text('Business tools'), findsNothing);
      expect(find.text('Moderation'), findsNothing);
      expect(find.byKey(ProfileHubScreen.featuredStatusKey), findsNothing);
    });

    testWidgets('Business: business name, email line, Business chip, tools', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _business, business: _profile());

      expect(find.text('Roots Atelier'), findsOneWidget);
      expect(find.text('business@example.com'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ProfileHubScreen.accountTypeChipKey),
          matching: find.text('Business'),
        ),
        findsOneWidget,
      );
      expect(find.text('Business tools'), findsOneWidget);
      expect(find.text('Edit business profile'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Stories'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Moderation'), findsNothing);
    });

    testWidgets('Business without a loaded profile falls back to the email', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _business);

      expect(find.text('business@example.com'), findsOneWidget);
      expect(find.byKey(ProfileHubScreen.featuredStatusKey), findsNothing);
    });

    testWidgets('Featured status: "Not featured" when the business is not', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _business, business: _profile());

      expect(find.byKey(ProfileHubScreen.featuredStatusKey), findsOneWidget);
      expect(find.text('Not featured'), findsOneWidget);
      expect(find.byType(FeaturedBadge), findsNothing);
    });

    testWidgets('Featured status: the Featured badge when it is', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _business, business: _profile(featured: true));

      expect(find.byType(FeaturedBadge), findsOneWidget);
      expect(find.text('Not featured'), findsNothing);
    });

    testWidgets('Featured status row is display only (no navigation)', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _business, business: _profile(featured: true));

      final ListTile tile = tester.widget<ListTile>(
        find.descendant(
          of: find.byKey(ProfileHubScreen.featuredStatusKey),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile.onTap, isNull);
    });

    testWidgets('Staff: Moderation group with the pending count badge', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _staff, pending: 7);

      expect(find.text('Moderation'), findsOneWidget);
      expect(find.text('Moderation queue'), findsOneWidget);
      expect(find.byKey(ProfileHubScreen.moderationBadgeKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ProfileHubScreen.moderationBadgeKey),
          matching: find.text('7'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ProfileHubScreen.accountTypeChipKey),
          matching: find.text('Staff'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Staff: no badge when nothing is pending', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _staff, pending: 0);

      expect(_row(RouteNames.moderation), findsOneWidget);
      expect(find.byKey(ProfileHubScreen.moderationBadgeKey), findsNothing);
    });
  });

  group('P-113 STEP 3A: rows open the right screen', () {
    Future<void> expectTapOpens(
      WidgetTester tester, {
      required User user,
      required String rowId,
      required String routeName,
      BusinessProfile? business,
    }) async {
      await _pump(tester, user: user, business: business);
      await tester.tap(_row(rowId));
      await tester.pumpAndSettle();
      expect(find.text('stub:$routeName'), findsOneWidget);
    }

    testWidgets('Saved', (WidgetTester tester) async {
      await expectTapOpens(
        tester,
        user: _customer,
        rowId: RouteNames.saved,
        routeName: RouteNames.saved,
      );
    });

    testWidgets('Notification preferences', (WidgetTester tester) async {
      await expectTapOpens(
        tester,
        user: _customer,
        rowId: RouteNames.notificationPreferences,
        routeName: RouteNames.notificationPreferences,
      );
    });

    for (final String route in <String>[
      RouteNames.businessConsole,
      RouteNames.businessProfileEdit,
      RouteNames.productList,
      RouteNames.contentList,
      RouteNames.storyList,
      RouteNames.businessAnalytics,
    ]) {
      testWidgets('Business tools row: $route', (WidgetTester tester) async {
        await expectTapOpens(
          tester,
          user: _business,
          business: _profile(),
          rowId: route,
          routeName: route,
        );
      });
    }

    testWidgets('Moderation queue (Staff)', (WidgetTester tester) async {
      await expectTapOpens(
        tester,
        user: _staff,
        rowId: RouteNames.moderation,
        routeName: RouteNames.moderation,
      );
    });

    testWidgets('a pushed screen returns to the hub with back', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _customer);
      await tester.tap(_row(RouteNames.notificationPreferences));
      await tester.pumpAndSettle();
      expect(find.text('stub:${RouteNames.notificationPreferences}'), findsOneWidget);

      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('Profile & Settings'), findsOneWidget);
    });

    testWidgets('About opens the about dialog', (WidgetTester tester) async {
      await _pump(tester, user: _customer);
      await tester.tap(_row(ProfileHubScreen.aboutId));
      await tester.pumpAndSettle();

      expect(find.byType(AboutDialog), findsOneWidget);
    });
  });

  group('P-113 STEP 3A: log out', () {
    testWidgets('asks for confirmation and does not sign out yet', (
      WidgetTester tester,
    ) async {
      final _FakeSession session = await _pump(tester, user: _customer);

      await tester.tap(_row(kNavLogoutId));
      await tester.pumpAndSettle();

      expect(find.byKey(ProfileHubScreen.logoutDialogKey), findsOneWidget);
      expect(find.text('Log out?'), findsOneWidget);
      expect(session.logoutCalls, 0);
    });

    testWidgets('Cancel closes the dialog and keeps the session', (
      WidgetTester tester,
    ) async {
      final _FakeSession session = await _pump(tester, user: _customer);

      await tester.tap(_row(kNavLogoutId));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProfileHubScreen.logoutCancelKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ProfileHubScreen.logoutDialogKey), findsNothing);
      expect(session.logoutCalls, 0);
      expect(find.text('Profile & Settings'), findsOneWidget);
    });

    testWidgets('Confirm signs out exactly once', (WidgetTester tester) async {
      final _FakeSession session = await _pump(tester, user: _customer);

      await tester.tap(_row(kNavLogoutId));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProfileHubScreen.logoutConfirmKey));
      await tester.pumpAndSettle();

      expect(session.logoutCalls, 1);
      expect(find.byKey(ProfileHubScreen.logoutDialogKey), findsNothing);
    });
  });

  group('P-113 STEP 3A: Arabic', () {
    testWidgets('texts are Arabic and the layout is right-to-left', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _customer, locale: const Locale('ar'));

      expect(find.text(_arTitle), findsOneWidget);
      expect(find.text(_arLogOut), findsOneWidget);
      expect(find.text('Profile & Settings'), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(ProfileHubScreen))),
        TextDirection.rtl,
      );
    });
  });
}
'@
$sources.Add(@{ Path = 'test\features\profile_hub\presentation\profile_hub_screen_test.dart'; Content = $src7; Replaces = $false })

# ---------------------------------------------------------------
# 1. Second preflight: never overwrite a file that is not ours
# ---------------------------------------------------------------
if (-not $arbAlreadyDone) {
    $newKeys = @()
    foreach ($m in [regex]::Matches($arbEn, '(?m)^  "(hub[A-Za-z0-9]+)":')) {
        $newKeys += $m.Groups[1].Value
    }
    $clashes = @()
    foreach ($k in $newKeys) {
        if ($enText.Contains('"' + $k + '"') -or $arText.Contains('"' + $k + '"')) { $clashes += $k }
    }
    if ($clashes.Count -gt 0) {
        throw ("These ARB keys already exist, so the new keys would collide: " + ($clashes -join ', ') + ". Nothing was changed.")
    }
}

foreach ($s in $sources) {
    $target = Join-Path $root $s.Path
    if ((Test-Path -LiteralPath $target) -and (-not $s.Replaces) -and (-not $Force)) {
        $existing = Read-Text $target
        if (-not $existing.Contains('STEP 3A')) {
            throw "$($s.Path) already exists and is not a STEP 3A file. Nothing was changed. Use -Force to overwrite it."
        }
    }
}

# ---------------------------------------------------------------
# 2. Backup of every file that will be overwritten or patched
# ---------------------------------------------------------------
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path (Split-Path -Parent $root) ("_p113_step3a_backup_" + $stamp)
$backedUp = @()

function Backup-File([string]$fullPath) {
    if (-not (Test-Path -LiteralPath $fullPath)) { return }
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    $dest = Join-Path $backupRoot $rel
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $fullPath -Destination $dest -Force
    $script:backedUp += $rel
}

foreach ($s in $sources) { Backup-File (Join-Path $root $s.Path) }
if (-not $arbAlreadyDone) {
    Backup-File $enPath
    Backup-File $arPath
}

# ---------------------------------------------------------------
# 3. Write the Dart files (new files, and the hub screen replacing STEP 1's placeholder)
# ---------------------------------------------------------------
$created = @()
$replaced = @()
foreach ($s in $sources) {
    $target = Join-Path $root $s.Path
    $existed = Test-Path -LiteralPath $target
    Save-Text $target $s.Content
    if ($existed) { $replaced += $s.Path } else { $created += $s.Path }
    Write-Host ("  wrote " + $s.Path)
}

# ---------------------------------------------------------------
# 4. ARB files: append the new keys at the very end, change nothing else
# ---------------------------------------------------------------
function Add-ArbEntries([string]$path, [string]$entries) {
    $text = Read-Text $path
    $nl = "`n"
    if ($text.Contains("`r`n")) { $nl = "`r`n" }

    $trimmed = $text.TrimEnd()
    if (-not $trimmed.EndsWith('}')) {
        throw "$path does not end with '}', refusing to patch it."
    }
    $body = $trimmed.Substring(0, $trimmed.Length - 1).TrimEnd()
    if ($body.EndsWith(',')) {
        throw "$path has a trailing comma before the closing brace, refusing to patch it."
    }

    $block = $entries -replace "`r`n", "`n"
    $block = $block.TrimEnd() -replace "`n", $nl
    $patched = $body + ',' + $nl + $block + $nl + '}' + $nl

    # The result must still be valid JSON before it is written.
    try { $null = $patched | ConvertFrom-Json } catch {
        throw "Patched $path is not valid JSON, nothing was written to it: $($_.Exception.Message)"
    }
    [System.IO.File]::WriteAllText($path, $patched, $utf8NoBom)
}

$arbPatched = @()
if ($arbAlreadyDone) {
    Write-Host '  ARB keys already present, skipped.'
} else {
    Add-ArbEntries $enPath $arbEn
    Add-ArbEntries $arPath $arbAr
    $arbPatched += 'lib\l10n\app_en.arb'
    $arbPatched += 'lib\l10n\app_ar.arb'
    Write-Host '  appended hub keys to app_en.arb and app_ar.arb'
}

# ---------------------------------------------------------------
# 5. Regenerate AppLocalizations (committed generated files)
# ---------------------------------------------------------------
$genStatus = 'skipped (-SkipGenL10n)'
if (-not $SkipGenL10n) {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        $genStatus = 'NOT RUN: flutter is not on PATH'
        Write-Warning 'flutter is not on PATH. Run "flutter gen-l10n" yourself from the project folder.'
    } else {
        # Windows PowerShell 5.1 turns any stderr line of a native command into
        # a terminating error when ErrorActionPreference is 'Stop', so relax it
        # for this one call and judge by the exit code instead.
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        Push-Location $root
        try {
            & flutter gen-l10n
            $genExit = $LASTEXITCODE
        } finally {
            Pop-Location
            $ErrorActionPreference = $previousPreference
        }
        if ($genExit -ne 0) { throw "flutter gen-l10n failed with exit code $genExit" }
        $gen = Read-Text (Join-Path $root 'lib\l10n\app_localizations.dart')
        if (-not $gen.Contains('hubTitle')) {
            throw 'flutter gen-l10n finished but app_localizations.dart has no hubTitle. Check l10n.yaml.'
        }
        $genStatus = 'done (lib\l10n\app_localizations*.dart regenerated)'
    }
}

# ---------------------------------------------------------------
# 6. Summary
# ---------------------------------------------------------------
Write-Host ''
Write-Host '================ P-113 STEP 3 / PART A - done ================'
Write-Host 'Created:'
foreach ($p in $created) { Write-Host ("  + " + $p) }
Write-Host 'Replaced (STEP 1 placeholder or a previous run of this step):'
foreach ($p in $replaced) { Write-Host ("  ~ " + $p) }
Write-Host 'Patched (new keys appended at the end only):'
foreach ($p in $arbPatched) { Write-Host ("  ~ " + $p) }
Write-Host ("gen-l10n: " + $genStatus)
if ($backedUp.Count -gt 0) { Write-Host ("Backup of replaced files: " + $backupRoot) }
Write-Host ''
Write-Host 'Next, from the project folder:'
Write-Host '  flutter analyze'
Write-Host '  flutter test test\features\profile_hub test\l10n test\routing test\core\shell'
Write-Host '  flutter test'