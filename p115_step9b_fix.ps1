# p115_step9b_fix.ps1 -- run as a FILE from D:\Cavallo\social_commerce_app
$root = (Get-Location).Path
if (-not (Test-Path "$root\pubspec.yaml")) { throw 'Run from the repo root.' }
$stamp    = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup   = Join-Path $env:TEMP "p115_step9b_fix_$stamp"
$evidence = Join-Path $root 'p115_step9b_evidence_v2.txt'
New-Item -ItemType Directory -Path $backup | Out-Null
$transcribing = $false
try { Start-Transcript -Path $evidence -Force | Out-Null; $transcribing = $true }
catch { Write-Host "Transcript unavailable (continuing): $_" -ForegroundColor Yellow }
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Run-Native([scriptblock]$cmd) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  $out = & $cmd 2>&1 | Out-String
  $code = $LASTEXITCODE
  $ErrorActionPreference = $old
  return [pscustomobject]@{ Out = $out; Code = $code }
}
# NOTE: 'R' is a built-in alias of Invoke-History, so we use New-Rep
function New-Rep([string]$Lit, [string]$Key, [int]$Count) { [pscustomobject]@{ Lit = $Lit; Key = $Key; Count = $Count } }

$keys = [ordered]@{
  validationBusinessNameRequired = @('Business name is required.', '\u0627\u0633\u0645 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a \u0645\u0637\u0644\u0648\u0628.')
  validationCountryRequired      = @('Country is required.', '\u0627\u0644\u062f\u0648\u0644\u0629 \u0645\u0637\u0644\u0648\u0628\u0629.')
  validationCityRequired         = @('City is required.', '\u0627\u0644\u0645\u062f\u064a\u0646\u0629 \u0645\u0637\u0644\u0648\u0628\u0629.')
  businessProfileLoadError       = @('Could not load your business profile.', '\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0645\u0644\u0641 \u0646\u0634\u0627\u0637\u0643 \u0627\u0644\u062a\u062c\u0627\u0631\u064a.')
  postLoadError                  = @('Could not load this post.', '\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0647\u0630\u0627 \u0627\u0644\u0645\u0646\u0634\u0648\u0631.')
  reelLoadError                  = @('Could not load this reel.', '\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0647\u0630\u0627 \u0627\u0644\u0631\u064a\u0644.')
  commonGenericError             = @('Something went wrong. Please try again.', '\u062d\u062f\u062b \u062e\u0637\u0623 \u0645\u0627. \u064a\u064f\u0631\u062c\u0649 \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.')
  validationCaptionRequired      = @('Caption is required.', '\u0627\u0644\u0646\u0635 \u0627\u0644\u062a\u0648\u0636\u064a\u062d\u064a \u0645\u0637\u0644\u0648\u0628.')
  reelVideoRequired              = @('A video is required.', '\u0627\u0644\u0641\u064a\u062f\u064a\u0648 \u0645\u0637\u0644\u0648\u0628.')
  productFormEditTitle           = @('Edit product', '\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0646\u062a\u062c')
  productFormCreate              = @('Create product', '\u0625\u0646\u0634\u0627\u0621 \u0645\u0646\u062a\u062c')
  productFormSaveChanges         = @('Save changes', '\u062d\u0641\u0638 \u0627\u0644\u062a\u063a\u064a\u064a\u0631\u0627\u062a')
  validationProductNameRequired  = @('Name is required.', '\u0627\u0644\u0627\u0633\u0645 \u0645\u0637\u0644\u0648\u0628.')
  validationDescriptionRequired  = @('Description is required.', '\u0627\u0644\u0648\u0635\u0641 \u0645\u0637\u0644\u0648\u0628.')
  validationPriceRequired        = @('Price is required.', '\u0627\u0644\u0633\u0639\u0631 \u0645\u0637\u0644\u0648\u0628.')
  validationPriceInvalid         = @('Enter a valid price (e.g. 199.99).', '\u0623\u062f\u062e\u0644 \u0633\u0639\u0631\u064b\u0627 \u0635\u062d\u064a\u062d\u064b\u0627 (\u0645\u062b\u0627\u0644: 199.99).')
}

$plan = @(
  [pscustomobject]@{ File='lib\features\business_profile\presentation\business_onboarding_screen.dart'; Reps=@(
      (New-Rep "'Business name is required.'" 'validationBusinessNameRequired' 1),
      (New-Rep "'Country is required.'" 'validationCountryRequired' 1),
      (New-Rep "'City is required.'" 'validationCityRequired' 1)) },
  [pscustomobject]@{ File='lib\features\business_profile\presentation\business_profile_edit_screen.dart'; Reps=@(
      (New-Rep "'Could not load your business profile.'" 'businessProfileLoadError' 1),
      (New-Rep "'Business name is required.'" 'validationBusinessNameRequired' 1),
      (New-Rep "'Country is required.'" 'validationCountryRequired' 1),
      (New-Rep "'City is required.'" 'validationCityRequired' 1)) },
  [pscustomobject]@{ File='lib\features\content\presentation\post_detail_screen.dart'; Reps=@(
      (New-Rep "'Could not load this post.'" 'postLoadError' 1)) },
  [pscustomobject]@{ File='lib\features\content\presentation\reel_detail_screen.dart'; Reps=@(
      (New-Rep "'Could not load this reel.'" 'reelLoadError' 1)) },
  [pscustomobject]@{ File='lib\features\content\presentation\post_form_screen.dart'; Reps=@(
      (New-Rep "'Something went wrong. Please try again.'" 'commonGenericError' 1),
      (New-Rep "'Caption is required.'" 'validationCaptionRequired' 1)) },
  [pscustomobject]@{ File='lib\features\content\presentation\reel_form_screen.dart'; Reps=@(
      (New-Rep "'A video is required.'" 'reelVideoRequired' 1),
      (New-Rep "'Something went wrong. Please try again.'" 'commonGenericError' 1),
      (New-Rep "'Caption is required.'" 'validationCaptionRequired' 1)) },
  [pscustomobject]@{ File='lib\features\products\presentation\product_form_screen.dart'; Reps=@(
      (New-Rep "'Something went wrong. Please try again.'" 'commonGenericError' 1),
      (New-Rep "'Edit product'" 'productFormEditTitle' 1),
      (New-Rep "'Create product'" 'productFormCreate' 2),
      (New-Rep "'Save changes'" 'productFormSaveChanges' 1),
      (New-Rep "'Name is required.'" 'validationProductNameRequired' 1),
      (New-Rep "'Description is required.'" 'validationDescriptionRequired' 1),
      (New-Rep "'Price is required.'" 'validationPriceRequired' 1),
      (New-Rep "'Enter a valid price (e.g. 199.99).'" 'validationPriceInvalid' 1)) }
)

try {
  # ---- sanity: the plan itself must not be empty/broken ----
  $total = 0
  foreach ($p in $plan) {
    if (-not $p.Reps -or @($p.Reps).Count -eq 0) { throw "Empty Reps for $($p.File)" }
    foreach ($r in $p.Reps) {
      if (-not $r.Lit -or $r.Lit.Length -lt 4 -or -not $r.Key) { throw "Broken rep in $($p.File)" }
      $total += $r.Count
    }
  }
  if ($total -ne 23) { throw "Plan total is $total, expected 23" }
  Write-Host "PLAN OK (8->7 files, $total replacements)" -ForegroundColor Green

  $en = Get-ChildItem $root -Recurse -Filter app_en.arb | Where-Object { $_.FullName -notmatch '\\(build|\.dart_tool)\\' } | Select-Object -First 1
  if (-not $en) { throw 'app_en.arb not found' }
  $arPath = Join-Path $en.DirectoryName 'app_ar.arb'
  if (-not (Test-Path $arPath)) { throw "app_ar.arb not found" }
  $enRaw = [IO.File]::ReadAllText($en.FullName, [Text.Encoding]::UTF8)
  $arRaw = [IO.File]::ReadAllText($arPath, [Text.Encoding]::UTF8)

  # ---- ARB state per key: both present = skip, both missing = add, mixed = stop ----
  $missing = @()
  foreach ($k in $keys.Keys) {
    $inEn = $enRaw -match ('"' + $k + '"\s*:')
    $inAr = $arRaw -match ('"' + $k + '"\s*:')
    if ($inEn -and $inAr) { continue }
    if (-not $inEn -and -not $inAr) { $missing += $k; continue }
    throw "ARB parity problem for key $k (en=$inEn ar=$inAr)"
  }
  Write-Host "ARB keys already present: $($keys.Count - $missing.Count) | to add: $($missing.Count)"

  # ---- per-file state: literal count must equal expected (todo) or be 0 with key used (done) ----
  foreach ($p in $plan) {
    $full = Join-Path $root $p.File
    if (-not (Test-Path $full)) { throw "Missing file: $($p.File)" }
    $t = [IO.File]::ReadAllText($full, [Text.Encoding]::UTF8)
    if ($t -notmatch 'l10n') { throw "File does not use l10n yet: $($p.File)" }
    foreach ($r in $p.Reps) {
      $c = [regex]::Matches($t, [regex]::Escape($r.Lit)).Count
      $done = [regex]::Matches($t, [regex]::Escape('context.l10n.' + $r.Key)).Count
      if ($c -ne $r.Count -and -not ($c -eq 0 -and $done -ge $r.Count)) {
        throw "$($p.File): $($r.Lit) found $c (expected $($r.Count)), key used $done"
      }
    }
  }
  Write-Host 'PRE-CHECKS OK' -ForegroundColor Green

  # ---- backups ----
  Copy-Item $en.FullName (Join-Path $backup 'app_en.arb')
  Copy-Item $arPath      (Join-Path $backup 'app_ar.arb')
  foreach ($p in $plan) { Copy-Item (Join-Path $root $p.File) (Join-Path $backup ($p.File -replace '[\\:]','_')) }

  # ---- add only missing ARB keys ----
  function Add-ArbKeys([string]$path, [string]$raw, [int]$idx) {
    $nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
    $body = $raw.TrimEnd()
    if (-not $body.EndsWith('}')) { throw "ARB does not end with }: $path" }
    $body = $body.Substring(0, $body.Length - 1).TrimEnd()
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append($body)
    foreach ($k in $missing) { [void]$sb.Append(',' + $nl + '  "' + $k + '": "' + $keys[$k][$idx] + '"') }
    [void]$sb.Append($nl + '}' + $nl)
    [IO.File]::WriteAllText($path, $sb.ToString(), $utf8)
  }
  if ($missing.Count -gt 0) {
    Add-ArbKeys $en.FullName $enRaw 0
    Add-ArbKeys $arPath      $arRaw 1
  }
  $g = Run-Native { flutter gen-l10n }
  if ($g.Code -ne 0) {
    Copy-Item (Join-Path $backup 'app_en.arb') $en.FullName -Force
    Copy-Item (Join-Path $backup 'app_ar.arb') $arPath -Force
    Write-Host $g.Out
    throw 'gen-l10n failed; ARBs restored'
  }
  Write-Host 'gen-l10n OK' -ForegroundColor Green

  # ---- apply, analyze, revert on error ----
  $failed = @(); $changed = @(); $applied = 0
  foreach ($p in $plan) {
    $full = Join-Path $root $p.File
    $t = [IO.File]::ReadAllText($full, [Text.Encoding]::UTF8)
    $orig = $t
    foreach ($r in $p.Reps) {
      $c = [regex]::Matches($t, [regex]::Escape($r.Lit)).Count
      if ($c -gt 0) { $t = $t.Replace($r.Lit, 'context.l10n.' + $r.Key); $applied += $c }
    }
    if ($t -eq $orig) { Write-Host "SKIP (already done): $($p.File)"; continue }
    [IO.File]::WriteAllText($full, $t, $utf8)
    $rel = $p.File
    $a = Run-Native { flutter analyze --no-pub $rel }
    if ($a.Out -match '(?m)^\s*error\s') {
      Copy-Item (Join-Path $backup ($p.File -replace '[\\:]','_')) $full -Force
      $failed += $p.File
      Write-Host "REVERTED (analyze error): $($p.File)" -ForegroundColor Yellow
      Write-Host $a.Out
    } else {
      $changed += $p.File
      Write-Host "OK: $($p.File)" -ForegroundColor Green
    }
  }

  # ---- format ONLY the files we touched ----
  if ($changed.Count -gt 0) { Run-Native { dart format @changed } | Out-Null }

  # ---- post-check: leftover literals ----
  Write-Host '--- leftover literals (should be none) ---'
  foreach ($p in $plan) {
    $t = [IO.File]::ReadAllText((Join-Path $root $p.File), [Text.Encoding]::UTF8)
    foreach ($r in $p.Reps) {
      $c = [regex]::Matches($t, [regex]::Escape($r.Lit)).Count
      if ($c -gt 0) { Write-Host "LEFT: $($p.File) :: $($r.Lit) x$c" -ForegroundColor Red }
    }
  }

  $dirs = @('test/l10n','test/routing','test/features/business_profile','test/features/content','test/features/products','test/features/social') | Where-Object { Test-Path (Join-Path $root $_) }
  $tr = Run-Native { flutter test @dirs }
  Write-Host ($tr.Out -split "`n" | Select-Object -Last 15 | Out-String)
  Write-Host "Replacements applied this run: $applied"
  Write-Host "flutter test exit code: $($tr.Code)"
  Write-Host "Reverted files: $($failed.Count)"; $failed | ForEach-Object { Write-Host "  $_" }
  Write-Host "Backup: $backup"
}
catch { Write-Host "STOPPED: $_" -ForegroundColor Red; Write-Host "Backup: $backup" }
finally { if ($transcribing) { Stop-Transcript | Out-Null } }