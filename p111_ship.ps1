# =====================================================================
# P-111 SHIP  -  commit + push cavallo-mobile, verify, append Progress to cavallo-app, commit + push, verify
#                  (stops before touching anything if a precondition fails)
# Run from: D:\Cavallo\social_commerce_app   (branch part-111, STEP 3 green)
# Usage:    powershell -ExecutionPolicy Bypass -File .\p111_ship.ps1
# Run it ONCE. ASCII only on purpose (Windows PowerShell 5.1).
# =====================================================================
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Get-Location).Path
$Evidence = Join-Path $Root 'p111_ship_evidence.txt'
Set-Content -Path $Evidence -Value ("P-111 SHIP evidence - " + (Get-Date -Format 's')) -Encoding ASCII

function Log([string]$m) { Write-Host $m; Add-Content -Path $Evidence -Value $m -Encoding ASCII }
function Fail([string]$m) { Write-Host ("ABORT: " + $m) -ForegroundColor Red; Add-Content -Path $Evidence -Value ("ABORT: " + $m); exit 1 }

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-NewFile([string]$RelPath, [string]$Content) {
    $full = Join-Path $Root $RelPath
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $text = ($Content -replace "`r?`n", "`r`n")
    [System.IO.File]::WriteAllText($full, $text, $Utf8NoBom)
    Log ("  wrote  " + $RelPath)
}

# Rewrites a text file while preserving a UTF-8 BOM if the original had one.
function Update-TextFile([string]$RelPath, [scriptblock]$Transform) {
    $full = Join-Path $Root $RelPath
    $bytes = [System.IO.File]::ReadAllBytes($full)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $start = 0; if ($hasBom) { $start = 3 }
    $text = $Utf8NoBom.GetString($bytes, $start, $bytes.Length - $start)
    $new = & $Transform $text
    if ($new -ceq $text) { Log ("  unchanged " + $RelPath); return }
    $out = New-Object System.Text.UTF8Encoding($hasBom)
    [System.IO.File]::WriteAllText($full, $new, $out)
    Log ("  edited " + $RelPath)
}

function Run-Native([string]$Title, [scriptblock]$Cmd) {
    Log ""
    Log ("=== " + $Title + " ===")
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & $Cmd 2>&1 | ForEach-Object { $_.ToString() }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    $out | ForEach-Object { Add-Content -Path $Evidence -Value $_ }
    Log ("exit code: " + $code)
    return @{ Code = $code; Out = $out }
}



$Mobile = $Root
$Backend = 'D:\Cavallo\scd-backend'
$Progress = Join-Path $Backend 'PROJECT_PROGRESS.md'
$Today = Get-Date -Format 'yyyy-MM-dd'

function G([string]$Repo, [string[]]$GitArgs) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & git -C $Repo @GitArgs 2>&1 | ForEach-Object { $_.ToString() }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($null -eq $out) { $out = @() }
    $out = @($out)
    Add-Content -Path $Evidence -Value ("git " + ($GitArgs -join ' ') + "  -> exit " + $code)
    foreach ($l in $out) { Add-Content -Path $Evidence -Value $l }
    return @{ Code = $code; Out = $out }
}
function One($r) { return (($r.Out -join "`n").Trim()) }

# ---------- 0. preflight (nothing is changed here) ----------
Log "=== 0. PREFLIGHT ==="
if (-not (Test-Path (Join-Path $Mobile '.git'))) { Fail "not a git repo: $Mobile" }
if (-not (Test-Path (Join-Path $Backend '.git'))) { Fail "not a git repo: $Backend" }
if (-not (Test-Path $Progress)) { Fail "missing $Progress" }

$mb = One (G $Mobile @('rev-parse', '--abbrev-ref', 'HEAD'))
Log ("mobile branch:  " + $mb)
if ($mb -ne 'part-111') { Fail "mobile repo is on '$mb', expected part-111" }
$bb = One (G $Backend @('rev-parse', '--abbrev-ref', 'HEAD'))
Log ("backend branch: " + $bb)
if ($bb -ne 'develop') { Fail "backend repo is on '$bb', expected develop (the Progress file lives on develop). Send me this line." }

$mo = One (G $Mobile @('remote', 'get-url', 'origin'))
$bo = One (G $Backend @('remote', 'get-url', 'origin'))
Log ("mobile origin:  " + $mo)
Log ("backend origin: " + $bo)

$null = G $Backend @('fetch', 'origin')
$behind = One (G $Backend @('rev-list', '--count', 'HEAD..origin/develop'))
Log ("backend commits behind origin/develop: " + $behind)
if ($behind -ne '0') { Fail "backend develop is behind origin by $behind commit(s); run git pull in D:\Cavallo\scd-backend first" }

$dirty = One (G $Backend @('status', '--porcelain', '--', 'PROJECT_PROGRESS.md'))
if ($dirty -ne '') { Fail "PROJECT_PROGRESS.md already has uncommitted changes in the backend repo: $dirty" }
$pre = One (G $Backend @('diff', '--cached', '--name-only'))
if ($pre -ne '') { Fail "the backend repo already has staged files, commit or unstage them first: $pre" }
if (Select-String -Path $Progress -Pattern '## PART P-111' -Quiet) { Fail "PROJECT_PROGRESS.md already contains a P-111 section" }
Log "preflight OK"

# ---------- 1. mobile: stage, commit, push, verify ----------
Log ""
Log "=== 1. cavallo-mobile: stage (lib, test, assets, pubspec.yaml only) ==="
$null = G $Mobile @('add', '-A', '--', 'lib', 'test', 'assets', 'pubspec.yaml')
$staged = G $Mobile @('diff', '--cached', '--name-status')
if ($staged.Out.Count -eq 0) { Fail "nothing staged in the mobile repo" }
$bad = @($staged.Out | Where-Object { $_ -match 'p111_|evidence|\.bak|backup|\.log' })
if ($bad.Count -gt 0) { $bad | ForEach-Object { Log ("  unexpected: " + $_) }; Fail "unexpected file in the staged set (nothing committed)" }
Log ("staged files: " + $staged.Out.Count)
$staged.Out | ForEach-Object { Log ("  " + $_) }

Log ""
Log "=== 2. cavallo-mobile: commit ==="
$c = G $Mobile @('commit', '-m', 'P-111: design system foundation (Cavallo Blue tokens, light/dark themes, persisted ThemeMode, core widget restyle, status tokens)')
$c.Out | Select-Object -First 3 | ForEach-Object { Log ("  " + $_) }
if ($c.Code -ne 0) { Fail "mobile commit failed" }
$mobileSha = One (G $Mobile @('rev-parse', 'HEAD'))
$mobileParent = One (G $Mobile @('rev-parse', '--short=7', 'HEAD~1'))
$mobileShort = $mobileSha.Substring(0, 7)
Log ("mobile commit: " + $mobileShort + " (parent " + $mobileParent + ")")

Log ""
Log "=== 3. cavallo-mobile: push + verify ==="
$p = G $Mobile @('push', '-u', 'origin', 'part-111')
$p.Out | Select-Object -Last 4 | ForEach-Object { Log ("  " + $_) }
if ($p.Code -ne 0) { Fail "mobile push failed (the commit exists locally). Send me the lines above." }
$ls = One (G $Mobile @('ls-remote', 'origin', 'refs/heads/part-111'))
$remoteSha = ($ls -split '\s+')[0]
Log ("local  HEAD:        " + $mobileSha)
Log ("remote part-111:    " + $remoteSha)
if ($remoteSha -ne $mobileSha) { Fail "mobile push NOT verified: remote does not equal local HEAD" }
Log "MOBILE PUSH VERIFIED"

# ---------- 2. backend: append Progress, commit, push, verify ----------
Log ""
Log "=== 4. cavallo-app: append the P-111 section to PROJECT_PROGRESS.md ==="
$backendParent = One (G $Backend @('rev-parse', '--short=7', 'HEAD'))
$section = @'
## PART P-111 - Flutter: Design System Foundation (Phase 23) - STATUS: CODE COMPLETE, AUTOMATED CHECKS GREEN (@@DATE@@); NOT MARKED COMPLETE: golden tests and the manual Light/Dark walk-through are still OPEN

### What was implemented
- Cavallo Blue tokens as a ThemeExtension in lib/core/theme/app_colors.dart: AppColors with light and dark instances, value equality (== and hashCode, needed because MaterialApp copies the extension through AnimatedTheme), copyWith, lerp, and context.appColors (falls back to AppColors.light/dark by ambient brightness when a bare MaterialApp has no AppTheme). Tokens: brand, onBrand, brandText, background, surface, surfaceVariant, outline, textPrimary, textSecondary, danger, onDanger, featured, onFeatured, storyRing gradient, plus computed storyRingSeen and brandSubtle.
- STEP 3 added successText, warningText, dangerText and the computed successSubtle, warningSubtle, dangerSubtle (tint = the text colour at 10% over surface). Values: Light 187A37 / 8A5A00 / C4232F, Dark 4ADE80 / FFC94D / FF6B74. Light dangerText is deliberately deeper than danger (D92D3A gives only 4.24:1 on its own tint). Measured ratios on the tint: 4.73, 5.13, 4.93 (Light) and 8.47, 9.48, 5.72 (Dark).
- AppTheme.light and AppTheme.dark in lib/core/theme/app_theme.dart, typography in app_typography.dart, bundled font under assets/ declared in pubspec.yaml (no google_fonts). lib/core/config/app_theme.dart was deleted; the legacy AppTheme.theme alias still points at light.
- ThemeMode: lib/core/theme/theme_mode_provider.dart. One cache key app.theme_mode through the existing CacheStorage, stored as the string system|light|dark; any other value means system. preloadThemeMode() never throws. themeModeProvider (Notifier) is the only owner of theme state; initialThemeModeProvider carries the preloaded value.
- main.dart wiring (the real main.dart differs from the shape the master plan assumed): main() was already Future<void> and runApp lives inside _installErrorHooksAndRunApp(), reached through SentryFlutter.init(appRunner: ...). A top-level private _initialThemeMode is set in main() right after WidgetsFlutterBinding.ensureInitialized() via await preloadThemeMode(), and injected with initialThemeModeProvider.overrideWithValue(_initialThemeMode) in the single ProviderScope overrides list, so there is no light-to-dark flash. Both MaterialApp constructors (bootstrap spinner and router) now get theme: AppTheme.light, darkTheme: AppTheme.dark, themeMode: themeMode.
- Core widgets restyled to the tokens: AppButton, AppTextField, FeaturedBadge, EmptyStateWidget, ErrorStateWidget, LoadingIndicator. New shared widgets: AppAvatar (optional unseen/seen story ring, 44 px minimum tap target) and AppShimmerBox (skeleton, stops animating under reduced motion).
- Hardcoded-colour replacement in features: 17 replacements (content_list_screen 10, moderation_widgets 6 with QueueAgeChip _styleFor now taking AppColors, content_action_row 1 like icon -> danger). Processing badge -> surfaceVariant + textSecondary. 13 hits kept on purpose (see audit record).

### Hardcoded-colour audit record
- STEP 1 audit file p111_step1_audit.txt (not committed): 58 hits, 27 in the new theme files, 31 in features. The 30 feature lines re-listed in STEP 3 were classified: 17 replaceable (done) and 13 intentional and kept: message_bubble_widget 2, reel_card 2, reel_detail_screen 2 (black 45% play scrim + white icon), notification_center_screen 1 (Colors.transparent), story_viewer_screen 6 (forced dark theme, black/white/white24/white54).
- Final authority is the guard test test/core/theme/status_tokens_test.dart: it scans all of lib/ outside core/theme and fails on any Colors.<name> other than black, white, white24, white54, transparent, and on any Color(0x literal. Its regex has a lookbehind so identifiers such as appColors are not matched.

### Files created (cavallo-mobile)
- lib/core/theme/app_colors.dart, app_theme.dart, app_typography.dart, theme_mode_provider.dart; assets/ (bundled font files); lib/core/widgets/app_avatar.dart, app_shimmer_box.dart.
- Tests: test/core/theme/app_theme_foundation_test.dart, theme_mode_provider_test.dart, status_tokens_test.dart; test/core/widgets/core_widgets_theming_test.dart, app_avatar_test.dart, app_shimmer_box_test.dart.

### Files modified (cavallo-mobile)
- pubspec.yaml, lib/main.dart, lib/core/widgets/{app_button, app_text_field, featured_badge, empty_state_widget, error_state_widget, loading_indicator}.dart, lib/features/content/presentation/content_list_screen.dart, lib/features/moderation/presentation/moderation_widgets.dart, lib/features/social/presentation/content_action_row.dart.
- Tests updated: test/core/integration_test.dart, test/core/widgets/widget_gallery_demo_test.dart, test/features/business_console/presentation/business_console_shell_test.dart (STEP 1); test/features/moderation/presentation/moderation_widgets_test.dart and moderation_queue_screen_test.dart (STEP 3: expectations moved from Colors.green/amber/red shades to AppColors.light.successText/warningText/dangerText, because a bare MaterialApp falls back to the light tokens).
- Deleted: lib/core/config/app_theme.dart.

### Important implementation details and architecture decisions
- Colour values live only in app_colors.dart; features read context.appColors. The three status text tokens and their computed tints exist because the design tokens table had no success or warning colour and Colors.green/amber shades are unreadable in Dark.
- PowerShell 5.1 reads BOM-less scripts as ANSI, so scripts stay ASCII; an Arabic literal in a Dart test was written as \u escapes.
- flutter analyze scans every .dart file under the project root, so script backups must live outside the repo (a backup folder inside it produced 54 false errors and was auto-restored).
- There is no UI to change ThemeMode yet (P-113 builds the Settings screen). Live switching is covered by widget tests; manually only System mode (OS dark-mode setting) can be exercised until a temporary debug toggle or P-113 exists.

### Commands
- Analyze: flutter analyze (from D:\Cavallo\social_commerce_app). Tests: flutter test (full suite).
- Scripts (outside the repo history, not committed): p111_step1*.ps1, p111_step2.ps1, p111_step2b.ps1, p111_step3.ps1, p111_step3_fix.ps1 and their *_evidence.txt files, all in D:\Cavallo\social_commerce_app.

### Tests and verification results (@@DATE@@)
- flutter analyze: No issues found. flutter test (full suite): 1097 tests, All tests passed.
- New tests cover: ThemeMode round-trip and junk-means-system, preload persistence across restarts, provider persisting one string key, live switching in a MaterialApp and System mode following the OS brightness, core widgets rendering in both themes, AppTextField 12 px radius from the theme, AppAvatar sizes/rings/tap target, AppShimmerBox, status text contrast >= 4.5:1 on tint (both themes), processing chip textSecondary on surfaceVariant >= 4.5:1, like icon >= 3:1, copyWith/equality/lerp of the new tokens, and the hardcoded-colour guard.

### Known issues and OPEN Definition-of-Done items
- OPEN: golden tests (light and dark) for AppButton, AppTextField, FeaturedBadge and AppAvatar. Goldens must be generated on the owner's machine (flutter test --update-goldens) and committed.
- OPEN: manual walk-through of Login, Register, Home, Search, Business Console and Chat in Light, Dark and System, with restart persistence, on a device or emulator. Not done.
- OPEN, to confirm: the spec contrast assertions textPrimary/background, textSecondary/surface, white/brand and brandText/surface; check whether test/core/theme/app_theme_foundation_test.dart already asserts them and add them if not. Also confirm a test asserts that every token of AppColors.light and AppColors.dark is non-null.
- No unit/golden test exists for the story viewer's forced dark theme; it was left untouched on purpose.

### Remaining work (exact order)
1. Close the three OPEN items above, then mark P-111 COMPLETE.
2. Decide whether to merge branch part-111 into cavallo-mobile main (not done by this part).
3. P-112 (localization and the Language setting next to the theme setting), then P-113 (navigation and the real Settings screen that hosts theme and language), P-114, P-115. P-114 and P-115 must use AppAvatar, AppShimmerBox and context.appColors instead of local variants.

### GitHub references
- cavallo-mobile: branch part-111, commit @@MOBILE_SHA@@ (parent @@MOBILE_PARENT@@), pushed and verified equal to origin/part-111.
- cavallo-app develop: the commit that records this section is the next commit on develop after @@BACKEND_PARENT@@.

### Exact next starting point
Finish the OPEN items (goldens, manual walk-through, contrast/non-null test confirmation), then start P-112 from PHASE_23_UI_UX_PARTS_P-111_to_P-115.docx on top of branch part-111.

### Edits to existing sections
- In the Part status index/table add: P-111 | Flutter Design System Foundation | Phase 23 | CODE COMPLETE; goldens and manual walk-through OPEN. Set the Phase 23 summary line to "IN PROGRESS (P-111 code complete with open DoD items, P-112 next)".
'@
$section = $section.Replace('@@DATE@@', $Today).Replace('@@MOBILE_SHA@@', $mobileShort).Replace('@@MOBILE_PARENT@@', $mobileParent).Replace('@@BACKEND_PARENT@@', $backendParent)
$section = ($section -replace "`r?`n", "`r`n")

$bytes = [System.IO.File]::ReadAllBytes($Progress)
$oldLen = $bytes.Length
$endsWithNewline = ($oldLen -ge 1 -and $bytes[$oldLen - 1] -eq 10)
$sep = "`r`n"
if (-not $endsWithNewline) { $sep = "`r`n`r`n" }
[System.IO.File]::AppendAllText($Progress, ($sep + $section + "`r`n"), $Utf8NoBom)
$newLen = (Get-Item $Progress).Length
Log ("file size: " + $oldLen + " -> " + $newLen + " bytes (appended " + ($newLen - $oldLen) + ")")
if ($newLen -le $oldLen) { Fail "Progress file did not grow" }
if (-not (Select-String -Path $Progress -Pattern '## PART P-111' -Quiet)) { Fail "P-111 heading not found after append" }
Log "last 3 lines of the file now:"
Get-Content -Path $Progress -Tail 3 | ForEach-Object { Log ("  " + $_) }

Log ""
Log "=== 5. cavallo-app: commit + push + verify ==="
$null = G $Backend @('add', '--', 'PROJECT_PROGRESS.md')
$st = One (G $Backend @('diff', '--cached', '--name-only'))
if ($st -ne 'PROJECT_PROGRESS.md') { Fail ("unexpected staged set in the backend repo: " + $st) }
$bc = G $Backend @('commit', '-m', 'P-111: Progress section (Phase 23 design system foundation; goldens and manual walk-through still open)')
$bc.Out | Select-Object -First 3 | ForEach-Object { Log ("  " + $_) }
if ($bc.Code -ne 0) { Fail "backend commit failed" }
$backendSha = One (G $Backend @('rev-parse', 'HEAD'))
$bp = G $Backend @('push', 'origin', 'develop')
$bp.Out | Select-Object -Last 4 | ForEach-Object { Log ("  " + $_) }
if ($bp.Code -ne 0) { Fail "backend push failed (the commit exists locally). Send me the lines above." }
$bls = One (G $Backend @('ls-remote', 'origin', 'refs/heads/develop'))
$bRemote = ($bls -split '\s+')[0]
Log ("local  HEAD:        " + $backendSha)
Log ("remote develop:     " + $bRemote)
if ($bRemote -ne $backendSha) { Fail "backend push NOT verified: remote does not equal local HEAD" }
Log "BACKEND PUSH VERIFIED"
$stat = One (G $Backend @('diff', '--stat', 'HEAD~1', 'HEAD', '--', 'PROJECT_PROGRESS.md'))
Log $stat

Log ""
Log "=== SHIP SUMMARY ==="
Log ("cavallo-mobile  part-111 : " + $mobileShort + "  (verified on origin)")
Log ("cavallo-app     develop   : " + $backendSha.Substring(0, 7) + "  (verified on origin)")
Log "SHIP RESULT: ALL PUSHED AND VERIFIED"
Write-Host ""
Write-Host "Evidence file: $Evidence  (do NOT commit it)" -ForegroundColor Cyan