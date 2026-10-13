<#
  Cavallo mobile - custom "About" dialog (profile hub) without "View licenses"

  What it does:
    1) Replaces Flutter's showAboutDialog (which always shows a "View licenses"
       button) with a plain AlertDialog: app name, description, developer credit,
       and a Close button.
    2) Adds the 4 new strings in Arabic + English: ARB files AND the generated
       app_localizations*.dart files (kept in sync by hand, same format as
       gen-l10n, so a later `flutter gen-l10n` produces the same output).
    3) Updates the widget test that expected AboutDialog and adds an Arabic one.

  Run it from the root of cavallo-mobile, on the branch that has the profile hub
  (part-111 at the time of writing):
      .\cavallo-about-dialog-patch.ps1
      .\cavallo-about-dialog-patch.ps1 -RepoPath "C:\path\cavallo-mobile" -Commit

  Safe to re-run: files that already contain the change are skipped, and nothing
  is written unless EVERY anchor matched exactly once.
#>

param(
    [string]$RepoPath = (Get-Location).Path,
    [switch]$Commit
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Arabic is stored as \u escapes so this script stays pure ASCII (no encoding issues
# in Windows PowerShell 5.1).
function U([string]$escaped) { [regex]::Unescape($escaped) }

# ------------------------------------------------------------------ Texts
$enName  = 'Cavallo'
$enDesc  = 'Cavallo is a social commerce app that connects traders and factories with customers. Share reels, posts and stories, discover products and businesses, and chat directly to get deals done, all in one place.'
$enDev   = 'Developed by Eng. Ahmed Ibrahim'
$enClose = 'Close'

$arNameEsc  = '\u0642\u0628\u0627\u0644\u0648'
$arDescEsc  = '\u0642\u0628\u0627\u0644\u0648 \u062a\u0637\u0628\u064a\u0642 \u062a\u062c\u0627\u0631\u0629 \u0627\u062c\u062a\u0645\u0627\u0639\u064a\u0629 \u064a\u0631\u0628\u0637 \u0628\u064a\u0646 \u0627\u0644\u062a\u062c\u0627\u0631 \u0648\u0627\u0644\u0645\u0635\u0627\u0646\u0639 \u0648\u0627\u0644\u0639\u0645\u0644\u0627\u0621. \u0634\u0627\u0631\u0643 \u0627\u0644\u0631\u064a\u0644\u0632 \u0648\u0627\u0644\u0645\u0646\u0634\u0648\u0631\u0627\u062a \u0648\u0627\u0644\u0642\u0635\u0635\u060c \u0648\u0627\u0643\u062a\u0634\u0641 \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a \u0648\u0627\u0644\u0623\u0646\u0634\u0637\u0629 \u0627\u0644\u062a\u062c\u0627\u0631\u064a\u0629\u060c \u0648\u062a\u0648\u0627\u0635\u0644 \u0645\u0628\u0627\u0634\u0631\u0629 \u0644\u0625\u062a\u0645\u0627\u0645 \u0635\u0641\u0642\u0627\u062a\u0643 \u0641\u064a \u0645\u0643\u0627\u0646 \u0648\u0627\u062d\u062f.'
$arDevEsc   = '\u062a\u0645 \u062a\u0637\u0648\u064a\u0631\u0647 \u0628\u0648\u0627\u0633\u0637\u0629 \u0645. \u0623\u062d\u0645\u062f \u0625\u0628\u0631\u0627\u0647\u064a\u0645'
$arCloseEsc = '\u0625\u063a\u0644\u0627\u0642'

$arName  = U $arNameEsc
$arDesc  = U $arDescEsc
$arDev   = U $arDevEsc
$arClose = U $arCloseEsc

# ------------------------------------------------------------------ Helpers
function Resolve-RepoFile([string]$rel) {
    $p = Join-Path $RepoPath $rel
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Missing file: $rel`nRun this from the cavallo-mobile root on the branch that has the profile hub (part-111), or pass -RepoPath."
    }
    return $p
}

function Get-Eol([string]$text) {
    if ($text.Contains("`r`n")) { return "`r`n" } else { return "`n" }
}

# Replaces the single regex match; throws unless there is exactly one.
function Replace-Once([string]$text, [string]$pattern, [string]$replacement, [string]$label) {
    $ms = [regex]::Matches($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($ms.Count -ne 1) {
        throw "Anchor '$label' matched $($ms.Count) times (expected exactly 1). The file differs from what this patch expects; nothing was changed."
    }
    $m = $ms[0]
    return $text.Substring(0, $m.Index) + $replacement + $text.Substring($m.Index + $m.Length)
}

# Appends $addition right after the single match of $pattern.
function Append-After([string]$text, [string]$pattern, [string]$addition, [string]$label) {
    $ms = [regex]::Matches($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($ms.Count -ne 1) {
        throw "Anchor '$label' matched $($ms.Count) times (expected exactly 1). The file differs from what this patch expects; nothing was changed."
    }
    $m = $ms[0]
    $end = $m.Index + $m.Length
    return $text.Substring(0, $end) + $addition + $text.Substring($end)
}

function Fix-Eol([string]$snippet, [string]$eol) { return ($snippet -replace "`r?`n", $eol) }

# ------------------------------------------------------------------ Load files
$files = [ordered]@{
    hub     = Resolve-RepoFile "lib/features/profile_hub/presentation/profile_hub_screen.dart"
    test    = Resolve-RepoFile "test/features/profile_hub/presentation/profile_hub_screen_test.dart"
    arbEn   = Resolve-RepoFile "lib/l10n/app_en.arb"
    arbAr   = Resolve-RepoFile "lib/l10n/app_ar.arb"
    genBase = Resolve-RepoFile "lib/l10n/app_localizations.dart"
    genEn   = Resolve-RepoFile "lib/l10n/app_localizations_en.dart"
    genAr   = Resolve-RepoFile "lib/l10n/app_localizations_ar.dart"
}

$orig = @{}
foreach ($k in $files.Keys) { $orig[$k] = [System.IO.File]::ReadAllText($files[$k], $utf8) }
$new = @{}
foreach ($k in $files.Keys) { $new[$k] = $orig[$k] }

# ------------------------------------------------------------------ 1) ARB (English)
if ($new.arbEn.Contains('"aboutAppName"')) {
    Write-Host "app_en.arb: already patched, skipping" -ForegroundColor Yellow
} else {
    $eol = Get-Eol $new.arbEn
    $add = @"

  "aboutAppName": "$enName",
  "@aboutAppName": {
    "description": "About dialog title: the name of the app."
  },
  "aboutDescription": "$enDesc",
  "@aboutDescription": {
    "description": "About dialog body: short description of what the app is."
  },
  "aboutDevelopedBy": "$enDev",
  "@aboutDevelopedBy": {
    "description": "About dialog: developer credit line."
  },
  "aboutClose": "$enClose",
  "@aboutClose": {
    "description": "About dialog: button that closes the dialog."
  },
"@
    $new.arbEn = Append-After $new.arbEn '"@hubAbout": \{[^}]*\},' (Fix-Eol $add $eol).TrimEnd("`r", "`n") "app_en.arb @hubAbout"
}

# ------------------------------------------------------------------ 2) ARB (Arabic, \u-escaped like the rest of the file)
if ($new.arbAr.Contains('"aboutAppName"')) {
    Write-Host "app_ar.arb: already patched, skipping" -ForegroundColor Yellow
} else {
    $eol = Get-Eol $new.arbAr
    $add = @"

  "aboutAppName": "$arNameEsc",
  "aboutDescription": "$arDescEsc",
  "aboutDevelopedBy": "$arDevEsc",
  "aboutClose": "$arCloseEsc",
"@
    $new.arbAr = Append-After $new.arbAr '  "hubAbout": "[^"\r\n]*",' (Fix-Eol $add $eol).TrimEnd("`r", "`n") "app_ar.arb hubAbout"
}

# ------------------------------------------------------------------ 3) Generated: app_localizations.dart (abstract getters)
if ($new.genBase.Contains('String get aboutAppName;')) {
    Write-Host "app_localizations.dart: already patched, skipping" -ForegroundColor Yellow
} else {
    $eol = Get-Eol $new.genBase
    $add = @"


  /// About dialog title: the name of the app.
  ///
  /// In en, this message translates to:
  /// **'$enName'**
  String get aboutAppName;

  /// About dialog body: short description of what the app is.
  ///
  /// In en, this message translates to:
  /// **'$enDesc'**
  String get aboutDescription;

  /// About dialog: developer credit line.
  ///
  /// In en, this message translates to:
  /// **'$enDev'**
  String get aboutDevelopedBy;

  /// About dialog: button that closes the dialog.
  ///
  /// In en, this message translates to:
  /// **'$enClose'**
  String get aboutClose;
"@
    $new.genBase = Append-After $new.genBase '  String get hubAbout;' (Fix-Eol $add $eol).TrimEnd("`r", "`n") "app_localizations.dart hubAbout"
}

# ------------------------------------------------------------------ 4) Generated: English implementation
if ($new.genEn.Contains('String get aboutAppName')) {
    Write-Host "app_localizations_en.dart: already patched, skipping" -ForegroundColor Yellow
} else {
    $eol = Get-Eol $new.genEn
    $add = @"


  @override
  String get aboutAppName => '$enName';

  @override
  String get aboutDescription =>
      '$enDesc';

  @override
  String get aboutDevelopedBy => '$enDev';

  @override
  String get aboutClose => '$enClose';
"@
    $new.genEn = Append-After $new.genEn "  String get hubAbout => '[^'\r\n]*';" (Fix-Eol $add $eol).TrimEnd("`r", "`n") "app_localizations_en.dart hubAbout"
}

# ------------------------------------------------------------------ 5) Generated: Arabic implementation
if ($new.genAr.Contains('String get aboutAppName')) {
    Write-Host "app_localizations_ar.dart: already patched, skipping" -ForegroundColor Yellow
} else {
    $eol = Get-Eol $new.genAr
    $add = @"


  @override
  String get aboutAppName => '$arName';

  @override
  String get aboutDescription =>
      '$arDesc';

  @override
  String get aboutDevelopedBy => '$arDev';

  @override
  String get aboutClose => '$arClose';
"@
    $new.genAr = Append-After $new.genAr "  String get hubAbout => '[^'\r\n]*';" (Fix-Eol $add $eol).TrimEnd("`r", "`n") "app_localizations_ar.dart hubAbout"
}

# ------------------------------------------------------------------ 6) Profile hub screen
if ($new.hub.Contains('_showAbout(')) {
    Write-Host "profile_hub_screen.dart: already patched, skipping" -ForegroundColor Yellow
} else {
    $eol = Get-Eol $new.hub

    # 6a) widget keys
    $keys = @"

  static const Key aboutDialogKey = Key('hub-about-dialog');
  static const Key aboutCloseKey = Key('hub-about-close');
"@
    $new.hub = Append-After $new.hub "  static const Key logoutConfirmKey = Key\('hub-logout-confirm'\);" (Fix-Eol $keys $eol).TrimEnd("`r", "`n") "hub logoutConfirmKey"

    # 6b) row tap: showAboutDialog(...) -> _showAbout(context)
    $new.hub = Replace-Once $new.hub 'onTap:\s*\(\)\s*=>\s*showAboutDialog\(\s*context:\s*context,\s*applicationName:\s*l10n\.appTitle,\s*\),' 'onTap: () => _showAbout(context),' "hub showAboutDialog"

    # 6c) the dialog itself, placed right before _confirmLogout's doc comment
    $method = @'
  /// Shows the About dialog: what the app is and who built it. It is a plain
  /// [AlertDialog] on purpose: Flutter's `showAboutDialog` always adds a
  /// "View licenses" button, which this app does not expose.
  Future<void> _showAbout(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return showDialog<void>(
      context: context,
      builder:
          (BuildContext dialogContext) => AlertDialog(
            key: aboutDialogKey,
            title: Text(l10n.aboutAppName),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.aboutDescription),
                  const SizedBox(height: 16),
                  Text(
                    l10n.aboutDevelopedBy,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                key: aboutCloseKey,
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.aboutClose),
              ),
            ],
          ),
    );
  }


'@
    $anchor = '  /// Asks for confirmation, then signs out through the session provider\. The'
    $ms = [regex]::Matches($new.hub, $anchor)
    if ($ms.Count -ne 1) { throw "Anchor 'hub _confirmLogout doc' matched $($ms.Count) times (expected 1). Nothing was changed." }
    $new.hub = $new.hub.Insert($ms[0].Index, (Fix-Eol $method $eol))
}

# ------------------------------------------------------------------ 7) Test
if ($new.test.Contains('aboutDialogKey')) {
    Write-Host "profile_hub_screen_test.dart: already patched, skipping" -ForegroundColor Yellow
} else {
    $eol = Get-Eol $new.test
    $tests = @"
    testWidgets('About opens a custom dialog without the licenses button', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _customer);
      await tester.tap(_row(ProfileHubScreen.aboutId));
      await tester.pumpAndSettle();

      final Finder dialog = find.byKey(ProfileHubScreen.aboutDialogKey);
      expect(dialog, findsOneWidget);
      expect(find.byType(AboutDialog), findsNothing);
      expect(find.text('View licenses'), findsNothing);
      expect(
        find.descendant(of: dialog, matching: find.text('$enName')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('$enDev')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('$enClose')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(ProfileHubScreen.aboutCloseKey));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
    });

    testWidgets('About dialog is Arabic when the app language is Arabic', (
      WidgetTester tester,
    ) async {
      await _pump(tester, user: _customer, locale: const Locale('ar'));
      await tester.tap(_row(ProfileHubScreen.aboutId));
      await tester.pumpAndSettle();

      final Finder dialog = find.byKey(ProfileHubScreen.aboutDialogKey);
      expect(dialog, findsOneWidget);
      expect(find.text('View licenses'), findsNothing);
      expect(
        find.descendant(of: dialog, matching: find.text('$arName')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('$arDev')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('$arClose')),
        findsOneWidget,
      );
    });
"@
    $pattern = "    testWidgets\('About opens the about dialog'.*?\r?\n    \}\);"
    $new.test = Replace-Once $new.test $pattern (Fix-Eol $tests $eol).TrimEnd("`r", "`n") "test About block"
}

# ------------------------------------------------------------------ Write (only if everything above succeeded)
$changed = @()
foreach ($k in $files.Keys) {
    if ($new[$k] -ne $orig[$k]) {
        [System.IO.File]::WriteAllText($files[$k], $new[$k], $utf8)
        $changed += $files[$k]
        Write-Host "patched: $($files[$k].Substring($RepoPath.Length).TrimStart('\','/'))" -ForegroundColor Green
    }
}

if ($changed.Count -eq 0) {
    Write-Host "Nothing to do - everything is already patched." -ForegroundColor Yellow
    return
}

if ($Commit) {
    & git -C $RepoPath add -- @($changed)
    if ($LASTEXITCODE -ne 0) { throw "git add failed" }
    & git -C $RepoPath commit -m "feat(profile): custom About dialog (description, credits), remove View licenses, AR/EN strings"
    if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
    Write-Host "Committed. Push when ready: git push" -ForegroundColor Green
}

Write-Host ""
Write-Host "Next (on a machine with Flutter): flutter analyze ; flutter test test/features/profile_hub" -ForegroundColor Cyan