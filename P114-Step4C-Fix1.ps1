<#
  P114-Step4C-Fix1.ps1
  Fixes test\goldens\p114_goldens_test.dart: 'Override' is not exported by the pinned
  flutter_riverpod, so the helper takes List<dynamic> (same trick as test\routing\app_router_test.dart).
  Run from the cavallo-mobile repo root:
      powershell -ExecutionPolicy Bypass -File .\P114-Step4C-Fix1.ps1
#>
$ErrorActionPreference = 'Stop'
$path = Join-Path (Get-Location).Path 'test\goldens\p114_goldens_test.dart'
if (-not (Test-Path $path)) { Write-Host 'ERROR: run from the repo root after P114-Step4C.ps1' -ForegroundColor Red; exit 1 }
$text = [System.IO.File]::ReadAllText($path)
$a = 'List<Override> overrides = const []'
$b = 'List<dynamic> overrides = const []'
$c = 'overrides: overrides,'
$d = 'overrides: [...overrides],'
if ($text.Contains($a)) { $text = $text.Replace($a, $b) } elseif (-not $text.Contains($b)) { Write-Host 'ERROR: signature not found' -ForegroundColor Red; exit 1 }
if ($text.Contains($c)) { $text = $text.Replace($c, $d) } elseif (-not $text.Contains($d)) { Write-Host 'ERROR: ProviderScope line not found' -ForegroundColor Red; exit 1 }
[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Host 'Patched. Generating goldens...'
& flutter test --update-goldens test\goldens
if ($LASTEXITCODE -ne 0) { Write-Host 'ERROR: update-goldens failed. Send me the output.' -ForegroundColor Red; exit 1 }
$n = @(Get-ChildItem -Path 'test\goldens\p114' -Filter '*.png' -ErrorAction SilentlyContinue).Count
Write-Host "PNG files: $n (expected 28)"
& flutter test test\goldens
if ($LASTEXITCODE -ne 0) { Write-Host 'ERROR: comparison failed. Send me the output.' -ForegroundColor Red; exit 1 }
Write-Host 'STEP 4C fix applied.' -ForegroundColor Green