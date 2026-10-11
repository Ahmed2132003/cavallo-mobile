<#
.SYNOPSIS
  Cavallo - refresh the 28 golden baselines that went stale after the logo
  AppBar (CavalloAppBar) and the new-chat button. Run it from anywhere.
  ASCII-only script.

.DESCRIPTION
  Why the 28 golden tests failed: the baselines (52 PNGs) were generated on
  2026-10-10. Afterwards AppBar became CavalloAppBar (logo added) on about 35
  screens and chat_list_screen got the new "New chat" button. The failing
  goldens are exactly the ones that contain a Scaffold + AppBar:
    p114/business_profile_header_*   (4)
    p114/product_detail_header_*     (4)
    p115_chat/chat_list_*            (4)
    p115_chat/chat_thread_*          (4)
    p115_chat/chat_thread_typing_*   (4)
    p115_screens/notification_center_* (4)
    p115_screens/moderation_queue_*  (4)
  The chat video fix is NOT the cause. No lib/ file is touched by this script.

  What it does (in order):
    1. Validates everything first (project folder, git, flutter, the 28
       baselines exist, test/goldens has no uncommitted changes).
    2. Copies the 28 old PNGs to a backup folder under %TEMP% (git also has them).
    3. Appends "*.bak_*" to .gitignore (script backups must not be committed).
    4. Runs: flutter test --update-goldens on the 3 golden test files.
    5. Checks git: only the 28 expected PNGs may change. Any other golden that
       changed (it was passing, so it must stay as it was) is restored
       automatically. A new/unknown file stops the script.
    6. Re-runs test/goldens WITHOUT --update-goldens: it must pass.

  Safe to re-run. -DryRun validates and prints the plan, writes nothing.
#>
[CmdletBinding()]
param(
    [string]$FlutterRoot = 'D:\Cavallo\social_commerce_app',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$GoldenTests = @(
    'test/goldens/p114_goldens_test.dart',
    'test/goldens/p115_chat_goldens_test.dart',
    'test/goldens/p115_screens_goldens_test.dart'
)

# The 28 baselines that are stale. p114 names are <locale>_<theme>,
# p115 names are <theme>_<locale> (that is how the tests name them).
$Expected = New-Object System.Collections.Generic.List[string]
foreach ($shot in @('business_profile_header', 'product_detail_header')) {
    foreach ($loc in @('en', 'ar')) {
        foreach ($theme in @('light', 'dark')) {
            $Expected.Add("test/goldens/p114/${shot}_${loc}_${theme}.png")
        }
    }
}
foreach ($shot in @('chat_list', 'chat_thread', 'chat_thread_typing')) {
    foreach ($theme in @('light', 'dark')) {
        foreach ($loc in @('en', 'ar')) {
            $Expected.Add("test/goldens/p115_chat/${shot}_${theme}_${loc}.png")
        }
    }
}
foreach ($shot in @('notification_center', 'moderation_queue')) {
    foreach ($theme in @('light', 'dark')) {
        foreach ($loc in @('en', 'ar')) {
            $Expected.Add("test/goldens/p115_screens/${shot}_${theme}_${loc}.png")
        }
    }
}

$GitIgnoreMarker = '*.bak_*'
$GitIgnoreAddition = "# Script backups (*.bak_chatvideo, *.bak_newchat, ...) must never be committed`r`n*.bak_*`r`n"

function Invoke-Git {
    param([string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git @GitArgs 2>$null
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    return [pscustomobject]@{ Out = @($out); Code = $code }
}

# ---------------------------------------------------------------------------
# Phase 1: validate (nothing is written here)
# ---------------------------------------------------------------------------
$problems = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath (Join-Path $FlutterRoot 'pubspec.yaml'))) {
    throw "pubspec.yaml not found in $FlutterRoot - pass -FlutterRoot with the Flutter project folder."
}

Push-Location $FlutterRoot
try {
    $inside = Invoke-Git @('rev-parse', '--is-inside-work-tree')
    if ($inside.Code -ne 0) {
        [void]$problems.Add('This folder is not a git repository (git is needed to verify the changed PNGs).')
    } else {
        $branch = Invoke-Git @('rev-parse', '--abbrev-ref', 'HEAD')
        Write-Host ("Branch: " + ($branch.Out -join '')) -ForegroundColor Cyan

        $dirty = Invoke-Git @('status', '--porcelain', '--', 'test/goldens')
        if ($dirty.Out.Count -gt 0) {
            [void]$problems.Add('test/goldens has uncommitted changes. Commit or revert them first (git checkout -- test/goldens):')
            foreach ($d in $dirty.Out) { [void]$problems.Add("    $d") }
        }
    }

    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        [void]$problems.Add('flutter was not found on PATH.')
    }

    foreach ($t in $GoldenTests) {
        if (-not (Test-Path -LiteralPath (Join-Path $FlutterRoot $t))) {
            [void]$problems.Add("Missing golden test file: $t")
        }
    }
    foreach ($png in $Expected) {
        if (-not (Test-Path -LiteralPath (Join-Path $FlutterRoot $png))) {
            [void]$problems.Add("Missing baseline PNG: $png")
        }
    }

    $giPath = Join-Path $FlutterRoot '.gitignore'
    $giState = 'append'
    if (Test-Path -LiteralPath $giPath) {
        $giText = [System.IO.File]::ReadAllText($giPath)
        if ($giText -match '(?m)^\*\.bak_\*\s*$') { $giState = 'already' }
    } else {
        $giState = 'create'
    }

    if ($problems.Count -gt 0) {
        Write-Host ''
        Write-Host 'NOTHING WAS CHANGED. Fix these first:' -ForegroundColor Red
        foreach ($p in $problems) { Write-Host "  - $p" -ForegroundColor Red }
        throw 'Validation failed.'
    }

    Write-Host ''
    Write-Host "Validation OK: $($Expected.Count) baselines to refresh, 3 golden test files, .gitignore: $giState." -ForegroundColor Green

    if ($DryRun) {
        Write-Host 'DryRun: nothing written, flutter not run.' -ForegroundColor Yellow
        return
    }

    # -----------------------------------------------------------------------
    # Phase 2: backup, .gitignore, regenerate
    # -----------------------------------------------------------------------
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bakRoot = Join-Path $env:TEMP "cavallo_goldens_bak_$stamp"
    foreach ($png in $Expected) {
        $src = Join-Path $FlutterRoot $png
        $dst = Join-Path $bakRoot ($png.Replace('/', '\'))
        $dstDir = Split-Path -Parent $dst
        if (-not (Test-Path -LiteralPath $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
        Copy-Item -LiteralPath $src -Destination $dst
    }
    Write-Host "  backup   $($Expected.Count) old PNGs -> $bakRoot"

    if ($giState -ne 'already') {
        $existing = ''
        if (Test-Path -LiteralPath $giPath) { $existing = [System.IO.File]::ReadAllText($giPath) }
        $prefix = ''
        if ($existing.Length -gt 0 -and -not $existing.EndsWith("`n")) { $prefix = "`r`n" }
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::AppendAllText($giPath, $prefix + $GitIgnoreAddition, $enc)
        Write-Host '  edited   .gitignore (appended *.bak_*)'
    } else {
        Write-Host '  same     .gitignore'
    }

    Write-Host ''
    Write-Host 'Regenerating baselines (flutter test --update-goldens, a few minutes)...' -ForegroundColor Cyan
    & flutter test --update-goldens $GoldenTests
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host 'flutter test --update-goldens failed. To undo: git checkout -- test/goldens' -ForegroundColor Red
        throw 'Golden update failed.'
    }

    # -----------------------------------------------------------------------
    # Phase 3: only the 28 expected PNGs may differ
    # -----------------------------------------------------------------------
    $status = Invoke-Git @('status', '--porcelain', '--', 'test/goldens')
    $changed = New-Object System.Collections.Generic.List[string]
    $restored = New-Object System.Collections.Generic.List[string]
    $unknown = New-Object System.Collections.Generic.List[string]

    foreach ($line in $status.Out) {
        if ($line.Length -lt 4) { continue }
        $code = $line.Substring(0, 2)
        $path = $line.Substring(3).Trim('"')
        if ($code -eq '??') {
            [void]$unknown.Add($path)
        } elseif ($Expected -contains $path) {
            [void]$changed.Add($path)
        } else {
            # It was passing before, so its pixels did not change: keep it as it was.
            $r = Invoke-Git @('checkout', '--', $path)
            if ($r.Code -eq 0) { [void]$restored.Add($path) } else { [void]$unknown.Add($path) }
        }
    }

    if ($unknown.Count -gt 0) {
        Write-Host ''
        Write-Host 'Unexpected files appeared in test/goldens:' -ForegroundColor Red
        foreach ($u in $unknown) { Write-Host "  - $u" -ForegroundColor Red }
        Write-Host 'To undo everything: git checkout -- test/goldens ; git clean -fd test/goldens' -ForegroundColor Yellow
        throw 'Unexpected golden changes.'
    }

    foreach ($c in $changed) { Write-Host "  updated  $c" }
    foreach ($r in $restored) { Write-Host "  restored $r (was passing, kept as it was)" -ForegroundColor DarkYellow }
    foreach ($png in $Expected) {
        if (-not ($changed -contains $png)) {
            Write-Host "  WARNING  $png did not change (it already matched on this machine)" -ForegroundColor Yellow
        }
    }
    Write-Host ''
    Write-Host "$($changed.Count) of $($Expected.Count) baselines updated." -ForegroundColor Green

    # -----------------------------------------------------------------------
    # Phase 4: the goldens must now pass without --update-goldens
    # -----------------------------------------------------------------------
    Write-Host ''
    Write-Host 'Verifying: flutter test test/goldens (no update)...' -ForegroundColor Cyan
    & flutter test test/goldens
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host 'Goldens still fail after regenerating. To undo: git checkout -- test/goldens' -ForegroundColor Red
        throw 'Golden verification failed.'
    }

    $tracked = Invoke-Git @('ls-files', '*.bak_*')

    Write-Host ''
    Write-Host 'DONE. Next steps:' -ForegroundColor Green
    Write-Host "  cd $FlutterRoot"
    Write-Host '  (look at 2-3 new images, e.g. test/goldens/p115_chat/chat_list_light_en.png: logo in the app bar + "New chat" button)'
    Write-Host '  flutter test --concurrency=2'
    Write-Host '  git add test/goldens .gitignore'
    Write-Host '  git commit -m "refresh golden baselines (logo app bar, new chat button)"'
    Write-Host "  Backup of the old PNGs: $bakRoot"
    if ($tracked.Out.Count -gt 0) {
        Write-Host ''
        Write-Host "Note: $($tracked.Out.Count) *.bak_* files are already tracked by git (.gitignore does not untrack them)." -ForegroundColor Yellow
        Write-Host "  Optional: git ls-files '*.bak_*' | ForEach-Object { git rm --cached `$_ }" -ForegroundColor Yellow
    }
} finally {
    Pop-Location
}