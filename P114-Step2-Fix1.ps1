<#
  P114-Step2-Fix1.ps1
  Fixes the one failing test of STEP 2: "FeedSkeletonList honours the count".
  Cause: the test surface was 400x800, and a ListView only builds the items near
  the screen, so with count: 3 only 2 skeletons were built. The app code is fine;
  only the test surface is made taller (400x3000).

  Run from the repo root:  powershell -ExecutionPolicy Bypass -File .\P114-Step2-Fix1.ps1
#>
$ErrorActionPreference = 'Stop'
$Rel = 'test\features\feed\presentation\feed_skeleton_test.dart'
$full = Join-Path (Get-Location).Path ($Rel -replace '[\\/]', [string][System.IO.Path]::DirectorySeparatorChar)
if (-not (Test-Path $full)) { Write-Host "ERROR: $Rel not found. Run from the repo root." -ForegroundColor Red; exit 1 }
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$text = [System.IO.File]::ReadAllText($full) -replace "`r`n", "`n"
$old = '  tester.view.physicalSize = const Size(400, 800);'
$new = "  // Tall on purpose: a ListView only builds the items near the screen.`n  tester.view.physicalSize = const Size(400, 3000);"
if ($text.Contains('Size(400, 3000)')) { Write-Host "  SKIPPED  $Rel (already fixed)"; exit 0 }
$pos = $text.IndexOf($old)
if ($pos -lt 0) { Write-Host "ERROR: expected line not found in $Rel. Send me the file." -ForegroundColor Red; exit 1 }
$text = $text.Substring(0, $pos) + $new + $text.Substring($pos + $old.Length)
[System.IO.File]::WriteAllText($full, ($text -replace "`r?`n", "`r`n"), $Utf8NoBom)
Write-Host "  PATCHED  $Rel" -ForegroundColor Green