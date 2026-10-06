# =============================================================================
# P113-Step6A-Fix.ps1  -  Part P-113, STEP 6A FIX: remove the duplicate notification override in app_router_test.dart
#
# Run from the ROOT of the cavallo-mobile repo (the folder that has pubspec.yaml),
# on branch part-111, in Windows PowerShell:
#     powershell -ExecutionPolicy Bypass -File .\P113-Step6A-Fix.ps1
#
# What it does
#   PATCH   test/routing/app_router_test.dart  (remove the default notificationRepositoryProvider override)
#   RUN     flutter analyze
#
# Safe to run twice: files with identical content are skipped, patches that are
# already applied are skipped, and a patch whose anchor text is not found
# exactly once STOPS the script before writing anything for that file.
# =============================================================================
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$pubspec = Join-Path $root 'pubspec.yaml'
if (-not (Test-Path -LiteralPath $pubspec)) { throw 'Run this script from the cavallo-mobile repo root (pubspec.yaml not found).' }
if (-not (Select-String -Path $pubspec -Pattern 'name:\s*social_commerce_app' -Quiet)) { throw 'pubspec.yaml is not the social_commerce_app project.' }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Convert-Eol([string]$text, [string]$eol) {
    $t = $text -replace "`r`n", "`n"
    if ($eol -eq "`r`n") { $t = $t -replace "`n", "`r`n" }
    return $t
}

function Write-NewFile([string]$rel, [string]$content) {
    $path = Join-Path $root ($rel -replace '/', '\')
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $text = (Convert-Eol $content "`n") + "`n"
    if (Test-Path -LiteralPath $path) {
        $existing = [System.IO.File]::ReadAllText($path)
        if ((Convert-Eol $existing "`n") -eq $text) { Write-Host "SKIP (same)   $rel"; return }
        Write-Host "OVERWRITE     $rel"
    } else {
        Write-Host "CREATE        $rel"
    }
    [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
}

function Update-File([string]$rel, [string]$anchor, [string]$replacement) {
    $path = Join-Path $root ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path)) { throw "File not found: $rel" }
    $raw = [System.IO.File]::ReadAllText($path)
    $eol = "`n"
    if ($raw.Contains("`r`n")) { $eol = "`r`n" }
    $a = Convert-Eol $anchor $eol
    $r = Convert-Eol $replacement $eol
    if ($raw.Contains($r)) { Write-Host "SKIP (done)   $rel"; return }
    $count = ([regex]::Matches($raw, [regex]::Escape($a))).Count
    if ($count -ne 1) { throw "Anchor found $count times (expected 1) in $rel. Anchor starts with: $($a.Substring(0, [Math]::Min(60, $a.Length)))" }
    $new = $raw.Replace($a, $r)
    [System.IO.File]::WriteAllText($path, $new, $utf8NoBom)
    Write-Host "PATCH         $rel"
}

Write-Host '== Creating new files =='

Write-Host '== Patching existing files =='
$a = @'
      // Part P-113 (STEP 5): Home now shows unread badges. Default fakes keep
      // every router test off the network; a test's own extraOverrides come
      // after these and win.
      notificationRepositoryProvider.overrideWithValue(
        FakeNotificationRepository(pages: {null: fakePage([])}),
      ),
'@
$r = @'
      // Part P-113 (STEP 5): Home now shows unread badges. Default fakes keep
      // router tests off the network for chat and stories. There is
      // deliberately NO default for notificationRepositoryProvider: Riverpod
      // refuses two overrides of one provider in a container, and several
      // tests pass their own through extraOverrides.
'@
Update-File 'test/routing/app_router_test.dart' $a $r

Write-Host '== flutter analyze =='
flutter analyze
if ($LASTEXITCODE -ne 0) { Write-Host 'flutter analyze reported issues - send me the output.' -ForegroundColor Yellow } else { Write-Host 'flutter analyze: clean.' -ForegroundColor Green }

Write-Host ''
Write-Host 'Done. Now re-run the tests (see my message).' -ForegroundColor Cyan