# =============================================================================
# P113-ProveReachabilityFails.ps1 - proves the reachability test CAN fail.
# Run from the cavallo-mobile repo root. It temporarily breaks the navigation
# manifest (points the productList entry at a route that does not exist),
# runs the reachability test (it MUST fail), then ALWAYS restores the file.
# =============================================================================
$ErrorActionPreference = 'Stop'
$file = Join-Path (Get-Location).Path 'lib\routing\navigation_manifest.dart'
if (-not (Test-Path -LiteralPath $file)) { throw 'Run from the cavallo-mobile repo root.' }
$backup = "$file.bak-prove"
Copy-Item -LiteralPath $file -Destination $backup -Force
try {
    $raw = [System.IO.File]::ReadAllText($file)
    $needle = 'routeName: RouteNames.productList,'
    $idx = $raw.IndexOf($needle)
    if ($idx -lt 0 -or $raw.IndexOf($needle, $idx + 1) -ge 0) { throw 'Mutation target not found exactly once.' }
    $broken = $raw.Replace($needle, "routeName: 'ghostRoute',")
    [System.IO.File]::WriteAllText($file, $broken, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host '== Running the reachability test on a BROKEN manifest (it must FAIL) ==' -ForegroundColor Yellow
    flutter test test\routing\navigation_reachability_test.dart
    $code = $LASTEXITCODE
    if ($code -eq 0) { Write-Host 'PROBLEM: the test PASSED on a broken manifest. Do not close P-113.' -ForegroundColor Red }
    else { Write-Host 'GOOD: the test FAILED on the broken manifest, as it should.' -ForegroundColor Green }
}
finally {
    Move-Item -LiteralPath $backup -Destination $file -Force
    Write-Host 'Manifest restored.' -ForegroundColor Cyan
}
Write-Host '== Running the reachability test on the RESTORED manifest (it must PASS) ==' -ForegroundColor Yellow
flutter test test\routing\navigation_reachability_test.dart