param([string]$MobileRoot = 'D:\Cavallo\social_commerce_app')
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$routerPath = Join-Path $MobileRoot 'lib\routing\app_router.dart'
if (-not (Test-Path $routerPath)) { throw "app_router.dart not found in $MobileRoot" }

# ---- 1. placeholder screens (created only if missing) ----
$savedPath   = Join-Path $MobileRoot 'lib\features\saved\presentation\saved_screen.dart'
$profilePath = Join-Path $MobileRoot 'lib\features\profile_hub\presentation\profile_hub_screen.dart'

$savedSrc = @'
import 'package:flutter/material.dart';

/// TEMPORARY (P-113 STEP 1 fix): empty placeholder so the `saved` route
/// exists and the reachability test can pass. P-113 STEP 3 replaces this
/// file with the real Saved screen (Posts / Reels / Products tabs).
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SizedBox.shrink());
}
'@

$profileSrc = @'
import 'package:flutter/material.dart';

/// TEMPORARY (P-113 STEP 1 fix): empty placeholder so the `profile` route
/// exists and the reachability test can pass. P-113 STEP 3 replaces this
/// file with the real Profile & Settings hub.
class ProfileHubScreen extends StatelessWidget {
  const ProfileHubScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SizedBox.shrink());
}
'@

foreach ($item in @(@($savedPath, $savedSrc), @($profilePath, $profileSrc))) {
  $p = $item[0]
  if (Test-Path $p) { Write-Host "  exists, skipped: $p"; continue }
  $dir = Split-Path -Parent $p
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($p, $item[1], $utf8NoBom)
  Write-Host "  wrote $p"
}

# ---- 2. app_router.dart: two imports + two GoRoutes (additive only) ----
$raw = [System.IO.File]::ReadAllText($routerPath)
if ($raw.Contains('RouteNames.savedPath')) {
  Write-Host '  app_router.dart already has the saved/profile routes - skipped'
} else {
  $nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }

  $importAnchor = "import '../features/notifications/presentation/notification_preferences_screen.dart';"
  if (-not $raw.Contains($importAnchor)) { throw 'Import anchor not found; no change made.' }
  $newImports = $importAnchor + $nl +
    "import '../features/profile_hub/presentation/profile_hub_screen.dart';" + $nl +
    "import '../features/saved/presentation/saved_screen.dart';"
  $raw = $raw.Replace($importAnchor, $newImports)

  $routeRegex = '(builder: \(context, state\) => const NotificationPreferencesScreen\(\),\r?\n      \),)'
  if (-not [regex]::IsMatch($raw, $routeRegex)) { throw 'Route anchor not found; no change made.' }
  $routes = $nl +
    '      GoRoute(' + $nl +
    '        // Part P-113 (STEP 1 fix): placeholder, moved into the shell in STEP 2.' + $nl +
    '        path: RouteNames.savedPath,' + $nl +
    '        name: RouteNames.saved,' + $nl +
    '        builder: (context, state) => const SavedScreen(),' + $nl +
    '      ),' + $nl +
    '      GoRoute(' + $nl +
    '        // Part P-113 (STEP 1 fix): placeholder, moved into the shell in STEP 2.' + $nl +
    '        path: RouteNames.profilePath,' + $nl +
    '        name: RouteNames.profile,' + $nl +
    '        builder: (context, state) => const ProfileHubScreen(),' + $nl +
    '      ),'
  $raw = [regex]::Replace($raw, $routeRegex, { param($m) $m.Groups[1].Value + $routes }, 1)

  $evidenceDir = Join-Path (Split-Path -Parent $MobileRoot) 'p113_evidence'
  if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir | Out-Null }
  Copy-Item $routerPath (Join-Path $evidenceDir 'app_router.dart.bak') -Force
  [System.IO.File]::WriteAllText($routerPath, $raw, $utf8NoBom)
  Write-Host "  edited $routerPath (backup in $evidenceDir)"
}
Write-Host 'STEP 1 fix applied.' -ForegroundColor Green