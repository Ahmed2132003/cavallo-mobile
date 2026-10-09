# p115_step9a_guard_baseline.ps1
# STEP 9a - READ-ONLY. Runs the three guard tests, flutter analyze, and inventories
# user-visible strings the guard test cannot see. Modifies NO existing file.
# Run from the repo root:  D:\Cavallo\social_commerce_app
#   powershell -ExecutionPolicy Bypass -File .\p115_step9a_guard_baseline.ps1

$ErrorActionPreference = 'Continue'

if (-not (Test-Path '.\pubspec.yaml') -or -not (Test-Path '.\lib')) {
    Write-Host 'STOP: run this from the Flutter project root (pubspec.yaml and lib\ not found).' -ForegroundColor Red
    exit 1
}

$ev  = Join-Path (Get-Location) 'p115_step9a_evidence.txt'
$inv = Join-Path (Get-Location) 'p115_step9a_inventory.txt'
"P-115 STEP 9a evidence - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $ev -Encoding utf8
"P-115 STEP 9a inventory - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $inv -Encoding utf8

function Add-Ev([string]$text) { $text | Out-File $ev -Append -Encoding utf8 }

function Run-Step([string]$title, [scriptblock]$cmd) {
    Write-Host ""
    Write-Host "=== $title ===" -ForegroundColor Cyan
    Add-Ev ""
    Add-Ev "=== $title ==="
    & $cmd 2>&1 | Tee-Object -FilePath $ev -Append
    $code = $LASTEXITCODE
    Add-Ev "EXIT CODE: $code"
    Write-Host "EXIT CODE: $code"
    return $code
}

# ---------- 1. git state ----------
Add-Ev '=== GIT STATE ==='
Add-Ev ("branch: " + (git rev-parse --abbrev-ref HEAD 2>&1))
Add-Ev 'last commits:'
git log --oneline -n 8 2>&1 | ForEach-Object { Add-Ev "  $_" }
Add-Ev 'git status --short:'
git status --short 2>&1 | ForEach-Object { Add-Ev "  $_" }
Add-Ev 'flutter version line:'
Add-Ev ((flutter --version 2>&1 | Select-Object -First 1) | Out-String)

# ---------- 2. STEP 3 gap check ----------
Add-Ev ''
Add-Ev '=== STEP 3 CHECK (chat thread files: l10n usage count) ==='
$chatFiles = @(
    'lib\features\chat\presentation\chat_thread_screen.dart',
    'lib\features\chat\presentation\message_bubble_widget.dart',
    'lib\features\chat\presentation\shared_content_card.dart',
    'lib\features\chat\presentation\share_to_conversation_sheet.dart'
)
foreach ($f in $chatFiles) {
    if (Test-Path $f) {
        $n = (Select-String -Path $f -Pattern 'l10n' -SimpleMatch | Measure-Object).Count
        Add-Ev "  $f : l10n references = $n"
    } else {
        $alt = Get-ChildItem lib -Recurse -Filter (Split-Path $f -Leaf) -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($alt) {
            $n = (Select-String -Path $alt.FullName -Pattern 'l10n' -SimpleMatch | Measure-Object).Count
            Add-Ev "  $($alt.FullName) : l10n references = $n (found at a different path)"
        } else {
            Add-Ev "  $f : FILE NOT FOUND"
        }
    }
}

# ---------- 3. flutter analyze + the three guard tests ----------
$results = [ordered]@{}
$results['flutter analyze']          = Run-Step 'flutter analyze' { flutter analyze }
$results['ARB parity']               = Run-Step 'ARB parity test' { flutter test test/l10n/arb_parity_test.dart }
$results['No hardcoded strings']     = Run-Step 'No-hardcoded-strings test' { flutter test test/l10n/no_hardcoded_strings_test.dart }
$results['Navigation reachability']  = Run-Step 'Navigation reachability test' { flutter test test/routing/navigation_reachability_test.dart }

# ---------- 4. _pendingMigration / _allowlist snapshot ----------
Add-Ev ''
Add-Ev '=== GUARD TEST: pending + allowlist snapshot ==='
$guard = 'test\l10n\no_hardcoded_strings_test.dart'
if (Test-Path $guard) {
    Select-String -Path $guard -Pattern '_pendingMigration|_allowlist|\.dart''' |
        ForEach-Object { Add-Ev ("  {0}: {1}" -f $_.LineNumber, $_.Line.Trim()) }
}

# ---------- 5. inventory of strings the guard cannot see ----------
$q  = '[''"]'
$nq = '[^''"]'
$patterns = [ordered]@{
    'validator/return string'      = 'return\s+' + $q + $nq + '*[A-Za-z]{3}'
    'arrow getter string'          = '=>\s*' + $q + '[A-Z]' + $nq + '*[a-z]{2}'
    'named arg with sentence'      = '\b(title|label|subtitle|message|content|description|hint|text|errorMessage|error|body|header|caption)\s*:\s*' + $q + '[A-Z]' + $nq + '*[a-z]{2}'
    'assigned message variable'    = '\b\w*(Message|Error|Label|Title|Text)\w*\s*=\s*' + $q + '[A-Z]' + $nq + '*[a-z]{2}'
    'ternary with sentence'        = '\?\s*' + $q + '[A-Z]' + $nq + '*[a-z]{2}' + $q + '\s*:'
    'TextSpan text'                = 'TextSpan\(\s*text\s*:\s*' + $q
    'Exception/StateError message' = '(Exception|Failure|Error)\(\s*' + $q + '[A-Z]'
}

$skipLine = '^\s*//|^\s*import |^\s*part |Key\(|GoRoute|path\s*:|debugPrint|\blog\(|print\(|Semantics\(identifier|assert\('
$files = Get-ChildItem lib -Recurse -Filter *.dart |
    Where-Object { $_.FullName -notmatch '\\lib\\l10n\\' -and $_.Name -ne 'widget_gallery_demo.dart' }

$hits = New-Object System.Collections.Generic.List[object]
foreach ($kv in $patterns.GetEnumerator()) {
    foreach ($m in ($files | Select-String -Pattern $kv.Value)) {
        if ($m.Line -match $skipLine) { continue }
        $hits.Add([pscustomobject]@{
            Category = $kv.Key
            File     = $m.Path.Replace((Get-Location).Path + '\', '')
            Line     = $m.LineNumber
            Text     = $m.Line.Trim()
        })
    }
}
$hits = $hits | Sort-Object File, Line, Category -Unique

"TOTAL CANDIDATES: $(@($hits).Count)" | Out-File $inv -Append -Encoding utf8
"(candidates only - a human decides which are user-visible; non-UI strings are expected)" | Out-File $inv -Append -Encoding utf8
"" | Out-File $inv -Append -Encoding utf8
"--- COUNT PER FILE ---" | Out-File $inv -Append -Encoding utf8
$hits | Group-Object File | Sort-Object Count -Descending |
    ForEach-Object { "{0,4}  {1}" -f $_.Count, $_.Name } | Out-File $inv -Append -Encoding utf8
"" | Out-File $inv -Append -Encoding utf8
"--- COUNT PER CATEGORY ---" | Out-File $inv -Append -Encoding utf8
$hits | Group-Object Category | ForEach-Object { "{0,4}  {1}" -f $_.Count, $_.Name } | Out-File $inv -Append -Encoding utf8
"" | Out-File $inv -Append -Encoding utf8
"--- FULL LIST ---" | Out-File $inv -Append -Encoding utf8
$hits | ForEach-Object { "{0}:{1} [{2}] {3}" -f $_.File, $_.Line, $_.Category, $_.Text } | Out-File $inv -Append -Encoding utf8

# ---------- 6. Language PATCH check (read-only grep) ----------
Add-Ev ''
Add-Ev '=== LANGUAGE PATCH CHECK (preferred_language usages in lib/) ==='
Get-ChildItem lib -Recurse -Filter *.dart | Select-String -Pattern 'preferred_language|preferredLanguage' |
    ForEach-Object { Add-Ev ("  {0}:{1}: {2}" -f $_.Path.Replace((Get-Location).Path + '\', ''), $_.LineNumber, $_.Line.Trim()) }
Get-ChildItem test -Recurse -Filter *.dart | Select-String -Pattern 'preferred_language|preferredLanguage' |
    ForEach-Object { Add-Ev ("  [test] {0}:{1}" -f $_.Path.Replace((Get-Location).Path + '\', ''), $_.LineNumber) }

# ---------- 7. summary ----------
Write-Host ''
Write-Host '================ STEP 9a SUMMARY ================' -ForegroundColor Green
Add-Ev ''
Add-Ev '=== SUMMARY ==='
foreach ($k in $results.Keys) {
    $line = "{0,-26} exit={1}" -f $k, $results[$k]
    Write-Host $line
    Add-Ev $line
}
Write-Host "Inventory candidates: $(@($hits).Count)  (see p115_step9a_inventory.txt)"
Write-Host "Evidence file:        $ev"
Write-Host 'No existing file was modified.'
Add-Ev "Inventory candidates: $(@($hits).Count)"