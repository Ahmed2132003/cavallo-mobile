# P-115 / STEP 8A - fix 1: two Staff moderation restyle tests asserted English text
# while running in Arabic. The screens are now localized, so the Arabic tests read
# their expected text from the generated Arabic localizations. No test is weakened
# or removed: the same widgets are found, the same positions are compared.
# Run from the repo root:  powershell -ExecutionPolicy Bypass -File .\p115_step8a_fix1.ps1
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Fail([string]$Message) { Write-Host ("STOP: " + $Message) -ForegroundColor Red; Write-Host 'Nothing was changed.' -ForegroundColor Red; exit 1 }
function Count-Occurrences([string]$Text, [string]$Needle) {
    $count = 0; $index = 0
    while (($index = $Text.IndexOf($Needle, $index, [System.StringComparison]::Ordinal)) -ge 0) { $count++; $index += $Needle.Length }
    return $count
}
$edits = New-Object System.Collections.ArrayList
function Add-Edit([string]$Path, [string]$Old, [string]$New) { [void]$script:edits.Add(@{ Path = $Path; Old = $Old; New = $New }) }
$old = @'
/// The moderation strings are still English on purpose: the P-040 tests pump
/// a bare MaterialApp without localization delegates, so localizing this
/// feature is STEP 8 (together with updating those harnesses). RTL is still
'@
$new = @'
/// The moderation strings are localized (STEP 8A). English finders are used
/// in the English tests; the Arabic tests read their expected text from the
/// generated Arabic localizations (this file stays ASCII). RTL is still
'@
Add-Edit 'test/features/moderation/presentation/moderation_restyle_test.dart' $old $new
$old = @'
    expect(find.text('3 d 5 h \u00B7 overdue'), findsOneWidget);
'@
$new = @'
    final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
    expect(
      find.text(
        ar.moderationAgeOverdue(
          formatQueueAge(const Duration(days: 3, hours: 5), l10n: ar),
        ),
      ),
      findsOneWidget,
    );
'@
Add-Edit 'test/features/moderation/presentation/moderation_restyle_test.dart' $old $new
$old = @'
/// Strings stay English on purpose (localizing the moderation feature is
/// STEP 8, together with the old test harnesses).
'@
$new = @'
/// The moderation strings are localized (STEP 8A). The English tests use
/// English finders; the Arabic tests read their expected text from the
/// generated Arabic localizations (this file stays ASCII).
'@
Add-Edit 'test/features/moderation/presentation/moderation_review_restyle_test.dart' $old $new
$old = @'
    expect(
      tester.getCenter(find.text('Type')).dx,
      greaterThan(tester.getCenter(find.text('Post')).dx),
    );
'@
$new = @'
    final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
    expect(
      tester.getCenter(find.text(ar.moderationDetailType)).dx,
      greaterThan(
        tester.getCenter(find.text(ar.moderationContentTypePost)).dx,
      ),
    );
'@
Add-Edit 'test/features/moderation/presentation/moderation_review_restyle_test.dart' $old $new

$contents = @{}
$order = New-Object System.Collections.ArrayList
foreach ($edit in $edits) {
    $path = $edit.Path
    if (-not $contents.ContainsKey($path)) {
        $full = Join-Path $root $path
        if (-not (Test-Path $full)) { Fail ("File not found: " + $path) }
        $contents[$path] = [System.IO.File]::ReadAllText($full, $utf8)
        [void]$order.Add($path)
    }
    $text = $contents[$path]
    $nl = "`n"
    if ($text.Contains("`r`n")) { $nl = "`r`n" }
    $oldText = $edit.Old -replace "`r?`n", $nl
    $newText = $edit.New -replace "`r?`n", $nl
    $found = Count-Occurrences $text $oldText
    if ($found -ne 1) { Fail ("Expected exactly 1 match, found " + $found + " in " + $path + " for: " + $edit.Old.Substring(0, [Math]::Min(80, $edit.Old.Length))) }
    $contents[$path] = $text.Replace($oldText, $newText)
}
$backup = Join-Path $env:TEMP ('p115_step8a_fix1_backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
foreach ($path in $order) {
    $target = Join-Path $backup $path
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root $path) -Destination $target
}
foreach ($path in $order) { [System.IO.File]::WriteAllText((Join-Path $root $path), $contents[$path], $utf8) }
Write-Host ('Edited ' + $order.Count + ' files. Backup: ' + $backup) -ForegroundColor Green

$ErrorActionPreference = 'Continue'
dart format test/features/moderation/presentation/moderation_restyle_test.dart test/features/moderation/presentation/moderation_review_restyle_test.dart
Write-Host '>>> flutter analyze' -ForegroundColor Cyan
flutter analyze
Write-Host ('exit code: ' + $LASTEXITCODE)
Write-Host '>>> flutter test moderation + l10n' -ForegroundColor Cyan
flutter test test/features/moderation test/l10n
Write-Host ('exit code: ' + $LASTEXITCODE)