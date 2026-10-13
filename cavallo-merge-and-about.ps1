<#
.SYNOPSIS
  Cavallo: merge every branch into main (both repos) + new About dialog (no licenses button).

.DESCRIPTION
  1. cavallo-app (backend):   merges all remote branches into main.
  2. cavallo-mobile (Flutter): merges all remote branches into main, then applies the About changes:
       - new About dialog: description, version 0.0.1, release Oct 2026, developer, Email + WhatsApp buttons
       - "View licenses" is gone (Flutter's built-in showAboutDialog is no longer used)
       - Arabic + English strings, Android package-visibility entries, pubspec version 0.0.1+1, tests
  Nothing is pushed unless you pass -Push. Safe to run twice (steps already applied are skipped).

.EXAMPLE
  .\cavallo-merge-and-about.ps1 -BackendPath D:\work\cavallo-app -MobilePath D:\work\cavallo-mobile
  .\cavallo-merge-and-about.ps1 -BackendPath D:\work\cavallo-app -MobilePath D:\work\cavallo-mobile -Push
#>
param(
  [string]$BackendPath,
  [string]$MobilePath,
  [switch]$Push
)

$ErrorActionPreference = 'Stop'
if (-not $BackendPath) { $BackendPath = Read-Host 'Path of the local cavallo-app (backend) folder' }
if (-not $MobilePath)  { $MobilePath  = Read-Host 'Path of the local cavallo-mobile folder' }

function Invoke-Git {
  & git @args
  if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit $LASTEXITCODE)" }
}

function Merge-AllBranchesIntoMain([string]$RepoPath) {
  if (-not (Test-Path $RepoPath)) { throw "Folder not found: $RepoPath" }
  Set-Location $RepoPath
  & git rev-parse --git-dir *> $null
  if ($LASTEXITCODE -ne 0) { throw "Not a git repo: $RepoPath" }
  Write-Host "`n=== $RepoPath ===" -ForegroundColor Cyan
  $dirty = (& git status --porcelain --untracked-files=no)
  if ($dirty) { throw "Uncommitted changes in $RepoPath. Commit or stash them first:`n$dirty" }
  Invoke-Git fetch --all --prune
  Invoke-Git checkout main
  Invoke-Git pull --ff-only origin main
  $branches = (& git branch -r --format='%(refname:short)') |
    Where-Object { $_ -like 'origin/*' -and $_ -ne 'origin/HEAD' -and $_ -ne 'origin/main' }
  foreach ($b in $branches) {
    Write-Host "Merging $b into main ..."
    & git merge --no-edit $b
    if ($LASTEXITCODE -ne 0) {
      & git merge --abort 2>$null
      throw "Merge conflict with $b. Merge aborted; resolve it manually, then re-run."
    }
  }
}

function Update-File([string]$Path, [string]$Old, [string]$New) {
  if (-not (Test-Path $Path)) { throw "File not found: $Path" }
  $Old = $Old.Replace("`r`n", "`n")
  $New = $New.Replace("`r`n", "`n")
  $raw  = [System.IO.File]::ReadAllText($Path)
  $crlf = $raw.Contains("`r`n")
  $text = $raw.Replace("`r`n", "`n")
  if ($text.Contains($New)) { Write-Host "  already applied: $Path"; return }
  $i = $text.IndexOf($Old)
  if ($i -lt 0) { throw "Expected text not found in $Path. The file differs from what this script expects." }
  if ($text.IndexOf($Old, $i + 1) -ge 0) { throw "Expected text appears more than once in $Path." }
  $text = $text.Substring(0, $i) + $New + $text.Substring($i + $Old.Length)
  if ($crlf) { $text = $text.Replace("`n", "`r`n") }
  [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  patched: $Path"
}

function Write-NewFile([string]$Path, [string]$Content) {
  $dir = Split-Path $Path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $Content = $Content.Replace("`r`n", "`n")
  [System.IO.File]::WriteAllText($Path, $Content + "`n", (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  wrote:   $Path"
}

# ---------------------------------------------------------------- 1) backend
Merge-AllBranchesIntoMain $BackendPath
if ($Push) { Invoke-Git push origin main }

# ---------------------------------------------------------------- 2) mobile
Merge-AllBranchesIntoMain $MobilePath
Set-Location $MobilePath
Write-Host "`nApplying About changes ..." -ForegroundColor Cyan
$old = @'
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
'@
$new = @'
            <data android:mimeType="text/plain"/>
        </intent>
        <!-- About screen: open the e-mail app and WhatsApp (wa.me link). -->
        <intent>
            <action android:name="android.intent.action.SENDTO"/>
            <data android:scheme="mailto"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
    </queries>
</manifest>
'@
Update-File 'android/app/src/main/AndroidManifest.xml' $old $new

$old = @'
import '../../moderation/domain/queue_item_entity.dart';
import '../../moderation/presentation/moderation_provider.dart';
import 'appearance_selector.dart';
import 'business_shortcuts.dart';
'@
$new = @'
import '../../moderation/domain/queue_item_entity.dart';
import '../../moderation/presentation/moderation_provider.dart';
import 'about_cavallo_dialog.dart';
import 'appearance_selector.dart';
import 'business_shortcuts.dart';
'@
Update-File 'lib/features/profile_hub/presentation/profile_hub_screen.dart' $old $new

$old = @'
                icon: Icons.info_outline,
                title: l10n.hubAbout,
                onTap:
                    () => showAboutDialog(
                      context: context,
                      applicationName: l10n.appTitle,
                    ),
              ),
            ],
'@
$new = @'
                icon: Icons.info_outline,
                title: l10n.hubAbout,
                onTap: () => showCavalloAboutDialog(context),
              ),
            ],
'@
Update-File 'lib/features/profile_hub/presentation/profile_hub_screen.dart' $old $new

$old = @'
  "hubModerationQueue": "\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629",
  "hubAbout": "\u0639\u0646 \u0627\u0644\u062a\u0637\u0628\u064a\u0642",
  "hubLogOut": "\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c",
  "hubLogOutConfirmTitle": "\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c\u061f",
'@
$new = @'
  "hubModerationQueue": "\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629",
  "hubAbout": "\u0639\u0646 \u0627\u0644\u062a\u0637\u0628\u064a\u0642",
  "aboutAppName": "Cavallo",
  "aboutDescription": "\u0643\u0627\u0641\u0627\u0644\u0648 \u0647\u0648 \u062d\u0644\u0642\u0629 \u0627\u0644\u0648\u0635\u0644 \u0628\u064a\u0646 \u0627\u0644\u062a\u0627\u062c\u0631 \u0623\u0648 \u0627\u0644\u0645\u0635\u0646\u0639 \u0623\u0648 \u0635\u0627\u062d\u0628 \u0627\u0644\u0639\u0645\u0644 \u0648\u0628\u064a\u0646 \u0627\u0644\u0639\u0645\u064a\u0644. \u062a\u0635\u0641\u0651\u062d \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a \u0648\u0627\u0644\u0639\u0631\u0648\u0636\u060c \u0648\u062a\u0627\u0628\u0639 \u0627\u0644\u0623\u0646\u0634\u0637\u0629 \u0627\u0644\u062a\u062c\u0627\u0631\u064a\u0629 \u0627\u0644\u062a\u064a \u062a\u0639\u062c\u0628\u0643\u060c \u0648\u062a\u0648\u0627\u0635\u0644 \u0645\u0639\u0647\u0627 \u0645\u0628\u0627\u0634\u0631\u0629 \u0641\u064a \u0645\u0643\u0627\u0646 \u0648\u0627\u062d\u062f.",
  "aboutVersionLabel": "\u0627\u0644\u0625\u0635\u062f\u0627\u0631",
  "aboutReleaseLabel": "\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631",
  "aboutReleaseValue": "\u0623\u0643\u062a\u0648\u0628\u0631 2026",
  "aboutDeveloperLabel": "\u062a\u0637\u0648\u064a\u0631",
  "aboutDeveloperValue": "\u0645\u0647\u0646\u062f\u0633 \u0627\u0644\u0628\u0631\u0645\u062c\u064a\u0627\u062a \u0623\u062d\u0645\u062f \u0625\u0628\u0631\u0627\u0647\u064a\u0645",
  "aboutSupportTitle": "\u062a\u0648\u0627\u0635\u0644 \u0645\u0639\u0646\u0627 \u0623\u0648 \u0627\u0637\u0644\u0628 \u0627\u0644\u0645\u0633\u0627\u0639\u062f\u0629 \u0623\u0648 \u0623\u0628\u0644\u063a \u0639\u0646 \u0645\u0634\u0643\u0644\u0629",
  "aboutEmailButton": "\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a",
  "aboutWhatsappButton": "\u0648\u0627\u062a\u0633\u0627\u0628",
  "aboutCouldNotOpen": "\u062a\u0639\u0630\u0651\u0631 \u0627\u0644\u0641\u062a\u062d. \u064a\u0631\u062c\u0649 \u0627\u0644\u062a\u0648\u0627\u0635\u0644 \u0645\u0639\u0646\u0627 \u0639\u0628\u0631 \u0627\u0644\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0645\u0648\u0636\u062d\u0629 \u0623\u0639\u0644\u0627\u0647.",
  "aboutClose": "\u0625\u063a\u0644\u0627\u0642",
  "hubLogOut": "\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c",
  "hubLogOutConfirmTitle": "\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c\u061f",
'@
Update-File 'lib/l10n/app_ar.arb' $old $new

$old = @'
  "@hubAbout": {
    "description": "Hub row: opens the About dialog."
  },
  "hubLogOut": "Log out",
'@
$new = @'
  "@hubAbout": {
    "description": "Hub row: opens the About dialog."
  },
  "aboutAppName": "Cavallo",
  "@aboutAppName": {
    "description": "About dialog: the app name."
  },
  "aboutDescription": "Cavallo connects customers directly with merchants, factories and business owners. Discover products and offers, follow the businesses you like, and chat with them in one place.",
  "@aboutDescription": {
    "description": "About dialog: what the app is for."
  },
  "aboutVersionLabel": "Version",
  "@aboutVersionLabel": {
    "description": "About dialog: label of the version line."
  },
  "aboutReleaseLabel": "Release",
  "@aboutReleaseLabel": {
    "description": "About dialog: label of the release date line."
  },
  "aboutReleaseValue": "October 2026",
  "@aboutReleaseValue": {
    "description": "About dialog: release month and year."
  },
  "aboutDeveloperLabel": "Developed by",
  "@aboutDeveloperLabel": {
    "description": "About dialog: label of the developer line."
  },
  "aboutDeveloperValue": "Software Engineer Ahmed Ibrahim",
  "@aboutDeveloperValue": {
    "description": "About dialog: the developer name."
  },
  "aboutSupportTitle": "Contact, help or report a problem",
  "@aboutSupportTitle": {
    "description": "About dialog: heading above the two contact buttons."
  },
  "aboutEmailButton": "Email",
  "@aboutEmailButton": {
    "description": "About dialog: button that opens the e-mail app."
  },
  "aboutWhatsappButton": "WhatsApp",
  "@aboutWhatsappButton": {
    "description": "About dialog: button that opens WhatsApp."
  },
  "aboutCouldNotOpen": "Couldn't open it. Please contact us using the details above.",
  "@aboutCouldNotOpen": {
    "description": "About dialog: shown when no app could open the e-mail or WhatsApp link."
  },
  "aboutClose": "Close",
  "@aboutClose": {
    "description": "About dialog: close button."
  },
  "hubLogOut": "Log out",
'@
Update-File 'lib/l10n/app_en.arb' $old $new

$old = @'
  /// **'About'**
  String get hubAbout;

  /// Hub row and confirm button: sign out of the account.
'@
$new = @'
  /// **'About'**
  String get hubAbout;

  /// About dialog: the app name.
  ///
  /// In en, this message translates to:
  /// **'Cavallo'**
  String get aboutAppName;

  /// About dialog: what the app is for.
  ///
  /// In en, this message translates to:
  /// **'Cavallo connects customers directly with merchants, factories and business owners. Discover products and offers, follow the businesses you like, and chat with them in one place.'**
  String get aboutDescription;

  /// About dialog: label of the version line.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersionLabel;

  /// About dialog: label of the release date line.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get aboutReleaseLabel;

  /// About dialog: release month and year.
  ///
  /// In en, this message translates to:
  /// **'October 2026'**
  String get aboutReleaseValue;

  /// About dialog: label of the developer line.
  ///
  /// In en, this message translates to:
  /// **'Developed by'**
  String get aboutDeveloperLabel;

  /// About dialog: the developer name.
  ///
  /// In en, this message translates to:
  /// **'Software Engineer Ahmed Ibrahim'**
  String get aboutDeveloperValue;

  /// About dialog: heading above the two contact buttons.
  ///
  /// In en, this message translates to:
  /// **'Contact, help or report a problem'**
  String get aboutSupportTitle;

  /// About dialog: button that opens the e-mail app.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get aboutEmailButton;

  /// About dialog: button that opens WhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get aboutWhatsappButton;

  /// About dialog: shown when no app could open the e-mail or WhatsApp link.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open it. Please contact us using the details above.'**
  String get aboutCouldNotOpen;

  /// About dialog: close button.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get aboutClose;

  /// Hub row and confirm button: sign out of the account.
'@
Update-File 'lib/l10n/app_localizations.dart' $old $new

$old = @'
  @override
  String get hubAbout => 'عن التطبيق';

  @override
'@
$new = @'
  @override
  String get hubAbout => 'عن التطبيق';

  @override
  String get aboutAppName => 'Cavallo';

  @override
  String get aboutDescription => 'كافالو هو حلقة الوصل بين التاجر أو المصنع أو صاحب العمل وبين العميل. تصفّح المنتجات والعروض، وتابع الأنشطة التجارية التي تعجبك، وتواصل معها مباشرة في مكان واحد.';

  @override
  String get aboutVersionLabel => 'الإصدار';

  @override
  String get aboutReleaseLabel => 'تاريخ الإصدار';

  @override
  String get aboutReleaseValue => 'أكتوبر 2026';

  @override
  String get aboutDeveloperLabel => 'تطوير';

  @override
  String get aboutDeveloperValue => 'مهندس البرمجيات أحمد إبراهيم';

  @override
  String get aboutSupportTitle => 'تواصل معنا أو اطلب المساعدة أو أبلغ عن مشكلة';

  @override
  String get aboutEmailButton => 'البريد الإلكتروني';

  @override
  String get aboutWhatsappButton => 'واتساب';

  @override
  String get aboutCouldNotOpen => 'تعذّر الفتح. يرجى التواصل معنا عبر البيانات الموضحة أعلاه.';

  @override
  String get aboutClose => 'إغلاق';

  @override
'@
Update-File 'lib/l10n/app_localizations_ar.dart' $old $new

$old = @'
  @override
  String get hubAbout => 'About';

  @override
'@
$new = @'
  @override
  String get hubAbout => 'About';

  @override
  String get aboutAppName => 'Cavallo';

  @override
  String get aboutDescription => 'Cavallo connects customers directly with merchants, factories and business owners. Discover products and offers, follow the businesses you like, and chat with them in one place.';

  @override
  String get aboutVersionLabel => 'Version';

  @override
  String get aboutReleaseLabel => 'Release';

  @override
  String get aboutReleaseValue => 'October 2026';

  @override
  String get aboutDeveloperLabel => 'Developed by';

  @override
  String get aboutDeveloperValue => 'Software Engineer Ahmed Ibrahim';

  @override
  String get aboutSupportTitle => 'Contact, help or report a problem';

  @override
  String get aboutEmailButton => 'Email';

  @override
  String get aboutWhatsappButton => 'WhatsApp';

  @override
  String get aboutCouldNotOpen => 'Couldn\'t open it. Please contact us using the details above.';

  @override
  String get aboutClose => 'Close';

  @override
'@
Update-File 'lib/l10n/app_localizations_en.dart' $old $new

$old = @'
description: "Social Commerce Discovery Platform — mobile app (Customer / Trader-Factory / Admin surfaces share this codebase per Section 12)."
publish_to: "none"
version: 0.1.0+1

environment:
'@
$new = @'
description: "Social Commerce Discovery Platform — mobile app (Customer / Trader-Factory / Admin surfaces share this codebase per Section 12)."
publish_to: "none"
version: 0.0.1+1

environment:
'@
Update-File 'pubspec.yaml' $old $new

$old = @'
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/profile_hub_screen.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/settings_rows.dart';
'@
$new = @'
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/about_cavallo_dialog.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/profile_hub_screen.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/settings_rows.dart';
'@
Update-File 'test/features/profile_hub/presentation/profile_hub_screen_test.dart' $old $new

$old = @'
    });

    testWidgets('About opens the about dialog', (WidgetTester tester) async {
      await _pump(tester, user: _customer);
      await tester.tap(_row(ProfileHubScreen.aboutId));
'@
$new = @'
    });

    testWidgets('About opens the Cavallo about dialog, without a licenses button', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _customer);
      await tester.tap(_row(ProfileHubScreen.aboutId));
'@
Update-File 'test/features/profile_hub/presentation/profile_hub_screen_test.dart' $old $new

$old = @'
      await tester.pumpAndSettle();

      expect(find.byType(AboutDialog), findsOneWidget);
    });
  });
'@
$new = @'
      await tester.pumpAndSettle();

      expect(find.byKey(CavalloAboutDialog.dialogKey), findsOneWidget);
      expect(find.byType(AboutDialog), findsNothing);
      expect(find.textContaining('icenses'), findsNothing);
    });
  });
'@
Update-File 'test/features/profile_hub/presentation/profile_hub_screen_test.dart' $old $new

$content = @'
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// The version shown in the About dialog. Keep in step with `pubspec.yaml`.
const String kCavalloVersion = '0.0.1';

/// Support e-mail shown (and opened) from the About dialog.
const String kCavalloSupportEmail = 'ahmedibrahim0112223257@gmail.com';

/// Support WhatsApp number as typed locally, for display.
const String kCavalloSupportPhoneDisplay = '01029102507';

/// The same number in international form (Egypt, +20) for the wa.me link.
const String kCavalloSupportPhoneInternational = '201029102507';

/// Opens [uri] outside the app. Returns false when nothing could handle it.
typedef CavalloUrlOpener = Future<bool> Function(Uri uri);

Future<bool> _launchExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Shows the Cavallo About dialog.
///
/// This replaces Flutter's built-in `showAboutDialog`, whose "View licenses"
/// button is intentionally not offered to users.
Future<void> showCavalloAboutDialog(
  BuildContext context, {
  CavalloUrlOpener opener = _launchExternally,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => CavalloAboutDialog(opener: opener),
  );
}

/// About Cavallo: what the app is for, version, who built it, and two ways
/// to get in touch (contact, help or report a problem): e-mail and WhatsApp.
class CavalloAboutDialog extends StatefulWidget {
  const CavalloAboutDialog({this.opener = _launchExternally, super.key});

  final CavalloUrlOpener opener;

  static const Key dialogKey = Key('cavalloAboutDialog');
  static const Key emailButtonKey = Key('cavalloAboutEmailButton');
  static const Key whatsappButtonKey = Key('cavalloAboutWhatsappButton');
  static const Key openFailedKey = Key('cavalloAboutOpenFailed');
  static const Key closeButtonKey = Key('cavalloAboutCloseButton');

  @override
  State<CavalloAboutDialog> createState() => _CavalloAboutDialogState();
}

class _CavalloAboutDialogState extends State<CavalloAboutDialog> {
  bool _openFailed = false;

  Future<void> _open(Uri uri) async {
    bool opened = false;
    try {
      opened = await widget.opener(uri);
    } catch (_) {
      opened = false;
    }
    if (!mounted) {
      return;
    }
    setState(() => _openFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    return AlertDialog(
      key: CavalloAboutDialog.dialogKey,
      scrollable: true,
      title: Text(l10n.aboutAppName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.aboutDescription, style: text.bodyMedium),
          const SizedBox(height: 16),
          _InfoRow(label: l10n.aboutVersionLabel, value: kCavalloVersion),
          _InfoRow(
            label: l10n.aboutReleaseLabel,
            value: l10n.aboutReleaseValue,
          ),
          _InfoRow(
            label: l10n.aboutDeveloperLabel,
            value: l10n.aboutDeveloperValue,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.aboutSupportTitle,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: CavalloAboutDialog.emailButtonKey,
              onPressed:
                  () => _open(
                    Uri(scheme: 'mailto', path: kCavalloSupportEmail),
                  ),
              icon: const Icon(Icons.email_outlined),
              label: Text(l10n.aboutEmailButton),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                kCavalloSupportEmail,
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: CavalloAboutDialog.whatsappButtonKey,
              onPressed:
                  () => _open(
                    Uri.parse(
                      'https://wa.me/$kCavalloSupportPhoneInternational',
                    ),
                  ),
              icon: const Icon(Icons.chat_outlined),
              label: Text(l10n.aboutWhatsappButton),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                kCavalloSupportPhoneDisplay,
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ),
          ),
          if (_openFailed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l10n.aboutCouldNotOpen,
                key: CavalloAboutDialog.openFailedKey,
                style: text.bodySmall?.copyWith(color: colors.dangerText),
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          key: CavalloAboutDialog.closeButtonKey,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.aboutClose),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$label: ',
            style: text.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
'@
Write-NewFile 'lib/features/profile_hub/presentation/about_cavallo_dialog.dart' $content

$content = @'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/about_cavallo_dialog.dart';

/// The About dialog: description, version, developer, two contact buttons,
/// and no "View licenses" button.
void main() {
  Future<List<Uri>> pumpDialog(
    WidgetTester tester, {
    bool opens = true,
  }) async {
    final List<Uri> opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CavalloAboutDialog(
            opener: (Uri uri) async {
              opened.add(uri);
              return opens;
            },
          ),
        ),
      ),
    );
    return opened;
  }

  testWidgets('shows the app name, version, release and developer', (
    WidgetTester tester,
  ) async {
    await pumpDialog(tester);

    expect(find.text('Cavallo'), findsOneWidget);
    expect(find.textContaining('0.0.1'), findsOneWidget);
    expect(find.textContaining('October 2026'), findsOneWidget);
    expect(find.textContaining('Ahmed Ibrahim'), findsOneWidget);
  });

  testWidgets('has no licenses button', (WidgetTester tester) async {
    await pumpDialog(tester);

    expect(find.textContaining('icenses'), findsNothing);
    expect(find.byType(AboutDialog), findsNothing);
  });

  testWidgets('e-mail button opens a mailto link', (WidgetTester tester) async {
    final List<Uri> opened = await pumpDialog(tester);

    await tester.tap(find.byKey(CavalloAboutDialog.emailButtonKey));
    await tester.pump();

    expect(opened, hasLength(1));
    expect(opened.single.scheme, 'mailto');
    expect(opened.single.path, kCavalloSupportEmail);
  });

  testWidgets('WhatsApp button opens the wa.me link', (
    WidgetTester tester,
  ) async {
    final List<Uri> opened = await pumpDialog(tester);

    await tester.tap(find.byKey(CavalloAboutDialog.whatsappButtonKey));
    await tester.pump();

    expect(opened.single.toString(), 'https://wa.me/201029102507');
  });

  testWidgets('tells the user when nothing could open the link', (
    WidgetTester tester,
  ) async {
    await pumpDialog(tester, opens: false);

    expect(find.byKey(CavalloAboutDialog.openFailedKey), findsNothing);
    await tester.tap(find.byKey(CavalloAboutDialog.emailButtonKey));
    await tester.pump();

    expect(find.byKey(CavalloAboutDialog.openFailedKey), findsOneWidget);
  });
}
'@
Write-NewFile 'test/features/profile_hub/presentation/about_cavallo_dialog_test.dart' $content


$files = @(
  'android/app/src/main/AndroidManifest.xml',
  'lib/features/profile_hub/presentation/profile_hub_screen.dart',
  'lib/l10n/app_ar.arb',
  'lib/l10n/app_en.arb',
  'lib/l10n/app_localizations.dart',
  'lib/l10n/app_localizations_ar.dart',
  'lib/l10n/app_localizations_en.dart',
  'pubspec.yaml',
  'test/features/profile_hub/presentation/profile_hub_screen_test.dart',
  'lib/features/profile_hub/presentation/about_cavallo_dialog.dart',
  'test/features/profile_hub/presentation/about_cavallo_dialog_test.dart'
)
Invoke-Git add -- $files
& git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
  Write-Host "Nothing new to commit (About changes were already in main)."
} else {
  $msg = @"
About: new Cavallo About dialog (description, v0.0.1, developer, email + WhatsApp), remove View licenses

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PiE5fQibdkycYT31R7b44g
"@
  Invoke-Git commit -m $msg
}
if ($Push) { Invoke-Git push origin main }

Write-Host "`nDone. Next: run 'flutter pub get' then 'flutter test test/features/profile_hub' to verify." -ForegroundColor Green
if (-not $Push) { Write-Host "Nothing was pushed. Review with 'git log -3', then 'git push origin main' in each repo." -ForegroundColor Yellow }