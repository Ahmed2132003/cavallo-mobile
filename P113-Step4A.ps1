<#
.SYNOPSIS
  P-113 / STEP 4 / PART A - Business create sheet, Staff moderation badge,
  shell wiring, and the new createSheet* ARB keys.

.DESCRIPTION
  Creates lib\core\shell\create_sheet.dart and its test, replaces
  lib\core\shell\app_shell.dart (the STEP 2A/2B file), appends 5 keys to the
  end of both ARB files, then runs `flutter gen-l10n`.

  Safe to run twice. Every overwritten file is backed up next to the project
  folder (never inside the repository). It does not touch app_router.dart,
  the manifest, the hub, the Saved screen or any other file.
#>
[CmdletBinding()]
param(
    [string]$MobileRoot = 'D:\Cavallo\social_commerce_app',
    [switch]$SkipGenL10n,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-Text([string]$path) { return [System.IO.File]::ReadAllText($path, $utf8NoBom) }

function Save-Text([string]$path, [string]$text) {
    $t = $text -replace "`r`n", "`n"
    if (-not $t.EndsWith("`n")) { $t += "`n" }
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $t, $utf8NoBom)
}

# ---------------- 0. Preflight ----------------
if (-not (Test-Path -LiteralPath $MobileRoot)) { throw "MobileRoot not found: $MobileRoot" }
$root = (Resolve-Path -LiteralPath $MobileRoot).Path
$pubspecPath = Join-Path $root 'pubspec.yaml'
if (-not (Test-Path -LiteralPath $pubspecPath)) { throw "pubspec.yaml not found in $root" }
if (-not ((Read-Text $pubspecPath) -match '(?m)^name:\s*social_commerce_app\s*$')) {
    throw "$pubspecPath is not the social_commerce_app project."
}

$required = @(
    'lib\core\shell\app_shell.dart',
    'lib\core\shell\app_bottom_bar.dart',
    'lib\core\shell\shell_branches.dart',
    'lib\core\l10n\l10n_context.dart',
    'lib\routing\navigation_manifest.dart',
    'lib\routing\route_names.dart',
    'lib\features\moderation\presentation\moderation_provider.dart',
    'lib\features\saved\presentation\saved_screen.dart',
    'lib\l10n\app_en.arb',
    'lib\l10n\app_ar.arb'
)
$missing = @()
foreach ($rel in $required) { if (-not (Test-Path -LiteralPath (Join-Path $root $rel))) { $missing += $rel } }
if ($missing.Count -gt 0) { throw ("Missing files:`n  " + ($missing -join "`n  ")) }

$shellPath = Join-Path $root 'lib\core\shell\app_shell.dart'
$shellCurrent = Read-Text $shellPath
$shellIsStep2 = $shellCurrent.Contains('Part P-113 (STEP 2A')
$shellIsStep4 = $shellCurrent.Contains('Part P-113 (STEP 4A)')
if ((-not $shellIsStep2) -and (-not $shellIsStep4) -and (-not $Force)) {
    throw "app_shell.dart is neither the STEP 2 file nor a STEP 4A file. Nothing was changed. Use -Force to overwrite."
}

$enPath = Join-Path $root 'lib\l10n\app_en.arb'
$arPath = Join-Path $root 'lib\l10n\app_ar.arb'
$enText = Read-Text $enPath
$arText = Read-Text $arPath
$enHas = $enText.Contains('"createSheetTitle"')
$arHas = $arText.Contains('"createSheetTitle"')
if ($enHas -ne $arHas) { throw "ARB files disagree about createSheet keys. Nothing was changed." }
$arbAlreadyDone = $enHas

# ---------------- Embedded content ----------------
$arbEn = @'
  "createSheetTitle": "Create new",
  "@createSheetTitle": {
    "description": "Title of the Business create sheet opened by the + tab."
  },
  "createSheetPost": "Post",
  "@createSheetPost": {
    "description": "Create sheet option: new post."
  },
  "createSheetReel": "Reel",
  "@createSheetReel": {
    "description": "Create sheet option: new reel."
  },
  "createSheetStory": "Story",
  "@createSheetStory": {
    "description": "Create sheet option: new story."
  },
  "createSheetProduct": "Product",
  "@createSheetProduct": {
    "description": "Create sheet option: new product."
  }
'@

$arbAr = @'
  "createSheetTitle": "\u0625\u0646\u0634\u0627\u0621 \u062c\u062f\u064a\u062f",
  "createSheetPost": "\u0645\u0646\u0634\u0648\u0631",
  "createSheetReel": "\u0631\u064a\u0644",
  "createSheetStory": "\u0633\u062a\u0648\u0631\u064a",
  "createSheetProduct": "\u0645\u0646\u062a\u062c"
'@

$sources = @(
    @{ Path = 'lib\core\shell\create_sheet.dart'; Content = @'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../routing/route_names.dart';
import '../l10n/l10n_context.dart';

/// Part P-113 (STEP 4A): the Business "+" create sheet.
///
/// Four options, each routing to a form that already exists:
/// Post ([RouteNames.postForm]), Reel ([RouteNames.reelForm]),
/// Story ([RouteNames.storyForm]) and Product ([RouteNames.productForm],
/// create mode: no `extra`).
///
/// The sheet itself never navigates. It pops with the chosen route name and
/// [showCreateSheet] pushes it afterwards, using the router captured BEFORE
/// the sheet opened, so nothing depends on a context that was just popped.
/// The forms are top-level routes, so they open above the shell and back
/// returns to the tab the user was on.
///
/// Who may open these forms is still decided by the router redirect guards,
/// not by this sheet. The sheet is only reachable from the Business "+" tab.
class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key});

  static const Key titleKey = Key('create-sheet-title');

  /// Key of the option that opens [routeName].
  static Key optionKey(String routeName) => Key('create-sheet-$routeName');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    Widget option(String routeName, IconData icon, String label) {
      return ListTile(
        key: optionKey(routeName),
        leading: Icon(icon),
        title: Text(label),
        onTap: () => Navigator.of(context).pop(routeName),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
            child: Text(
              l10n.createSheetTitle,
              key: titleKey,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          option(RouteNames.postForm, Icons.image_outlined, l10n.createSheetPost),
          option(
            RouteNames.reelForm,
            Icons.play_circle_outline,
            l10n.createSheetReel,
          ),
          option(
            RouteNames.storyForm,
            Icons.auto_stories_outlined,
            l10n.createSheetStory,
          ),
          option(
            RouteNames.productForm,
            Icons.inventory_2_outlined,
            l10n.createSheetProduct,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Opens the create sheet and, if an option was chosen, pushes its form.
Future<void> showCreateSheet(BuildContext context) async {
  final GoRouter router = GoRouter.of(context);
  final String? routeName = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => const CreateSheet(),
  );
  if (routeName != null) {
    router.pushNamed(routeName);
  }
}
'@ }
    @{ Path = 'lib\core\shell\app_shell.dart'; Content = @'
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_entity.dart';
import '../../features/auth/presentation/session_provider.dart';
import '../../features/moderation/presentation/moderation_provider.dart';
import '../../routing/navigation_manifest.dart';
import '../../routing/route_names.dart';
import 'app_bottom_bar.dart';
import 'create_sheet.dart';
import 'shell_branches.dart';

/// Part P-113 (STEP 2A, back behaviour STEP 2B, create sheet and moderation
/// badge STEP 4A): the app shell - the persistent frame around the tabs.
///
/// It wraps the branches of the app's `StatefulShellRoute.indexedStack`
/// (declared in `app_router.dart`) and adds the bottom bar for the signed-in
/// account type. Each branch keeps its own navigator, so every tab remembers
/// its back stack and scroll position.
///
/// ## Back button
///
/// System back on a tab root returns to the Home tab first, and only from
/// Home does it leave the app:
/// * a screen pushed INSIDE a tab is popped first;
/// * on any other tab root, back switches to the Home tab;
/// * on the Home tab root, back is not intercepted (the app exits).
///
/// ## Business "+" (STEP 4A)
///
/// Unless [onCreateTap] is given, the "+" tab opens the create sheet
/// ([showCreateSheet]). It is an action: it never changes the selected tab.
///
/// ## Moderation badge (STEP 4A)
///
/// For the Staff audience only, the shell reads the EXISTING
/// `moderationQueueProvider` and shows the number of pending items on the
/// Moderation tab. No polling and no new request are added; nothing is read
/// for other account types. Entries of [badgeCounts] win over this value.
///
/// ## What it does NOT do
/// * It does not grant or deny access. Who may open which route is decided by
///   the router `redirect` guards, which P-113 leaves untouched.
/// * It has no top bar. Each tab root keeps its own AppBar.
///
/// The audience is read from [sessionProvider] through [navAudienceForUser].
/// While no user is available (a login/logout is in flight) the bar is simply
/// not drawn; the body keeps its place in the tree, so nothing is remounted.
class AppShell extends ConsumerWidget {
  const AppShell({
    required this.navigationShell,
    this.onCreateTap,
    this.badgeCounts = const <String, int>{},
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  /// Overrides what the Business "+" tab does. Null opens the create sheet.
  final VoidCallback? onCreateTap;

  /// Badge counts by destination id, forwarded to [AppBottomBar]. They win
  /// over the counts the shell computes itself.
  final Map<String, int> badgeCounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<User?> session = ref.watch(sessionProvider);
    final User? user = switch (session) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final NavAudience? audience =
        user == null ? null : navAudienceForUser(user);

    // Staff only: the pending count of the existing moderation queue.
    final int pendingModeration =
        audience == NavAudience.staff
            ? ref.watch(
              moderationQueueProvider.select(
                (async) => switch (async) {
                  AsyncData(:final value) => value.length,
                  _ => 0,
                },
              ),
            )
            : 0;

    final Map<String, int> counts = <String, int>{
      if (pendingModeration > 0) RouteNames.moderation: pendingModeration,
      ...badgeCounts,
    };

    return PopScope(
      // Only the Home tab lets the system back button through (= exit).
      canPop: navigationShell.currentIndex == ShellBranch.home,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          navigationShell.goBranch(ShellBranch.home);
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar:
            audience == null
                ? null
                : AppBottomBar(
                  audience: audience,
                  currentBranch: navigationShell.currentIndex,
                  onSelectBranch:
                      (int branch) => navigationShell.goBranch(
                        branch,
                        // Tapping the tab you are already on pops it back to
                        // its branch root (standard bottom-nav behaviour).
                        initialLocation: branch == navigationShell.currentIndex,
                      ),
                  onCreate:
                      onCreateTap ??
                      () => unawaited(showCreateSheet(context)),
                  badgeCounts: counts,
                ),
      ),
    );
  }
}
'@ }
    @{ Path = 'test\core\shell\create_sheet_test.dart'; Content = @'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/shell/create_sheet.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-113 (STEP 4A): the Business create sheet.

const List<String> _forms = <String>[
  RouteNames.postForm,
  RouteNames.reelForm,
  RouteNames.storyForm,
  RouteNames.productForm,
];

const String _arTitle = '\u0625\u0646\u0634\u0627\u0621 \u062c\u062f\u064a\u062f';

GoRouter _router() {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder:
            (BuildContext context, GoRouterState state) => Scaffold(
              body: Builder(
                builder:
                    (BuildContext inner) => TextButton(
                      key: const Key('open-sheet'),
                      onPressed: () => showCreateSheet(inner),
                      child: const Text('open'),
                    ),
              ),
            ),
      ),
      for (final String name in _forms)
        GoRoute(
          path: '/$name',
          name: name,
          builder:
              (BuildContext context, GoRouterState state) =>
                  Scaffold(appBar: AppBar(), body: Text('stub:$name')),
        ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final GoRouter router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-sheet')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sheet offers Post, Reel, Story and Product', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    expect(find.text('Create new'), findsOneWidget);
    for (final String name in _forms) {
      expect(find.byKey(CreateSheet.optionKey(name)), findsOneWidget, reason: name);
    }
    expect(find.text('Post'), findsOneWidget);
    expect(find.text('Reel'), findsOneWidget);
    expect(find.text('Story'), findsOneWidget);
    expect(find.text('Product'), findsOneWidget);
  });

  for (final String name in _forms) {
    testWidgets('choosing $name opens that form route', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(CreateSheet.optionKey(name)));
      await tester.pumpAndSettle();

      expect(find.text('stub:$name'), findsOneWidget);
      expect(find.byKey(CreateSheet.titleKey), findsNothing);
    });
  }

  testWidgets('dismissing the sheet opens nothing', (WidgetTester tester) async {
    await _pump(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byKey(CreateSheet.titleKey), findsNothing);
    expect(find.textContaining('stub:'), findsNothing);
  });

  testWidgets('works in Arabic', (WidgetTester tester) async {
    await _pump(tester, locale: const Locale('ar'));

    expect(find.text(_arTitle), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byKey(CreateSheet.titleKey))),
      TextDirection.rtl,
    );
  });
}
'@ }
)

# ---------------- 1. Second preflight ----------------
if (-not $arbAlreadyDone) {
    $newKeys = @()
    foreach ($m in [regex]::Matches($arbEn, '(?m)^  "(createSheet[A-Za-z0-9]+)":')) { $newKeys += $m.Groups[1].Value }
    $clashes = @()
    foreach ($k in $newKeys) {
        if ($enText.Contains('"' + $k + '"') -or $arText.Contains('"' + $k + '"')) { $clashes += $k }
    }
    if ($clashes.Count -gt 0) { throw ("ARB keys already exist: " + ($clashes -join ', ') + ". Nothing was changed.") }
}

foreach ($s in $sources) {
    $target = Join-Path $root $s.Path
    if ((Test-Path -LiteralPath $target) -and ($s.Path -ne 'lib\core\shell\app_shell.dart') -and (-not $Force)) {
        $existing = Read-Text $target
        if (-not $existing.Contains('STEP 4A')) {
            throw "$($s.Path) already exists and is not a STEP 4A file. Nothing was changed. Use -Force."
        }
    }
}

# ---------------- 2. Backup ----------------
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path (Split-Path -Parent $root) ("_p113_step4a_backup_" + $stamp)
$backedUp = @()
function Backup-File([string]$fullPath) {
    if (-not (Test-Path -LiteralPath $fullPath)) { return }
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    $dest = Join-Path $backupRoot $rel
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Copy-Item -LiteralPath $fullPath -Destination $dest -Force
    $script:backedUp += $rel
}
foreach ($s in $sources) { Backup-File (Join-Path $root $s.Path) }
if (-not $arbAlreadyDone) { Backup-File $enPath; Backup-File $arPath }

# ---------------- 3. Write Dart files ----------------
$created = @(); $replaced = @()
foreach ($s in $sources) {
    $target = Join-Path $root $s.Path
    $existed = Test-Path -LiteralPath $target
    Save-Text $target $s.Content
    if ($existed) { $replaced += $s.Path } else { $created += $s.Path }
    Write-Host ("  wrote " + $s.Path)
}

# ---------------- 4. ARB ----------------
function Add-ArbEntries([string]$path, [string]$entries) {
    $text = Read-Text $path
    $nl = "`n"
    if ($text.Contains("`r`n")) { $nl = "`r`n" }
    $trimmed = $text.TrimEnd()
    if (-not $trimmed.EndsWith('}')) { throw "$path does not end with '}', refusing to patch it." }
    $body = $trimmed.Substring(0, $trimmed.Length - 1).TrimEnd()
    if ($body.EndsWith(',')) { throw "$path has a trailing comma before the closing brace, refusing to patch it." }
    $block = $entries -replace "`r`n", "`n"
    $block = $block.TrimEnd() -replace "`n", $nl
    $patched = $body + ',' + $nl + $block + $nl + '}' + $nl
    try { $null = $patched | ConvertFrom-Json } catch {
        throw "Patched $path is not valid JSON, nothing was written to it: $($_.Exception.Message)"
    }
    [System.IO.File]::WriteAllText($path, $patched, $utf8NoBom)
}

$arbPatched = @()
if ($arbAlreadyDone) {
    Write-Host '  ARB keys already present, skipped.'
} else {
    Add-ArbEntries $enPath $arbEn
    Add-ArbEntries $arPath $arbAr
    $arbPatched += 'lib\l10n\app_en.arb'
    $arbPatched += 'lib\l10n\app_ar.arb'
    Write-Host '  appended createSheet keys to app_en.arb and app_ar.arb'
}

# ---------------- 5. gen-l10n ----------------
$genStatus = 'skipped (-SkipGenL10n)'
if (-not $SkipGenL10n) {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        $genStatus = 'NOT RUN: flutter is not on PATH'
        Write-Warning 'flutter is not on PATH. Run "flutter gen-l10n" yourself from the project folder.'
    } else {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        Push-Location $root
        try { & flutter gen-l10n; $genExit = $LASTEXITCODE }
        finally { Pop-Location; $ErrorActionPreference = $previousPreference }
        if ($genExit -ne 0) { throw "flutter gen-l10n failed with exit code $genExit" }
        $gen = Read-Text (Join-Path $root 'lib\l10n\app_localizations.dart')
        if (-not $gen.Contains('createSheetTitle')) {
            throw 'flutter gen-l10n finished but app_localizations.dart has no createSheetTitle. Check l10n.yaml.'
        }
        $genStatus = 'done (lib\l10n\app_localizations*.dart regenerated)'
    }
}

# ---------------- 6. Summary ----------------
Write-Host ''
Write-Host '================ P-113 STEP 4 / PART A - done ================'
Write-Host 'Created:'
foreach ($p in $created) { Write-Host ("  + " + $p) }
Write-Host 'Replaced:'
foreach ($p in $replaced) { Write-Host ("  ~ " + $p) }
Write-Host 'Patched (keys appended at the end only):'
foreach ($p in $arbPatched) { Write-Host ("  ~ " + $p) }
Write-Host ("gen-l10n: " + $genStatus)
if ($backedUp.Count -gt 0) { Write-Host ("Backup of replaced files: " + $backupRoot) }
Write-Host ''
Write-Host 'Next, from the project folder:'
Write-Host '  flutter analyze'
Write-Host '  flutter test test\core\shell test\routing test\features\profile_hub'