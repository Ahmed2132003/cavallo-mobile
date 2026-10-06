<#
.SYNOPSIS
  P-113 / STEP 4 / PART B - the two in-context entry points that the
  navigation manifest already promises for Business accounts:
    1. "Tab 5 header shortcuts"  -> four shortcut buttons (Products, Content,
       Stories, Analytics) under the header of the Profile & Settings hub.
    2. "Edit button on the Business public profile" -> an Edit action in the
       app bar of the public Business profile, shown ONLY to the owner.

.DESCRIPTION
  Creates 3 Dart files and 2 test files, and patches 2 existing files with
  small exact-text edits (an import and one insertion each).

  - No ARB changes: the labels reuse hubProducts, hubContent, hubStories,
    hubAnalytics and hubEditBusinessProfile, which already exist in both ARB
    files. So there is NO gen-l10n in this step.
  - It does not touch app_router.dart, the navigation manifest, the shell,
    the create sheet, the Add buttons of the console lists, or any redirect
    guard.
  - Safe to run twice: a patch whose marker is already present is skipped, and
    files that come from this step are simply rewritten.
  - Every file it changes is first copied to a backup folder NEXT TO the
    project folder (never inside the repository).
  - Line endings of the two patched files (CRLF or LF) are preserved.

.PARAMETER MobileRoot
  The Flutter project folder (the one that contains pubspec.yaml).
#>
[CmdletBinding()]
param(
    [string]$MobileRoot = 'D:\Cavallo\social_commerce_app'
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
    'lib\core\l10n\l10n_context.dart',
    'lib\routing\route_names.dart',
    'lib\routing\navigation_manifest.dart',
    'lib\features\auth\domain\user_entity.dart',
    'lib\features\auth\presentation\session_provider.dart',
    'lib\features\business_profile\domain\business_profile_entity.dart',
    'lib\features\business_profile\presentation\business_profile_provider.dart',
    'lib\features\business_profile\presentation\business_profile_public_screen.dart',
    'lib\features\profile_hub\presentation\profile_hub_screen.dart',
    'lib\l10n\app_en.arb',
    'lib\l10n\app_ar.arb'
)
$missing = @()
foreach ($rel in $required) { if (-not (Test-Path -LiteralPath (Join-Path $root $rel))) { $missing += $rel } }
if ($missing.Count -gt 0) { throw ("Missing files:`n  " + ($missing -join "`n  ")) }

# The labels this step reuses must already exist in both ARB files.
foreach ($arb in @('lib\l10n\app_en.arb', 'lib\l10n\app_ar.arb')) {
    $arbText = Read-Text (Join-Path $root $arb)
    foreach ($key in @('hubProducts', 'hubContent', 'hubStories', 'hubAnalytics', 'hubEditBusinessProfile')) {
        if (-not $arbText.Contains('"' + $key + '"')) { throw "$arb has no key $key. Nothing was changed." }
    }
}

$hubPath = Join-Path $root 'lib\features\profile_hub\presentation\profile_hub_screen.dart'
$publicPath = Join-Path $root 'lib\features\business_profile\presentation\business_profile_public_screen.dart'
$hubText = Read-Text $hubPath
$publicText = Read-Text $publicPath

# Normalised (LF) copies are used for matching; the original EOL is restored on save.
$hubEol = "`n"; if ($hubText.Contains("`r`n")) { $hubEol = "`r`n" }
$publicEol = "`n"; if ($publicText.Contains("`r`n")) { $publicEol = "`r`n" }
$hubLf = $hubText -replace "`r`n", "`n"
$publicLf = $publicText -replace "`r`n", "`n"

$hubDone = $hubLf.Contains('BusinessShortcuts')
$publicDone = $publicLf.Contains('OwnProfileEditButton')

$hubImportAnchor = "import 'appearance_selector.dart';`n"
$hubInsertAnchor = "          _HubHeader(user: user, audience: audience, business: business),`n"
$publicImportAnchor = "import 'business_profile_public_provider.dart';`n"
$publicAppBarAnchor = "      appBar: AppBar(title: const Text('Business')),`n"

function Count-Occurrences([string]$text, [string]$needle) {
    return ([regex]::Matches($text, [regex]::Escape($needle))).Count
}

if (-not $hubDone) {
    if ((Count-Occurrences $hubLf $hubImportAnchor) -ne 1) { throw "profile_hub_screen.dart: import anchor not found exactly once. Nothing was changed." }
    if ((Count-Occurrences $hubLf $hubInsertAnchor) -ne 1) { throw "profile_hub_screen.dart: header anchor not found exactly once. Nothing was changed." }
}
if (-not $publicDone) {
    if ((Count-Occurrences $publicLf $publicImportAnchor) -ne 1) { throw "business_profile_public_screen.dart: import anchor not found exactly once. Nothing was changed." }
    if ((Count-Occurrences $publicLf $publicAppBarAnchor) -ne 1) { throw "business_profile_public_screen.dart: AppBar anchor not found exactly once. Nothing was changed." }
}

# ---------------- Embedded content ----------------
$sources = @(
    @{ Path = 'lib\features\business_profile\presentation\own_business_id_provider.dart'; Content = @'
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';
import '../domain/business_profile_entity.dart';
import 'business_profile_provider.dart';

/// Part P-113 (STEP 4B): the id of the signed-in user's OWN business, or null.
///
/// Null when nobody is signed in, when the account is not a Business account,
/// or while the own profile is loading, missing or failed. It is derived from
/// the two providers that already exist ([sessionProvider] and
/// [businessProfileProvider]); it adds no request and no polling.
///
/// The public Business profile uses it to decide whether to show the owner's
/// Edit button. It never grants access: the route behind the button is still
/// protected by the router redirect guards.
final ownBusinessIdProvider = Provider.autoDispose<int?>((Ref ref) {
  final AsyncValue<User?> session = ref.watch(sessionProvider);
  final User? user = switch (session) {
    AsyncData(:final value) => value,
    _ => null,
  };
  if (user == null || user.accountType != AccountType.business) {
    return null;
  }

  final AsyncValue<BusinessProfile?> profile = ref.watch(
    businessProfileProvider,
  );
  return switch (profile) {
    AsyncData(:final value) => value?.id,
    _ => null,
  };
});
'@ },
    @{ Path = 'lib\features\business_profile\presentation\own_profile_edit_button.dart'; Content = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../routing/route_names.dart';
import 'own_business_id_provider.dart';

/// Part P-113 (STEP 4B): the owner's Edit action on the public Business
/// profile.
///
/// It is an app bar action. It draws an Edit icon ONLY when [businessId] is
/// the signed-in user's own business ([ownBusinessIdProvider]); for everybody
/// else (customers, staff, other businesses, signed-out, still loading) it
/// draws nothing and takes no space.
///
/// A tap pushes [RouteNames.businessProfileEdit] above the current screen, so
/// back returns to the public profile. Who may open the edit screen is still
/// decided by the router redirect guards, not by this button.
class OwnProfileEditButton extends ConsumerWidget {
  const OwnProfileEditButton({required this.businessId, super.key});

  static const Key buttonKey = Key('own-profile-edit-button');

  /// The business whose public profile is on screen.
  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? ownId = ref.watch(ownBusinessIdProvider);
    if (ownId == null || ownId != businessId) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: buttonKey,
      icon: const Icon(Icons.edit_outlined),
      tooltip: context.l10n.hubEditBusinessProfile,
      onPressed: () => context.pushNamed(RouteNames.businessProfileEdit),
    );
  }
}
'@ },
    @{ Path = 'lib\features\profile_hub\presentation\business_shortcuts.dart'; Content = @'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';

/// Part P-113 (STEP 4B): the Business shortcuts under the header of the
/// Profile & Settings hub (tab 5).
///
/// Four icon buttons - Products, Content, Stories, Analytics - each opening
/// the same screen as the matching row of the "Business tools" group, one tap
/// from the tab. They carry a tooltip (and so an accessibility label) instead
/// of visible text, so the hub does not show the same words twice.
///
/// The hub draws this widget for Business accounts only. A tap pushes the
/// screen above the shell, so back returns to the hub. Who may open those
/// screens is still decided by the router redirect guards.
class BusinessShortcuts extends StatelessWidget {
  const BusinessShortcuts({super.key});

  /// The destinations, in display order.
  static const List<String> routeNames = <String>[
    RouteNames.productList,
    RouteNames.contentList,
    RouteNames.storyList,
    RouteNames.businessAnalytics,
  ];

  /// Key of the shortcut that opens [routeName].
  static Key shortcutKey(String routeName) => Key('hub-shortcut-$routeName');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    Widget shortcut(String routeName, IconData icon, String label) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: IconButton.filledTonal(
          key: shortcutKey(routeName),
          icon: Icon(icon),
          tooltip: label,
          onPressed: () => context.pushNamed(routeName),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: Row(
        children: <Widget>[
          shortcut(
            RouteNames.productList,
            Icons.inventory_2_outlined,
            l10n.hubProducts,
          ),
          shortcut(
            RouteNames.contentList,
            Icons.photo_library_outlined,
            l10n.hubContent,
          ),
          shortcut(
            RouteNames.storyList,
            Icons.auto_stories_outlined,
            l10n.hubStories,
          ),
          shortcut(
            RouteNames.businessAnalytics,
            Icons.insights_outlined,
            l10n.hubAnalytics,
          ),
        ],
      ),
    );
  }
}
'@ },
    @{ Path = 'test\features\business_profile\presentation\own_profile_edit_button_test.dart'; Content = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_provider.dart';
import 'package:social_commerce_app/features/business_profile/presentation/own_business_id_provider.dart';
import 'package:social_commerce_app/features/business_profile/presentation/own_profile_edit_button.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-113 (STEP 4B): the owner's Edit action on the public Business
/// profile, and the provider that decides who the owner is.

class _FakeSession extends SessionNotifier {
  _FakeSession(this._user);

  final User? _user;

  @override
  Future<User?> build() async => _user;
}

class _FakeProfileNotifier extends BusinessProfileNotifier {
  _FakeProfileNotifier(this._profile);

  final BusinessProfile? _profile;

  @override
  Future<BusinessProfile?> build() async => _profile;
}

const User _customer = User(
  id: 1,
  email: 'customer@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

const User _business = User(
  id: 2,
  email: 'business@example.com',
  accountType: AccountType.business,
  isModerator: false,
  isStaff: false,
);

BusinessProfile _profile(int id) {
  return BusinessProfile(
    id: id,
    businessName: 'Roots Atelier',
    businessType: BusinessType.trader,
    country: 'EG',
    city: 'Cairo',
    isVerified: false,
    isFeatured: false,
  );
}

GoRouter _router(int shownBusinessId) {
  return GoRouter(
    initialLocation: '/host',
    routes: <RouteBase>[
      GoRoute(
        path: '/host',
        builder:
            (BuildContext context, GoRouterState state) => Scaffold(
              appBar: AppBar(
                title: const Text('host'),
                actions: <Widget>[
                  OwnProfileEditButton(businessId: shownBusinessId),
                ],
              ),
            ),
      ),
      GoRoute(
        path: RouteNames.businessProfileEditPath,
        name: RouteNames.businessProfileEdit,
        builder:
            (BuildContext context, GoRouterState state) => const Scaffold(
              body: Center(child: Text('stub:businessProfileEdit')),
            ),
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required int? ownId,
  required int shownBusinessId,
}) async {
  final GoRouter router = _router(shownBusinessId);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ownBusinessIdProvider.overrideWithValue(ownId)],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<int?> _ownId(
  User? user,
  BusinessProfile? profile,
) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSession(user)),
      businessProfileProvider.overrideWith(() => _FakeProfileNotifier(profile)),
    ],
  );
  addTearDown(container.dispose);
  final ProviderSubscription<int?> subscription = container.listen<int?>(
    ownBusinessIdProvider,
    (int? previous, int? next) {},
  );
  addTearDown(subscription.close);
  await container.read(sessionProvider.future);
  await container.read(businessProfileProvider.future);
  return container.read(ownBusinessIdProvider);
}

void main() {
  group('P-113 STEP 4B: OwnProfileEditButton', () {
    testWidgets('the owner sees Edit, and it opens the edit screen', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ownId: 5, shownBusinessId: 5);

      expect(find.byKey(OwnProfileEditButton.buttonKey), findsOneWidget);
      expect(find.byTooltip('Edit business profile'), findsOneWidget);

      await tester.tap(find.byKey(OwnProfileEditButton.buttonKey));
      await tester.pumpAndSettle();
      expect(find.text('stub:businessProfileEdit'), findsOneWidget);
    });

    testWidgets('someone looking at ANOTHER business sees no Edit', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ownId: 5, shownBusinessId: 6);
      expect(find.byKey(OwnProfileEditButton.buttonKey), findsNothing);
    });

    testWidgets('a user with no own business sees no Edit', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ownId: null, shownBusinessId: 5);
      expect(find.byKey(OwnProfileEditButton.buttonKey), findsNothing);
    });
  });

  group('P-113 STEP 4B: ownBusinessIdProvider', () {
    test('a Business account with a profile: its business id', () async {
      expect(await _ownId(_business, _profile(7)), 7);
    });

    test('a Business account without a profile yet: null', () async {
      expect(await _ownId(_business, null), isNull);
    });

    test('a Customer account: null, whatever the profile provider holds', () async {
      expect(await _ownId(_customer, _profile(7)), isNull);
    });

    test('nobody signed in: null', () async {
      expect(await _ownId(null, null), isNull);
    });
  });
}
'@ },
    @{ Path = 'test\features\profile_hub\presentation\business_shortcuts_test.dart'; Content = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/business_shortcuts.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/profile_hub_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-113 (STEP 4B): the Business shortcuts under the hub header.
///
/// * each of the four buttons opens its screen, and back returns to the hub;
/// * the hub draws the shortcuts for a Business account only;
/// * they work (and mirror) in Arabic.

class _FakeSession extends SessionNotifier {
  _FakeSession(this._user);

  final User? _user;

  @override
  Future<User?> build() async => _user;
}

const User _customer = User(
  id: 1,
  email: 'customer@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

const User _business = User(
  id: 2,
  email: 'business@example.com',
  accountType: AccountType.business,
  isModerator: false,
  isStaff: false,
);

const User _staff = User(
  id: 3,
  email: 'staff@example.com',
  accountType: AccountType.customer,
  isModerator: true,
  isStaff: false,
);

BusinessProfile _profile() {
  return BusinessProfile(
    id: 1,
    businessName: 'Roots Atelier',
    businessType: BusinessType.trader,
    country: 'EG',
    city: 'Cairo',
    isVerified: false,
    isFeatured: false,
  );
}

GoRouter _stubRouter() {
  GoRoute stub(String name, String path) {
    return GoRoute(
      path: path,
      name: name,
      builder:
          (BuildContext context, GoRouterState state) =>
              Scaffold(body: Center(child: Text('stub:$name'))),
    );
  }

  return GoRouter(
    initialLocation: RouteNames.profilePath,
    routes: <RouteBase>[
      GoRoute(
        path: RouteNames.profilePath,
        name: RouteNames.profile,
        builder:
            (BuildContext context, GoRouterState state) =>
                const ProfileHubScreen(),
      ),
      stub(RouteNames.saved, RouteNames.savedPath),
      stub(RouteNames.moderation, RouteNames.moderationPath),
      stub(
        RouteNames.notificationPreferences,
        RouteNames.notificationPreferencesPath,
      ),
      stub(RouteNames.businessProfileEdit, RouteNames.businessProfileEditPath),
      stub(RouteNames.businessConsole, RouteNames.businessConsolePath),
      stub(RouteNames.productList, RouteNames.productListPath),
      stub(RouteNames.contentList, RouteNames.contentListPath),
      stub(RouteNames.storyList, RouteNames.storyListPath),
      stub(RouteNames.businessAnalytics, RouteNames.businessAnalyticsPath),
    ],
  );
}

Future<void> _pumpHub(
  WidgetTester tester, {
  required User user,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final GoRouter router = _stubRouter();
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _FakeSession(user)),
        hubBusinessProfileProvider.overrideWithValue(
          user.accountType == AccountType.business ? _profile() : null,
        ),
        hubModerationPendingCountProvider.overrideWithValue(0),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('P-113 STEP 4B: Business shortcuts in the hub', () {
    testWidgets('Business: four shortcuts, in order, with their tooltips', (
      WidgetTester tester,
    ) async {
      await _pumpHub(tester, user: _business);

      for (final String routeName in BusinessShortcuts.routeNames) {
        expect(
          find.byKey(BusinessShortcuts.shortcutKey(routeName)),
          findsOneWidget,
          reason: routeName,
        );
      }
      expect(find.byTooltip('Products'), findsOneWidget);
      expect(find.byTooltip('Content'), findsOneWidget);
      expect(find.byTooltip('Stories'), findsOneWidget);
      expect(find.byTooltip('Analytics'), findsOneWidget);
    });

    for (final String routeName in BusinessShortcuts.routeNames) {
      testWidgets('Business: the $routeName shortcut opens it, back returns', (
        WidgetTester tester,
      ) async {
        await _pumpHub(tester, user: _business);

        await tester.tap(find.byKey(BusinessShortcuts.shortcutKey(routeName)));
        await tester.pumpAndSettle();
        expect(find.text('stub:$routeName'), findsOneWidget);

        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        expect(find.byType(ProfileHubScreen), findsOneWidget);
      });
    }

    testWidgets('Customer: no shortcuts', (WidgetTester tester) async {
      await _pumpHub(tester, user: _customer);
      for (final String routeName in BusinessShortcuts.routeNames) {
        expect(
          find.byKey(BusinessShortcuts.shortcutKey(routeName)),
          findsNothing,
          reason: routeName,
        );
      }
    });

    testWidgets('Staff: no shortcuts', (WidgetTester tester) async {
      await _pumpHub(tester, user: _staff);
      for (final String routeName in BusinessShortcuts.routeNames) {
        expect(
          find.byKey(BusinessShortcuts.shortcutKey(routeName)),
          findsNothing,
          reason: routeName,
        );
      }
    });

    testWidgets('Arabic: the shortcuts are drawn and the page is right-to-left', (
      WidgetTester tester,
    ) async {
      await _pumpHub(tester, user: _business, locale: const Locale('ar'));

      for (final String routeName in BusinessShortcuts.routeNames) {
        expect(
          find.byKey(BusinessShortcuts.shortcutKey(routeName)),
          findsOneWidget,
          reason: routeName,
        );
      }
      expect(
        Directionality.of(tester.element(find.byType(BusinessShortcuts))),
        TextDirection.rtl,
      );
    });
  });
}
'@ }
)

# ---------------- 1. Backup ----------------
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path (Split-Path -Parent $root) ("_p113_step4b_backup_" + $stamp)
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
if (-not $hubDone) { Backup-File $hubPath }
if (-not $publicDone) { Backup-File $publicPath }

# ---------------- 2. Write the new files ----------------
$created = @(); $rewritten = @()
foreach ($s in $sources) {
    $target = Join-Path $root $s.Path
    $existed = Test-Path -LiteralPath $target
    Save-Text $target $s.Content
    if ($existed) { $rewritten += $s.Path } else { $created += $s.Path }
    Write-Host ("  wrote " + $s.Path)
}

# ---------------- 3. Patch the two existing files ----------------
$patched = @()

if ($hubDone) {
    Write-Host '  profile_hub_screen.dart already has the shortcuts, skipped.'
} else {
    $new = $hubLf.Replace($hubImportAnchor, $hubImportAnchor + "import 'business_shortcuts.dart';`n")
    $new = $new.Replace(
        $hubInsertAnchor,
        $hubInsertAnchor + "          if (audience == NavAudience.business) const BusinessShortcuts(),`n"
    )
    if (-not $new.Contains('const BusinessShortcuts()')) { throw 'profile_hub_screen.dart patch failed, file NOT written.' }
    $out = $new.Replace("`n", $hubEol)
    [System.IO.File]::WriteAllText($hubPath, $out, $utf8NoBom)
    $patched += 'lib\features\profile_hub\presentation\profile_hub_screen.dart'
    Write-Host '  patched profile_hub_screen.dart'
}

if ($publicDone) {
    Write-Host '  business_profile_public_screen.dart already has the Edit button, skipped.'
} else {
    $appBarNew = "      appBar: AppBar(`n" +
                 "        title: const Text('Business'),`n" +
                 "        actions: <Widget>[OwnProfileEditButton(businessId: id)],`n" +
                 "      ),`n"
    $new = $publicLf.Replace($publicImportAnchor, $publicImportAnchor + "import 'own_profile_edit_button.dart';`n")
    $new = $new.Replace($publicAppBarAnchor, $appBarNew)
    if (-not $new.Contains('OwnProfileEditButton(businessId: id)')) { throw 'business_profile_public_screen.dart patch failed, file NOT written.' }
    $out = $new.Replace("`n", $publicEol)
    [System.IO.File]::WriteAllText($publicPath, $out, $utf8NoBom)
    $patched += 'lib\features\business_profile\presentation\business_profile_public_screen.dart'
    Write-Host '  patched business_profile_public_screen.dart'
}

# ---------------- 4. Summary ----------------
Write-Host ''
Write-Host '================ P-113 STEP 4 / PART B - done ================'
Write-Host 'Created:'
foreach ($p in $created) { Write-Host ("  + " + $p) }
if ($rewritten.Count -gt 0) {
    Write-Host 'Rewritten (already existed):'
    foreach ($p in $rewritten) { Write-Host ("  ~ " + $p) }
}
Write-Host 'Patched (one import + one insertion each):'
foreach ($p in $patched) { Write-Host ("  ~ " + $p) }
Write-Host 'ARB files: not touched (existing hub* keys reused).'
if ($backedUp.Count -gt 0) { Write-Host ("Backup of changed files: " + $backupRoot) }
Write-Host ''
Write-Host 'Next, from the project folder:'
Write-Host '  flutter analyze'
Write-Host '  flutter test test\features\profile_hub test\features\business_profile test\core\shell test\routing'