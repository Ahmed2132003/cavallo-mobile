<#
  P114-Step2-Fix2.ps1
  Fixes the one failing test of the full suite:
    test/core/theme/status_tokens_test.dart  "no palette colours or hex literals outside core/theme"
  Cause: STEP 2 wrote the white used over media as Color(0xFFFFFFFF) in two files.
  The project rule only allows Colors.white / Colors.black there, so both lines
  now use Colors.white (the same colour, no behavior change).

  Run from the repo root:  powershell -ExecutionPolicy Bypass -File .\P114-Step2-Fix2.ps1
#>
$ErrorActionPreference = 'Stop'
$Root = (Get-Location).Path
$Sep = [string][System.IO.Path]::DirectorySeparatorChar
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Patch-Line([string]$Rel, [string]$Old, [string]$New) {
  $full = Join-Path $Root ($Rel -replace '[\\/]', $Sep)
  if (-not (Test-Path $full)) { Write-Host "ERROR: $Rel not found. Run from the repo root." -ForegroundColor Red; exit 1 }
  $text = [System.IO.File]::ReadAllText($full) -replace "`r`n", "`n"
  if ($text.Contains($New)) { Write-Host "  SKIPPED  $Rel (already fixed)"; return }
  $pos = $text.IndexOf($Old)
  if ($pos -lt 0) { Write-Host "ERROR: expected line not found in $Rel. Send me the file." -ForegroundColor Red; exit 1 }
  $text = $text.Substring(0, $pos) + $New + $text.Substring($pos + $Old.Length)
  [System.IO.File]::WriteAllText($full, ($text -replace "`r?`n", "`r`n"), $Utf8NoBom)
  Write-Host "  PATCHED  $Rel" -ForegroundColor Green
}

Patch-Line 'lib\features\content\presentation\reel_card.dart' 'const Color _reelOnMedia = Color(0xFFFFFFFF);' 'const Color _reelOnMedia = Colors.white;'
Patch-Line 'lib\features\social\presentation\content_action_row.dart' 'const Color _overlayOnMedia = Color(0xFFFFFFFF);' 'const Color _overlayOnMedia = Colors.white;'