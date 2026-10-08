<#
  P114-Step3B.ps1
  PART P-114, STEP 3 (part B of 2) of 4: EXPLORE, Instagram style
  (search screen + filter chips + filter sheet + result cards, and the Discover grid).
  (STEP 3A, already applied, was the public business profile.)

  Run from the ROOT of the cavallo-mobile repo (the folder that contains pubspec.yaml),
  in Windows PowerShell or PowerShell 7, on branch part-111 (STEP 1, 2 and 3A already applied):

      powershell -ExecutionPolicy Bypass -File .\P114-Step3B.ps1

  What it does:
    1. Checks you are in the right repo and that STEP 1, 2 and 3A are in place.
    2. CREATES 1 test file (search_p114_test.dart).
    3. REPLACES 5 presentation files (featured_badge, search_result_card, search_filter_panel,
       search_screen, discover_screen) and 1 existing test (discover_screen_test). Each one is first
       compared with the exact version this step was built against; if your copy differs the script
       stops and changes nothing (use -Force to overwrite anyway).
    4. APPENDS 24 new keys to app_en.arb and app_ar.arb.
    5. Runs flutter gen-l10n.
  It is safe to run twice. Nothing is committed: undo everything with
      git checkout -- .
      git clean -fd lib test
#>
param([switch]$SkipGenL10n, [switch]$Force)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Get-Location).Path
$Sep = [System.IO.Path]::DirectorySeparatorChar

function Fail([string]$Message) { Write-Host "ERROR: $Message" -ForegroundColor Red; exit 1 }
function Fix-Rel([string]$RelPath) { return ($RelPath -replace '[\\/]', [string]$Sep) }

if (-not (Test-Path (Join-Path $RepoRoot 'pubspec.yaml'))) { Fail 'pubspec.yaml not found. Run this script from the cavallo-mobile repo root.' }
if (-not (Select-String -Path (Join-Path $RepoRoot 'pubspec.yaml') -Pattern 'name: social_commerce_app' -Quiet)) { Fail 'This is not the social_commerce_app repo.' }
foreach ($required in @(
  'lib\core\widgets\app_avatar.dart','lib\core\widgets\app_shimmer_box.dart','lib\core\widgets\grid_tile_media.dart',
  'lib\core\widgets\app_button.dart','lib\core\widgets\featured_badge.dart',
  'lib\core\l10n\formatters.dart','lib\core\l10n\l10n_context.dart','lib\core\l10n\rtl_helpers.dart',
  'lib\features\search\presentation\search_screen.dart','lib\features\search\presentation\search_result_card.dart',
  'lib\features\search\presentation\search_filter_panel.dart','lib\features\discover\presentation\discover_screen.dart',
  'test\features\business_profile\presentation\business_profile_public_p114_test.dart',
  'lib\l10n\app_en.arb','lib\l10n\app_ar.arb')) {
  if (-not (Test-Path (Join-Path $RepoRoot (Fix-Rel $required)))) { Fail "Missing $required. Are P-114 STEP 1, 2 and 3A applied (branch part-111)?" }
}
if (-not (Select-String -Path (Join-Path $RepoRoot (Fix-Rel 'lib\l10n\app_en.arb')) -Pattern '"profileScreenTitle"' -Quiet)) { Fail 'app_en.arb has no profileScreenTitle key: P-114 STEP 3A is not applied.' }
if (-not (Select-String -Path (Join-Path $RepoRoot (Fix-Rel 'lib\l10n\app_en.arb')) -Pattern '"businessUnknownName"' -Quiet)) { Fail 'app_en.arb has no businessUnknownName key.' }
try { $branch = (git rev-parse --abbrev-ref HEAD).Trim(); Write-Host "Git branch: $branch" } catch { Write-Host 'WARNING: git not available.' -ForegroundColor Yellow }

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function ToCrLf([string]$Text) { return ($Text -replace "`r?`n", "`r`n") }

# The script itself is pure ASCII: a non-ASCII character inside a file body is written as {{U+XXXX}}.
function Expand-U([string]$Text) {
  return [regex]::Replace($Text, '\{\{U\+([0-9A-F]{4})\}\}', { param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) })
}

function Get-TextHash([string]$Text) {
  $lf = $Text -replace "`r`n", "`n"
  $sha = [System.Security.Cryptography.SHA256]::Create()
  return ([System.BitConverter]::ToString($sha.ComputeHash($Utf8NoBom.GetBytes($lf)))).Replace('-', '').ToLower()
}

# Creates the file, or overwrites it when it already exists (safe re-run).
function Write-RepoFile([string]$RelPath, [string]$Content, [bool]$TrailingNewline = $true) {
  $full = Join-Path $RepoRoot (Fix-Rel $RelPath)
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $existed = Test-Path $full
  $text = Expand-U $Content; if ($TrailingNewline) { $text = $text + "`n" }
  [System.IO.File]::WriteAllText($full, (ToCrLf $text), $Utf8NoBom)
  if ($existed) { Write-Host "  UPDATED  $RelPath" } else { Write-Host "  CREATED  $RelPath" }
}

# Replaces an EXISTING file, but only when it is exactly the version this step was built against.
function Replace-RepoFile([string]$RelPath, [string]$ExpectedHash, [string]$Content, [bool]$TrailingNewline) {
  $full = Join-Path $RepoRoot (Fix-Rel $RelPath)
  if (-not (Test-Path $full)) { Fail "Missing $RelPath." }
  $newText = Expand-U $Content; if ($TrailingNewline) { $newText = $newText + "`n" }
  $currentHash = Get-TextHash ([System.IO.File]::ReadAllText($full))
  if ($currentHash -eq (Get-TextHash $newText)) { Write-Host "  SKIPPED  $RelPath (already up to date)"; return }
  if (($currentHash -ne $ExpectedHash) -and (-not $Force)) {
    Fail "$RelPath is not the version STEP 3B was built against (it has local changes, or STEP 2 was not applied exactly). Nothing was changed. Send me this file, or run again with -Force to overwrite it."
  }
  [System.IO.File]::WriteAllText($full, (ToCrLf $newText), $Utf8NoBom)
  Write-Host "  UPDATED  $RelPath"
}

function Patch-Once([string]$RelPath, [string]$Old, [string]$New, [string]$DoneMarker) {
  $full = Join-Path $RepoRoot (Fix-Rel $RelPath)
  $raw = [System.IO.File]::ReadAllText($full)
  $text = $raw -replace "`r`n", "`n"
  $Old = $Old -replace "`r`n", "`n"
  $New = $New -replace "`r`n", "`n"
  $DoneMarker = $DoneMarker -replace "`r`n", "`n"
  if ($text.Contains($DoneMarker)) { Write-Host "  SKIPPED  $RelPath (already patched: $DoneMarker)"; return }
  $pos = $text.IndexOf($Old)
  if ($pos -lt 0) { Fail "Could not find the expected line in $RelPath. Send me that file." }
  if ($text.IndexOf($Old, $pos + 1) -ge 0) { Fail "The expected line appears twice in $RelPath." }
  $text = $text.Substring(0, $pos) + $New + $text.Substring($pos + $Old.Length)
  [System.IO.File]::WriteAllText($full, (ToCrLf $text), $Utf8NoBom)
  Write-Host "  PATCHED  $RelPath"
}

function Add-ArbEntries([string]$RelPath, [string]$MarkerKey, [string]$EntriesText, [int]$KeyCount) {
  $full = Join-Path $RepoRoot (Fix-Rel $RelPath)
  $raw = [System.IO.File]::ReadAllText($full)
  if ($raw.Contains('"' + $MarkerKey + '"')) { Write-Host "  SKIPPED  $RelPath (already contains $MarkerKey)"; return }
  $idx = $raw.LastIndexOf('}')
  if ($idx -lt 0) { Fail "$RelPath has no closing brace." }
  $nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
  $head = $raw.Substring(0, $idx).TrimEnd()
  $tail = $raw.Substring($idx + 1)
  $body = $EntriesText -replace "`r?`n", $nl
  $new = $head + ',' + $nl + $body + $nl + '}' + $tail
  try { $null = $new | ConvertFrom-Json } catch { Fail "Generated JSON for $RelPath is invalid: $($_.Exception.Message)" }
  [System.IO.File]::WriteAllText($full, $new, $Utf8NoBom)
  Write-Host "  UPDATED  $RelPath (+$KeyCount keys)"
}

Write-Host ''
Write-Host '== 1/4 New test file ==' -ForegroundColor Cyan
$newTest1 = @'
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_avatar.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/categories/data/category_repository_impl.dart';
import 'package:social_commerce_app/features/categories/domain/category_entity.dart';
import 'package:social_commerce_app/features/categories/domain/category_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/presentation/product_price_framing.dart';
import 'package:social_commerce_app/features/search/data/search_repository_impl.dart';
import 'package:social_commerce_app/features/search/domain/search_filters.dart';
import 'package:social_commerce_app/features/search/domain/search_page_entity.dart';
import 'package:social_commerce_app/features/search/domain/search_repository.dart';
import 'package:social_commerce_app/features/search/domain/search_result_entity.dart';
import 'package:social_commerce_app/features/search/presentation/search_result_card.dart';
import 'package:social_commerce_app/features/search/presentation/search_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-114 STEP 3B: the Instagram-style Explore search - result card (with
/// and without Featured), the chip row, the skeleton, English LTR / Arabic
/// RTL, light / dark. Data flow and debounce stay covered by
/// `search_screen_test.dart`, `search_provider_test.dart` and
/// `search_filter_panel_test.dart`.
///
/// This file is ASCII only: Arabic text is read from the generated
/// localizations of the `ar` locale, never typed here.

BusinessSearchResult _biz(
  int id, {
  bool featured = false,
  bool verified = false,
  int followers = 12,
}) => BusinessSearchResult(
  BusinessProfile(
    id: id,
    businessName: 'Business $id',
    businessType: BusinessType.trader,
    country: 'Egypt',
    city: 'Cairo',
    isVerified: verified,
    isFeatured: featured,
    followerCount: followers,
  ),
);

ProductSearchResult _prod(int id, {bool featured = false}) =>
    ProductSearchResult(
      Product(
        id: id,
        businessId: 1,
        categoryId: 1,
        name: 'Product $id',
        description: '',
        price: '250.00',
        currency: Currency.egp,
        isFeatured: featured,
      ),
    );

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository({this.page, this.gate});

  final SearchPage? page;
  final Completer<void>? gate;
  int callCount = 0;

  @override
  Future<SearchPage> search({
    String? q,
    SearchFilters filters = const SearchFilters(),
    String? cursor,
  }) async {
    callCount++;
    if (gate != null) {
      await gate!.future;
    }
    return page ?? const SearchPage(items: [], nextCursor: null);
  }
}

class _FakeCategoryRepository implements CategoryRepository {
  @override
  Future<List<CategoryNode>> fetchCategoryTree({
    bool forceRefresh = false,
  }) async => const [];
}

Widget _cards(
  List<SearchResult> results, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  void Function(SearchResult result)? onTap,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme ?? AppTheme.light,
    home: Scaffold(
      body: ListView(
        children: [
          for (final SearchResult r in results)
            SearchResultCard(result: r, onTap: () => onTap?.call(r)),
        ],
      ),
    ),
  );
}

Widget _screen(
  _FakeSearchRepository fake, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      searchRepositoryProvider.overrideWithValue(fake),
      categoryRepositoryProvider.overrideWith(
        (ref) async => _FakeCategoryRepository(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.light,
      home: const SearchScreen(),
    ),
  );
}

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

  group('SearchResultCard', () {
    testWidgets('an organic business row has no Featured badge', (
      tester,
    ) async {
      await tester.pumpWidget(_cards([_biz(1)]));

      expect(find.text('Business 1'), findsOneWidget);
      expect(find.byType(FeaturedBadge), findsNothing);
      expect(find.text('Trader \u2022 Cairo, Egypt'), findsOneWidget);
      expect(find.textContaining('12'), findsWidgets);
      expect(find.byType(AppAvatar), findsOneWidget);
    });

    testWidgets('a Featured business row carries the amber badge and the '
        'word Featured, and organic rows stay fully visible next to it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _cards([_biz(1, featured: true), _biz(2), _biz(3)]),
      );

      expect(find.byType(FeaturedBadge), findsOneWidget);
      expect(find.text('Featured'), findsOneWidget);
      expect(find.text('Business 1'), findsOneWidget);
      expect(find.text('Business 2'), findsOneWidget);
      expect(find.text('Business 3'), findsOneWidget);
    });

    testWidgets('the Verified mark shows only for a verified business', (
      tester,
    ) async {
      await tester.pumpWidget(_cards([_biz(1, verified: true), _biz(2)]));

      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('a Featured product row shows the badge and still frames '
        'the price (P-034)', (tester) async {
      await tester.pumpWidget(_cards([_prod(7, featured: true), _prod(8)]));

      expect(find.byType(FeaturedBadge), findsOneWidget);
      expect(find.text(ProductPriceCopy.note), findsNWidgets(2));
      expect(
        find.text(ProductPriceCopy.headline('250.00', Currency.egp)),
        findsNWidgets(2),
      );
    });

    testWidgets('tapping a row calls onTap with that result', (tester) async {
      final List<int> tapped = <int>[];
      await tester.pumpWidget(
        _cards([_biz(1), _prod(2)], onTap: (r) => tapped.add(r.id)),
      );

      await tester.tap(find.text('Business 1'));
      await tester.tap(find.text('Product 2'));

      expect(tapped, <int>[1, 2]);
    });

    testWidgets('a row is at least 72 logical pixels tall', (tester) async {
      await tester.pumpWidget(_cards([_biz(1)]));

      expect(
        tester.getSize(find.byType(SearchResultCard)).height,
        greaterThanOrEqualTo(72),
      );
    });

    testWidgets('Arabic RTL: avatar at the start (right), chevron at the end '
        '(left), badge text in Arabic', (tester) async {
      await tester.pumpWidget(
        _cards([_biz(1, featured: true)], locale: const Locale('ar')),
      );

      final BuildContext context = tester.element(
        find.byType(SearchResultCard),
      );
      expect(Directionality.of(context), TextDirection.rtl);
      expect(find.text(ar.featuredBadgeLabel), findsOneWidget);
      expect(find.text('Featured'), findsNothing);
      expect(
        tester.getCenter(find.byType(AppAvatar)).dx,
        greaterThan(tester.getCenter(find.byIcon(Icons.chevron_right)).dx),
      );
    });

    testWidgets('dark theme renders both kinds of row without errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _cards([_biz(1, featured: true), _prod(2)], theme: AppTheme.dark),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FeaturedBadge), findsOneWidget);
    });
  });

  group('SearchScreen (P-114 STEP 3B)', () {
    testWidgets('idle: sticky field, one Filters chip, localized prompt', (
      tester,
    ) async {
      await tester.pumpWidget(_screen(_FakeSearchRepository()));
      await tester.pump();

      expect(find.byKey(const Key('searchScreen_queryField')), findsOneWidget);
      expect(find.byKey(const Key('searchScreen_filterButton')), findsOneWidget);
      expect(find.text(en.searchFiltersChip), findsOneWidget);
      expect(find.text(en.searchIdlePrompt), findsOneWidget);
    });

    testWidgets('applying a filter turns it into a chip and shows the count, '
        'and the Filters chip opens the existing panel', (tester) async {
      final fake = _FakeSearchRepository(
        page: SearchPage(items: [_biz(1)], nextCursor: null),
      );
      await tester.pumpWidget(_screen(fake));
      await tester.pump();

      await tester.tap(find.byKey(const Key('searchScreen_filterButton')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('searchFilterPanel_featuredSwitch')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('searchFilterPanel_featuredSwitch')),
      );
      await tester.tap(
        find.byKey(const Key('searchFilterPanel_featuredSwitch')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(en.searchFilterApply));
      await tester.tap(find.text(en.searchFilterApply));
      await tester.pumpAndSettle();

      expect(fake.callCount, 1);
      expect(find.text(en.searchFiltersChipActive(1)), findsOneWidget);
      expect(find.text(en.searchFilterFeaturedOnly), findsOneWidget);
      expect(find.text('Business 1'), findsOneWidget);
    });

    testWidgets('while a search is in flight the list shows skeleton rows, '
        'not a spinner', (tester) async {
      final Completer<void> gate = Completer<void>();
      final fake = _FakeSearchRepository(
        page: SearchPage(items: [_biz(1)], nextCursor: null),
        gate: gate,
      );
      await tester.pumpWidget(_screen(fake));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('searchScreen_queryField')),
        'bag',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(AppShimmerBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Business 1'), findsOneWidget);
      expect(find.byType(AppShimmerBox), findsNothing);
    });

    testWidgets('Featured and organic results both stay in the list, in the '
        'order the server sent them', (tester) async {
      final fake = _FakeSearchRepository(
        page: SearchPage(
          items: [_biz(1, featured: true), _biz(2), _prod(3)],
          nextCursor: null,
        ),
      );
      await tester.pumpWidget(_screen(fake));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('searchScreen_queryField')),
        'x',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byType(FeaturedBadge), findsOneWidget);
      expect(find.text('Business 2'), findsOneWidget);
      expect(find.text('Product 3'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Business 1')).dy,
        lessThan(tester.getTopLeft(find.text('Business 2')).dy),
      );
    });

    testWidgets('Arabic RTL: localized hint and prompt, Filters chip at the '
        'start (right)', (tester) async {
      await tester.pumpWidget(
        _screen(_FakeSearchRepository(), locale: const Locale('ar')),
      );
      await tester.pump();

      final BuildContext context = tester.element(find.byType(SearchScreen));
      expect(Directionality.of(context), TextDirection.rtl);
      expect(find.text(ar.searchFieldHint), findsOneWidget);
      expect(find.text(ar.searchIdlePrompt), findsOneWidget);
      expect(find.text(ar.searchFiltersChip), findsOneWidget);
      expect(
        tester
            .getCenter(find.byKey(const Key('searchScreen_filterButton')))
            .dx,
        greaterThan(400),
      );
    });

    testWidgets('dark theme renders the screen without errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(_FakeSearchRepository(), theme: AppTheme.dark),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(en.searchIdlePrompt), findsOneWidget);
    });
  });
}
'@
Write-RepoFile 'test\features\search\presentation\search_p114_test.dart' $newTest1 $true

Write-Host ''
Write-Host '== 2/4 Replaced files (presentation only) ==' -ForegroundColor Cyan
$fb = @'
import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_colors.dart';

/// Part P-110: the single, reusable, READ-ONLY "Featured" badge (a star icon
/// plus the word "Featured").
///
/// Every screen that shows a business or its content uses THIS widget
/// whenever the backend says the owning business is Featured (real state
/// from P-087): public profile, search results, and Post/Reel cards (which
/// the Home feed, Discover and chat shares all reuse). Do not create a
/// second, slightly different badge elsewhere.
///
/// Display-only (ADR-006): it takes no callback, is not tappable and never
/// leads to any purchase flow. Featured is bought on the future Web
/// Dashboard, never inside this app. Callers decide WHETHER to show it:
///
/// ```dart
/// if (business.isFeatured) const FeaturedBadge(),
/// ```
///
/// Part P-111: amber `featured` fill with the dark `onFeatured` label, taken
/// from [AppColors]. Amber is reserved for Featured/Sponsored so it is never
/// confused with the blue brand or the blue Follow action.
///
/// Part P-114 STEP 3B: the visible word now comes from the ARB files
/// (`featuredBadgeLabel`), so Arabic shows the Arabic word. English is still
/// exactly [label].
class FeaturedBadge extends StatelessWidget {
  const FeaturedBadge({super.key});

  /// The English text. Public so tests can reference it. In another language
  /// the badge shows `featuredBadgeLabel` of that language instead.
  static const String label = 'Featured';

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelSmall;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.featured,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.star, size: 14, color: colors.onFeatured),
          const SizedBox(width: 4),
          Text(
            context.l10n.featuredBadgeLabel,
            style: labelStyle?.copyWith(
              color: colors.onFeatured,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
'@
Replace-RepoFile 'lib\core\widgets\featured_badge.dart' 'bc314d8f2a2a342a0bd771ca5fcfbc8bdebe3f58d51da2febd6196a898abf55f' $fb $true
$src = @'
/// Part P-065 STEP 4 scope: [SearchResultCard] - renders one row of the
/// Search results list, dispatching on [SearchResult]'s two variants
/// (STEP 1). [onTap] is a plain [VoidCallback], not a `context.pushNamed`
/// call made internally - same convention `PostCard`/`ReelCard`
/// (Part P-045) already use, and for the same reason: it keeps this
/// widget free of any `GoRouter` dependency, and lets a widget test
/// verify a tap without needing a real router in the tree.
///
/// ### Price - always through [ProductPriceFraming] (Part P-034)
///
/// The product row's price is rendered ONLY via [ProductPriceFraming]
/// (`products/presentation/product_price_framing.dart`). No new price text is
/// written here.
///
/// ### Business row - only real fields, no invented ones
///
/// `BusinessProfile` has no `rating`/`logo` field today, so this row shows
/// only what the entity carries: name, type, city/country, `isVerified`,
/// `isFeatured` and `followerCount`.
///
/// ### Part P-114 STEP 3B (presentation only)
///
/// * Instagram-style row: [AppAvatar], name with Verified mark and the single
///   [FeaturedBadge], a secondary line, a hairline under the row (no Card).
/// * Featured results carry the amber badge with the word "Featured"; organic
///   results use exactly the same row without it (nothing is hidden or
///   re-ordered here).
/// * Every string comes from the ARB files; counts use [AppFormatters].
/// * Directional layout only; the chevron mirrors in Arabic.
/// * Each row is at least 72 logical pixels tall (tap target >= 44).
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/l10n/rtl_helpers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/featured_badge.dart';
import '../../../core/widgets/grid_tile_media.dart';
import '../../business_profile/domain/business_profile_entity.dart';
import '../../products/domain/product_entity.dart';
import '../../products/presentation/product_price_framing.dart';
import '../domain/search_result_entity.dart';

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({super.key, required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return switch (result) {
      BusinessSearchResult(:final business) => _BusinessResultRow(
        business: business,
        onTap: onTap,
      ),
      ProductSearchResult(:final product) => _ProductResultRow(
        product: product,
        onTap: onTap,
      ),
    };
  }
}

/// The shared frame of both rows: tappable, 72 px minimum, hairline below.
class _ResultRowFrame extends StatelessWidget {
  const _ResultRowFrame({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outline, width: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
            child: Row(
              children: <Widget>[
                Expanded(child: child),
                const SizedBox(width: 8),
                DirectionalIcon(
                  Icons.chevron_right,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessResultRow extends StatelessWidget {
  const _BusinessResultRow({required this.business, required this.onTap});

  final BusinessProfile business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final l10n = context.l10n;
    final AppFormatters formatters = AppFormatters(l10n);

    final String typeLabel = business.businessType == BusinessType.trader
        ? l10n.businessTypeTrader
        : l10n.businessTypeFactory;
    final String locationLabel;
    if (business.city.isNotEmpty && business.country.isNotEmpty) {
      locationLabel = l10n.profileLocation(business.city, business.country);
    } else {
      locationLabel = business.city.isNotEmpty ? business.city : business.country;
    }
    final String subtitle = locationLabel.isEmpty
        ? typeLabel
        : '$typeLabel \u2022 $locationLabel';
    final int followers = business.followerCount;

    return _ResultRowFrame(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          AppAvatar(
            name: business.businessName,
            size: 52,
            ringGapColor: colors.background,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        business.businessName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (business.isVerified) ...<Widget>[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: colors.brand,
                        semanticLabel: l10n.feedVerifiedLabel,
                      ),
                    ],
                    // Part P-110: display-only Featured badge.
                    if (business.isFeatured) ...<Widget>[
                      const SizedBox(width: 6),
                      const FeaturedBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.followersCountLine(
                    followers,
                    formatters.compactCount(followers),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductResultRow extends StatelessWidget {
  const _ProductResultRow({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _ResultRowFrame(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 64,
            height: 64,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GridTileMedia(
                imageUrl: product.imageUrl,
                semanticLabel: product.name,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        product.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Part P-110: display-only; reflects whether the
                    // OWNING BUSINESS is Featured.
                    if (product.isFeatured) ...<Widget>[
                      const SizedBox(width: 6),
                      const FeaturedBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // The ONLY place this row renders a price - always through
                // ProductPriceFraming (Part P-034).
                ProductPriceFraming(
                  price: product.price,
                  currency: product.currency,
                  compact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
'@
Replace-RepoFile 'lib\features\search\presentation\search_result_card.dart' '504e12cf7685a68d3dfbaec41f3eb11e71b990af7fcb77a41bdad7b9cafcd2f8' $src $true
$sfp = @'
/// Part P-065 STEP 4 scope: [SearchFilterPanel] - the filter form shown
/// as a modal bottom sheet from `SearchScreen`. Presented via
/// `showModalBottomSheet<SearchFilters>`; pops the [SearchFilters] the
/// user built ("Apply"), a fresh `const SearchFilters()` ("Clear"), or
/// `null` if dismissed without either (swipe-down/tap-outside) - the
/// caller (`SearchScreen`) treats `null` as "keep whatever filters were
/// already active."
///
/// ### Why a bottom sheet, not an expandable section
///
/// A modal sheet keeps the results list's own scroll position and loaded
/// items completely untouched while filters are being edited, and gives the
/// filter form its own full-height space to lay out.
///
/// ### Category picker - the exact `product_form_screen.dart` (P-033)
/// pattern, duplicated, not imported
///
/// [_flattenCategories] is a private copy of that file's helper of the same
/// name, with one addition: an "All categories" entry mapping to `null`.
///
/// ### Part P-114 STEP 3B (presentation only)
///
/// Same fields, same keys, same result contract, same pops. Changed: every
/// string comes from the ARB files, padding is directional, the section
/// titles use the token text styles, the rating options are formatted by one
/// plural message, and Clear uses the outlined [AppButton] variant.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../categories/domain/category_entity.dart';
import '../../categories/presentation/category_tree_provider.dart';
import '../domain/search_filters.dart';

class SearchFilterPanel extends ConsumerStatefulWidget {
  const SearchFilterPanel({super.key, required this.initialFilters});

  final SearchFilters initialFilters;

  @override
  ConsumerState<SearchFilterPanel> createState() => _SearchFilterPanelState();
}

class _SearchFilterPanelState extends ConsumerState<SearchFilterPanel> {
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  int? _categoryId;
  String? _businessType;
  String? _minRating;
  bool _featuredOnly = false;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilters;
    _countryController = TextEditingController(text: f.country ?? '');
    _cityController = TextEditingController(text: f.city ?? '');
    _categoryId = f.categoryId;
    _businessType = f.businessType;
    _minRating = f.minRating;
    _featuredOnly = f.featuredOnly;
  }

  @override
  void dispose() {
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  SearchFilters _buildFilters() {
    final country = _countryController.text.trim();
    final city = _cityController.text.trim();
    return SearchFilters(
      categoryId: _categoryId,
      country: country.isEmpty ? null : country,
      city: city.isEmpty ? null : city,
      businessType: _businessType,
      minRating: _minRating,
      featuredOnly: _featuredOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryTreeProvider);
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final TextStyle? sectionStyle = theme.textTheme.labelLarge?.copyWith(
      color: colors.textSecondary,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.searchFilterTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _buildCategoryField(categoriesAsync),
              const SizedBox(height: 12),
              AppTextField(
                key: const Key('searchFilterPanel_countryField'),
                label: l10n.searchFilterCountry,
                controller: _countryController,
              ),
              const SizedBox(height: 12),
              AppTextField(
                key: const Key('searchFilterPanel_cityField'),
                label: l10n.searchFilterCity,
                controller: _cityController,
              ),
              const SizedBox(height: 16),
              Text(l10n.searchFilterBusinessType, style: sectionStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: Text(l10n.searchFilterAny),
                    selected: _businessType == null,
                    onSelected: (_) => setState(() => _businessType = null),
                  ),
                  ChoiceChip(
                    label: Text(l10n.businessTypeTrader),
                    selected: _businessType == 'trader',
                    onSelected: (_) =>
                        setState(() => _businessType = 'trader'),
                  ),
                  ChoiceChip(
                    label: Text(l10n.businessTypeFactory),
                    selected: _businessType == 'factory',
                    onSelected: (_) =>
                        setState(() => _businessType = 'factory'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l10n.searchFilterMinRating, style: sectionStyle),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: const Key('searchFilterPanel_minRatingDropdown'),
                value: _minRating,
                isExpanded: true,
                decoration: const InputDecoration(),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.searchFilterAny),
                  ),
                  for (final stars in const <int>[4, 3, 2, 1])
                    DropdownMenuItem(
                      value: '$stars',
                      child: Text(l10n.searchFilterMinRatingOption(stars)),
                    ),
                ],
                onChanged: (value) => setState(() => _minRating = value),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('searchFilterPanel_featuredSwitch'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.searchFilterFeaturedOnly),
                value: _featuredOnly,
                onChanged: (value) => setState(() => _featuredOnly = value),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: l10n.searchFilterClear,
                      variant: AppButtonVariant.outlined,
                      onPressed: () =>
                          Navigator.of(context).pop(const SearchFilters()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: l10n.searchFilterApply,
                      onPressed: () =>
                          Navigator.of(context).pop(_buildFilters()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryField(AsyncValue<List<CategoryNode>> categoriesAsync) {
    final l10n = context.l10n;
    return switch (categoriesAsync) {
      AsyncData(:final value) => DropdownButtonFormField<int?>(
        key: const Key('searchFilterPanel_categoryDropdown'),
        value: _categoryId,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.searchFilterCategory),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(l10n.searchFilterCategoryAll),
          ),
          for (final entry in _flattenCategories(value))
            DropdownMenuItem(
              value: entry.$1.id,
              child: Text(
                '${'\u2014' * entry.$2}${entry.$2 > 0 ? ' ' : ''}${entry.$1.name}',
              ),
            ),
        ],
        onChanged: (id) => setState(() => _categoryId = id),
      ),
      AsyncError() => Row(
        children: [
          Expanded(child: Text(l10n.searchFilterCategoriesFailed)),
          TextButton(
            onPressed: () => ref.invalidate(categoryTreeProvider),
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
    };
  }
}

/// See this file's module docstring - a deliberate, verbatim duplicate
/// of `product_form_screen.dart`'s own private `_flattenCategories`.
List<(CategoryNode, int)> _flattenCategories(
  List<CategoryNode> nodes, [
  int depth = 0,
]) {
  final result = <(CategoryNode, int)>[];
  for (final node in nodes) {
    result.add((node, depth));
    result.addAll(_flattenCategories(node.children, depth + 1));
  }
  return result;
}
'@
Replace-RepoFile 'lib\features\search\presentation\search_filter_panel.dart' 'e35359b8b957ed01bb37c8acc5eb545e31768c0e558e0f68215c7cc50594990d' $sfp $true
$ss = @'
/// Part P-065 STEP 4 scope: the real `/search` screen, replacing Part
/// P-007's placeholder (same file path, same `SearchScreen` class
/// name/no-arg constructor - `app_router.dart`'s existing `GoRoute` for
/// `RouteNames.searchPath` needs no edit at all).
///
/// Wires together `searchProvider` (STEP 3) for state/pagination,
/// [SearchFilterPanel] for filters, and [SearchResultCard] for each row.
///
/// ### Debounce - a plain [Timer], 400ms
///
/// Each keystroke cancels any pending [Timer] and starts a new one; only the
/// LAST one to survive 400ms actually calls `searchProvider.notifier.search`.
///
/// ### Idle vs. "no results" vs. loaded - three distinct states
///
/// [SearchState.hasSearched] tells the idle state (show a "type to search"
/// prompt) apart from a genuine zero-result search (show "No results found").
///
/// ### Retry does NOT use `ref.invalidate`
///
/// `build()` of `searchProvider` fetches nothing, so retry re-calls
/// `search()` with this screen's own remembered text and filters.
///
/// ### Filter panel result contract
///
/// `null` from [SearchFilterPanel] (dismissed without Apply/Clear) means
/// "keep the active filters" - no re-search. Any non-null [SearchFilters]
/// replaces `_filters` and immediately triggers a new search.
///
/// ### Part P-114 STEP 3B (presentation only)
///
/// * The search field sits in the app bar and stays put while the results
///   scroll (sticky).
/// * A horizontal chip row under it: a "Filters" chip (key
///   `searchScreen_filterButton`, with the active count) plus one chip per
///   active filter. Every chip opens the SAME [SearchFilterPanel].
/// * Skeleton rows ([AppShimmerBox]) replace the spinners (first load and
///   load-more).
/// * Results stay a plain list: Featured results carry the amber badge,
///   organic results are listed exactly the same way, in server order.
/// * Every string comes from the ARB files.
/// No provider, repository, route or callback changed.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../routing/route_names.dart';
import '../domain/search_filters.dart';
import '../domain/search_result_entity.dart';
import 'search_filter_panel.dart';
import 'search_provider.dart';
import 'search_result_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _debounceDuration = Duration(milliseconds: 400);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  SearchFilters _filters = const SearchFilters();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Identical 80%-of-scrollable-extent threshold as `HomeFeedScreen`/
  /// `DiscoverScreen` - `loadMore()` is already idempotent/no-op while a
  /// load is in flight or once `nextCursor` is `null`.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    final threshold = position.maxScrollExtent * 0.8;
    if (position.pixels >= threshold) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  void _runSearch() {
    final q = _searchController.text.trim();
    ref
        .read(searchProvider.notifier)
        .search(q: q.isEmpty ? null : q, filters: _filters);
  }

  void _onQueryChanged(String value) {
    // Refreshes the clear-icon visibility only - the actual search
    // fires from the Timer below, after the debounce window.
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _runSearch);
  }

  Future<void> _openFilterPanel() async {
    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SearchFilterPanel(initialFilters: _filters),
    );
    // null means "dismissed without Apply/Clear" - see this file's
    // module docstring ("Filter panel result contract").
    if (result == null || !mounted) return;
    setState(() => _filters = result);
    _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(searchProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsetsDirectional.only(end: 16),
          child: TextField(
            key: const Key('searchScreen_queryField'),
            controller: _searchController,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: l10n.searchFieldHint,
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.searchClearTooltip,
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _FilterChipsRow(filters: _filters, onOpen: _openFilterPanel),
          Expanded(
            child: switch (searchAsync) {
              AsyncData(value: final state) => _SearchResultsList(
                state: state,
                scrollController: _scrollController,
              ),
              AsyncError() => ErrorStateWidget(
                message: l10n.searchLoadFailed,
                onRetry: _runSearch,
              ),
              _ => const _ResultsSkeleton(),
            },
          ),
        ],
      ),
    );
  }
}

/// The horizontal chip row under the search field. Every chip opens the
/// existing filter panel; the active ones show what is applied.
class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({required this.filters, required this.onOpen});

  final SearchFilters filters;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String? country = filters.country;
    final String? city = filters.city;
    final String? rating = filters.minRating;
    final int? ratingStars = rating == null ? null : int.tryParse(rating);

    final List<String> active = <String>[
      if (filters.categoryId != null) l10n.searchFilterCategory,
      if (country != null) country,
      if (city != null) city,
      if (filters.businessType == 'trader') l10n.businessTypeTrader,
      if (filters.businessType == 'factory') l10n.businessTypeFactory,
      if (rating != null)
        ratingStars == null
            ? rating
            : l10n.searchFilterMinRatingOption(ratingStars),
      if (filters.featuredOnly) l10n.searchFilterFeaturedOnly,
    ];

    final List<Widget> chips = <Widget>[
      ActionChip(
        key: const Key('searchScreen_filterButton'),
        avatar: const Icon(Icons.tune, size: 18),
        label: Text(
          active.isEmpty
              ? l10n.searchFiltersChip
              : l10n.searchFiltersChipActive(active.length),
        ),
        onPressed: onOpen,
      ),
      for (final String label in active)
        FilterChip(
          label: Text(label),
          selected: true,
          showCheckmark: false,
          onSelected: (_) => onOpen(),
        ),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 6),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => Center(child: chips[index]),
      ),
    );
  }
}

/// The loaded results section - idle prompt, "no results", or the
/// paginated list. See this file's module docstring for the
/// idle/"no results" distinction via [SearchState.hasSearched].
class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.state,
    required this.scrollController,
  });

  final SearchState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (!state.hasSearched) {
      return EmptyStateWidget(
        message: l10n.searchIdlePrompt,
        icon: Icons.search,
      );
    }

    if (state.items.isEmpty) {
      return EmptyStateWidget(
        message: l10n.searchNoResults,
        icon: Icons.search_off,
      );
    }

    final itemCount = state.items.length + (state.isLoadingMore ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const _ResultSkeletonRow();
        }
        return _SearchListItem(result: state.items[index]);
      },
    );
  }
}

/// One row of the results list - dispatches to `context.pushNamed` for
/// the correct existing screen. See `SearchResultCard`'s own docstring
/// for why the navigation call lives here rather than inside that card.
class _SearchListItem extends StatelessWidget {
  const _SearchListItem({required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    return SearchResultCard(
      result: result,
      onTap: () => switch (result) {
        BusinessSearchResult(:final business) => context.pushNamed(
          RouteNames.businessProfile,
          pathParameters: {RouteNames.idParam: business.id.toString()},
        ),
        ProductSearchResult(:final product) => context.pushNamed(
          RouteNames.productDetail,
          pathParameters: {RouteNames.idParam: product.id.toString()},
        ),
      },
    );
  }
}

/// First-load placeholder: skeleton rows with the same shape as a result row.
class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.searchResultsLoadingLabel,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        itemBuilder: (context, index) => const _ResultSkeletonRow(),
      ),
    );
  }
}

class _ResultSkeletonRow extends StatelessWidget {
  const _ResultSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
      child: Row(
        children: <Widget>[
          AppShimmerBox.circle(size: 52),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppShimmerBox(width: 160, height: 14, borderRadius: 4),
                SizedBox(height: 8),
                AppShimmerBox(width: 110, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
'@
Replace-RepoFile 'lib\features\search\presentation\search_screen.dart' '6fd797f0b056bd56cdc79d2300d02514d2fb5708c167afab0f0dc50a102148d7' $ss $true
$ds = @'
/// Part P-062 scope (STEP 5): the real `/discover` screen, replacing
/// Part P-007's placeholder (same file path, same `DiscoverScreen`
/// class name/constructor - `app_router.dart`'s existing `GoRoute` for
/// `RouteNames.discoverPath` needs no edit at all).
///
/// Composes [StoriesBarWidget] as the first item of one single scrollable,
/// with the Recommended/general-content section - backed by
/// `discoverFeedProvider` - filling the rest. One [ScrollController] and one
/// [RefreshIndicator] cover both, so the 80%-threshold infinite-scroll and
/// pull-to-refresh behavior mirror `HomeFeedScreen` (Part P-061) exactly.
///
/// ### Pull-to-refresh refreshes BOTH sections
///
/// [_handleRefresh] awaits `discoverFeedProvider.notifier.refresh()` AND
/// synchronously calls `ref.invalidate(activeStoryGroupsProvider)` so the
/// stories bar re-fetches too.
///
/// ### Same known pull-to-refresh trade-off as Home
///
/// `refresh()` sets `state` to a bare `AsyncValue.loading()`, so the
/// top-level `switch` briefly shows the skeleton during a manual pull.
///
/// ### Part P-114 STEP 3B (presentation only)
///
/// * The Recommended section is a 3-column grid of square tiles (posts and
///   reels mixed, in server order) instead of full cards: Explore is for
///   browsing, the card is one tap away. A reel tile carries the video badge.
/// * A tile of a Featured business carries the single [FeaturedBadge]; tiles
///   of other businesses are listed exactly the same way.
/// * Skeleton tiles ([AppShimmerBox]) replace the spinners (first load and
///   load-more).
/// * Taps open the SAME routes as before (`postDetail` / `reelDetail`); each
///   tile still resolves its own business name through
///   `businessProfilePublicProvider` for its screen-reader label.
/// * Test hooks: each tile is wrapped in a `ValueKey('discover-post-<id>')` /
///   `ValueKey('discover-reel-<id>')`.
/// No provider, repository, route or callback changed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/featured_badge.dart';
import '../../../core/widgets/grid_tile_media.dart';
import '../../../routing/route_names.dart';
import '../../business_profile/presentation/business_profile_public_provider.dart';
import '../../feed/domain/feed_item_entity.dart';
import '../../feed/presentation/home_feed_provider.dart' show FeedState;
import 'discover_provider.dart';
import 'discover_search_bar.dart';
import 'stories_bar_widget.dart';

/// 3 equal columns with a thin gap, like the profile grids.
const SliverGridDelegate _gridDelegate =
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
    );

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Identical 80%-of-scrollable-extent threshold as `HomeFeedScreen`
  /// (Part P-061) - see that screen's own docstring for why
  /// `loadMore()` itself needs no separate in-flight guard here.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    final threshold = position.maxScrollExtent * 0.8;
    if (position.pixels >= threshold) {
      ref.read(discoverFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(discoverFeedProvider);

    return Scaffold(
      // Part P-113 (STEP 6A): the title is the search entry point.
      appBar: AppBar(title: const DiscoverSearchBar()),
      body: switch (feedAsync) {
        AsyncData(value: final state) => _DiscoverBody(
          state: state,
          scrollController: _scrollController,
        ),
        AsyncError() => const _LoadErrorView(),
        _ => const _DiscoverSkeleton(),
      },
    );
  }
}

/// The loaded (or loading-more) Recommended section, with
/// [StoriesBarWidget] as the first sliver of the same scrollable - see this
/// file's own doc above for why both sit under one `RefreshIndicator`/
/// `ScrollController` pair rather than two separate scroll regions.
class _DiscoverBody extends ConsumerWidget {
  const _DiscoverBody({required this.state, required this.scrollController});

  final FeedState state;
  final ScrollController scrollController;

  Future<void> _handleRefresh(WidgetRef ref) {
    ref.invalidate(activeStoryGroupsProvider);
    return ref.read(discoverFeedProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleRefresh() => _handleRefresh(ref);
    final l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsetsDirectional.only(top: 12, bottom: 12),
              child: StoriesBarWidget(),
            ),
          ),
          if (state.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                message: l10n.discoverEmpty,
                icon: Icons.explore_outlined,
              ),
            )
          else ...<Widget>[
            SliverGrid(
              gridDelegate: _gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) =>
                    _DiscoverTile(item: state.items[index]),
                childCount: state.items.length,
              ),
            ),
            if (state.isLoadingMore)
              SliverGrid(
                gridDelegate: _gridDelegate,
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) =>
                      const AppShimmerBox(borderRadius: 0),
                  childCount: 3,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One Recommended-section tile. Resolves its own business name through
/// `businessProfilePublicProvider` (Part P-029) independently of every other
/// tile - used for the screen-reader label - then opens the same detail
/// route the card used to open.
class _DiscoverTile extends ConsumerWidget {
  const _DiscoverTile({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profileAsync = ref.watch(
      businessProfilePublicProvider(item.businessId),
    );
    final businessName = switch (profileAsync) {
      AsyncData(value: final profile) =>
        profile?.businessName ?? l10n.businessUnknownName,
      _ => '',
    };

    final Key key;
    final Widget tile;
    final bool featured;
    switch (item) {
      case PostFeedItem(:final post):
        key = ValueKey<String>('discover-post-${post.id}');
        featured = post.isFeatured;
        tile = GridTileMedia(
          imageUrl: post.imageUrl,
          semanticLabel: l10n.feedPostMediaLabel(businessName),
          onTap: () => context.pushNamed(
            RouteNames.postDetail,
            pathParameters: {RouteNames.idParam: '${post.id}'},
          ),
        );
      case ReelFeedItem(:final reel):
        key = ValueKey<String>('discover-reel-${reel.id}');
        featured = reel.isFeatured;
        tile = GridTileMedia(
          imageUrl: reel.thumbnailUrl,
          badge: GridTileBadge.video,
          semanticLabel: l10n.feedReelMediaLabel(businessName),
          onTap: () => context.pushNamed(
            RouteNames.reelDetail,
            pathParameters: {RouteNames.idParam: '${reel.id}'},
          ),
        );
    }

    return KeyedSubtree(
      key: key,
      child: featured
          ? Stack(
              fit: StackFit.expand,
              children: <Widget>[
                tile,
                const PositionedDirectional(
                  bottom: 6,
                  start: 6,
                  child: FeaturedBadge(),
                ),
              ],
            )
          : tile,
    );
  }
}

/// First-load placeholder: a grid of skeleton tiles (no spinner).
class _DiscoverSkeleton extends StatelessWidget {
  const _DiscoverSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.profileGridLoadingLabel,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: _gridDelegate,
        itemCount: 18,
        itemBuilder: (BuildContext context, int index) =>
            const AppShimmerBox(borderRadius: 0),
      ),
    );
  }
}

/// A genuine first-load failure - retryable, same convention as
/// `HomeFeedScreen._LoadErrorView`: `discoverFeedProvider` also has
/// automatic retry disabled, so this button is the only thing that retries.
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      message: context.l10n.discoverLoadFailed,
      onRetry: () => ref.invalidate(discoverFeedProvider),
    );
  }
}
'@
Replace-RepoFile 'lib\features\discover\presentation\discover_screen.dart' 'bb0d464c9cad19188287c8d6771a655610653cbf4085841e2f3ce554d0182e1d' $ds $true
$dst = @'
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';
import 'package:social_commerce_app/features/discover/data/discover_repository.dart';
import 'package:social_commerce_app/features/discover/domain/active_story_group_entity.dart';
import 'package:social_commerce_app/features/discover/domain/discover_repository.dart';
import 'package:social_commerce_app/features/discover/presentation/discover_screen.dart';
import 'package:social_commerce_app/features/feed/domain/feed_item_entity.dart';
import 'package:social_commerce_app/features/feed/domain/feed_page_entity.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-062 scope (STEP 6 tests). Hand-rolled fakes only, mirroring
/// `home_feed_screen_test.dart`'s (Part P-061) exact convention {{U+2014}} no
/// mockito/mocktail anywhere in this project. `_FakeDiscoverRepository`
/// folds BOTH `DiscoverRepository` methods into one fake (unlike
/// `home_feed_screen_test.dart`'s single-method `_FakeFeedRepository`),
/// since `DiscoverScreen` composes both `activeStoryGroupsProvider` and
/// `discoverFeedProvider` {{U+2014}} each call is counted separately so the
/// pull-to-refresh group below can assert BOTH were actually re-hit.
class _FakeDiscoverRepository implements DiscoverRepository {
  _FakeDiscoverRepository({required this.pages, this.groups = const []});

  /// Keyed by the cursor that should return it (`null` = first page) {{U+2014}}
  /// same convention as `home_feed_screen_test.dart`'s `_FakeFeedRepository.pages`.
  final Map<String?, FeedPage> pages;

  List<ActiveStoryGroup> groups;

  int feedCallCount = 0;
  int groupsCallCount = 0;
  final List<String?> cursorsRequested = [];

  /// When set, the first `fetchDiscoverFeed` call blocks on this instead
  /// of resolving {{U+2014}} lets a test observe the initial [LoadingIndicator]
  /// deterministically, same purpose as the Home Feed test's own gate.
  Completer<void>? firstCallGate;

  /// When set, every `fetchDiscoverFeed` call throws this instead of
  /// resolving.
  Object? error;

  @override
  Future<List<ActiveStoryGroup>> fetchActiveStoryGroups() async {
    groupsCallCount++;
    return groups;
  }

  @override
  Future<FeedPage> fetchDiscoverFeed({String? cursor}) async {
    feedCallCount++;
    cursorsRequested.add(cursor);
    if (feedCallCount == 1 && firstCallGate != null) {
      await firstCallGate!.future;
    }
    if (error != null) {
      throw error!;
    }
    final page = pages[cursor];
    if (page == null) {
      throw StateError('Unexpected cursor requested: $cursor');
    }
    return page;
  }
}

class _FakeBusinessProfilePublicRepository
    implements BusinessProfilePublicRepository {
  _FakeBusinessProfilePublicRepository(this.namesById);

  final Map<int, String> namesById;

  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async {
    final name = namesById[id];
    if (name == null) return null;
    return BusinessProfile(
      id: id,
      businessName: name,
      businessType: BusinessType.trader,
      country: 'Egypt',
      city: 'Cairo',
      isVerified: false,
    );
  }
}

/// Fixes the bug this replaced version had: `StoryRingWidget` (used
/// inside `StoriesBarWidget`) independently watches `businessStoriesProvider`,
/// which calls the REAL `storyPublicRepositoryProvider` unless it is
/// also overridden here {{U+2014}} leaving it un-overridden made the ring hit
/// live HTTP through `dioClientProvider` (blocked/400 under
/// `flutter_test`'s `HttpClient`), so the ring never rendered
/// `businessName` and every assertion on it failed. Copied verbatim
/// from `stories_bar_widget_test.dart` (STEP 4)'s own
/// `_FakeStoryPublicRepository` {{U+2014}} same fake, not a new one.
class _FakeStoryPublicRepository implements StoryPublicRepository {
  _FakeStoryPublicRepository(this.storiesByBusiness);

  final Map<int, List<PublicStory>> storiesByBusiness;

  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async {
    return PaginatedResponse<PublicStory>(
      results: storiesByBusiness[businessId] ?? [],
      next: null,
      previous: null,
    );
  }

  @override
  Future<void> recordView(int storyId) async {}
}

PostFeedItem _post(int id, {int businessId = 1}) => PostFeedItem(
  PublicPost(id: id, businessId: businessId, caption: 'Post caption $id'),
);

ReelFeedItem _reel(int id, {int businessId = 1}) => ReelFeedItem(
  PublicReel(id: id, businessId: businessId, caption: 'Reel caption $id'),
);

PublicStory _story(int id, int businessId) => PublicStory(
  id: id,
  businessId: businessId,
  mediaUrl: 'https://cdn.example.com/stories/$id.jpg',
  publishedAt: DateTime(2026, 1, 1),
  expiresAt: DateTime(2026, 1, 2),
);

/// No `GoRouter` in this tree, deliberately {{U+2014}} same choice
/// `home_feed_screen_test.dart` makes: nothing in this file taps a
/// `PostCard`/`ReelCard`/story ring (each of those already has its own
/// dedicated navigation test {{U+2014}} `stories_bar_widget_test.dart`, STEP 4 {{U+2014}}
/// so `context.pushNamed` is never actually invoked here), so a real
/// router is unnecessary scaffolding for what this file covers.
Widget _wrap(
  _FakeDiscoverRepository discoverRepository, {
  Map<int, String> businessNames = const {1: 'Test Business'},
  Map<int, List<PublicStory>> storiesByBusiness = const {},
  Locale? locale,
}) {
  return ProviderScope(
    overrides: [
      discoverRepositoryProvider.overrideWithValue(discoverRepository),
      businessProfilePublicRepositoryProvider.overrideWithValue(
        _FakeBusinessProfilePublicRepository(businessNames),
      ),
      // Required whenever a test's `groups` puts a business in the
      // stories bar {{U+2014}} see `_FakeStoryPublicRepository`'s own doc above
      // for why this was the actual bug, not `discoverRepositoryProvider`.
      storyPublicRepositoryProvider.overrideWithValue(
        _FakeStoryPublicRepository(storiesByBusiness),
      ),
    ],
    // Part P-114 STEP 3B: [locale] is only given by the RTL tests; every
    // other test keeps the bare English fallback it always had.
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: locale == null
          ? null
          : AppLocalizations.localizationsDelegates,
      supportedLocales: locale == null
          ? const [Locale('en', 'US')]
          : AppLocalizations.supportedLocales,
      home: const DiscoverScreen(),
    ),
  );
}

/// A tall, narrow surface so `maxScrollExtent` is reliably > 0 for the
/// scroll/refresh groups below {{U+2014}} same convention as
/// `home_feed_screen_test.dart`'s own `_useTallSurface`.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('loading, empty and error states', () {
    testWidgets('shows a loading indicator while the first page is in flight', (
      tester,
    ) async {
      final fake = _FakeDiscoverRepository(
        pages: {null: FeedPage(items: [_post(1)], nextCursor: null)},
      )..firstCallGate = Completer<void>();

      await tester.pumpWidget(_wrap(fake));
      await tester.pump();

      // Part P-114 STEP 3B: a grid of skeleton tiles replaces the spinner.
      expect(find.byType(AppShimmerBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      fake.firstCallGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('discover-post-1')), findsOneWidget);
    });

    testWidgets(
      'an all-empty Recommended section shows the empty state',
      (tester) async {
        final fake = _FakeDiscoverRepository(
          pages: {null: const FeedPage(items: [], nextCursor: null)},
        );

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Nothing to discover yet'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a first-load failure shows the error state with a Retry that reloads',
      (tester) async {
        final fake = _FakeDiscoverRepository(
          pages: {null: FeedPage(items: [_post(1)], nextCursor: null)},
        )..error = StateError('backend exploded');

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(find.text('Could not load Discover right now.'), findsOneWidget);
        expect(fake.feedCallCount, 1);

        // "Fix the backend", then retry.
        fake.error = null;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey<String>('discover-post-1')), findsOneWidget);
        expect(find.text('Could not load Discover right now.'), findsNothing);
      },
    );
  });

  group('infinite scroll', () {
    testWidgets(
      'scrolling near the bottom of the list triggers loadMore() and '
      'appends the next page',
      (tester) async {
        _useTallSurface(tester);

        // Part P-114 STEP 3B: 3 tiles per row, so 30 items (10 rows) are
        // needed to be taller than the 800 px test surface.
        final page1Items = List.generate(30, (i) => _post(i + 1));
        final fake = _FakeDiscoverRepository(
          pages: {
            null: FeedPage(items: page1Items, nextCursor: 'cursor-a'),
            'cursor-a': FeedPage(items: [_post(99)], nextCursor: null),
          },
        );

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(fake.cursorsRequested, [null]);
        expect(find.byKey(const ValueKey<String>('discover-post-99'), skipOffstage: false), findsNothing);

        // Drag the list well past 80% of its scroll extent.
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, -4000),
          3000,
        );
        await tester.pumpAndSettle();

        expect(fake.cursorsRequested, [null, 'cursor-a']);
        expect(find.byKey(const ValueKey<String>('discover-post-99'), skipOffstage: false), findsOneWidget);
      },
    );
  });

  group('pull to refresh', () {
    testWidgets(
      'pull-to-refresh discards local Recommended state and REPLACES the '
      'list with a fresh first page, rather than appending to it',
      (tester) async {
        _useTallSurface(tester);

        final fake = _FakeDiscoverRepository(
          pages: {
            null: FeedPage(
              items: [_post(1), _post(2)],
              nextCursor: 'cursor-a',
            ),
          },
        );

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey<String>('discover-post-1')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('discover-post-2')), findsOneWidget);

        // The next `fetchDiscoverFeed(cursor: null)` call (triggered by
        // the refresh below) returns a DIFFERENT first page {{U+2014}} if
        // refresh() appended instead of replacing, both pages' items
        // would be visible together afterwards.
        fake.pages[null] = FeedPage(items: [_post(7)], nextCursor: null);

        await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey<String>('discover-post-7')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('discover-post-1')), findsNothing);
        expect(find.byKey(const ValueKey<String>('discover-post-2')), findsNothing);
        expect(fake.cursorsRequested, [null, null]);
      },
    );

    testWidgets(
      'pull-to-refresh ALSO re-fetches the stories bar '
      '(activeStoryGroupsProvider is invalidated, not just discoverFeedProvider)',
      (tester) async {
        _useTallSurface(tester);

        final fake = _FakeDiscoverRepository(
          pages: {null: FeedPage(items: [_post(1)], nextCursor: null)},
          groups: [
            ActiveStoryGroup(businessId: 5, stories: [_story(1, 5)]),
          ],
        );

        await tester.pumpWidget(
          _wrap(
            fake,
            businessNames: {1: 'Test Business', 5: 'Alpha Traders'},
            storiesByBusiness: {
              5: [_story(1, 5)],
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alpha Traders'), findsOneWidget);
        expect(fake.groupsCallCount, 1);

        // With the stories bar actually rendering a ring, there are now
        // Part P-114 STEP 3B: the outer scrollable is now one
        // `CustomScrollView` (stories sliver + grid sliver), the one
        // `RefreshIndicator` wraps; `StoriesBarWidget`'s own horizontal
        // `ListView.separated` is a different widget type, so there is
        // exactly one match.
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, 300),
          1000,
        );
        await tester.pumpAndSettle();

        expect(fake.groupsCallCount, 2);
        // The business still has an active story after the "refresh",
        // so its ring is still there {{U+2014}} this asserts the invalidate
        // actually re-ran the fetch, not merely that nothing crashed.
        expect(find.text('Alpha Traders'), findsOneWidget);
      },
    );
  });

  group('mixed content', () {
    testWidgets('renders both post and reel items as grid tiles', (
      tester,
    ) async {
      _useTallSurface(tester);

      final fake = _FakeDiscoverRepository(
        pages: {
          null: FeedPage(items: [_post(1), _reel(2)], nextCursor: null),
        },
      );

      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('discover-post-1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('discover-reel-2')), findsOneWidget);
    });
  });

  group('composition with the stories bar', () {
    testWidgets(
      'the stories bar renders above the Recommended section, both from '
      'the same screen',
      (tester) async {
        _useTallSurface(tester);

        final fake = _FakeDiscoverRepository(
          pages: {null: FeedPage(items: [_post(1)], nextCursor: null)},
          groups: [
            ActiveStoryGroup(businessId: 5, stories: [_story(1, 5)]),
          ],
        );

        await tester.pumpWidget(
          _wrap(
            fake,
            businessNames: {1: 'Test Business', 5: 'Alpha Traders'},
            storiesByBusiness: {
              5: [_story(1, 5)],
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alpha Traders'), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('discover-post-1')), findsOneWidget);
      },
    );

    testWidgets(
      'no active story groups -> the bar renders nothing, but the '
      'Recommended section still renders normally',
      (tester) async {
        final fake = _FakeDiscoverRepository(
          pages: {null: FeedPage(items: [_post(1)], nextCursor: null)},
        );

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(find.byType(CircleAvatar), findsNothing);
        expect(find.byKey(const ValueKey<String>('discover-post-1')), findsOneWidget);
      },
    );
  });

  group('P-114 STEP 3B: 3-column grid', () {
    Finder post(int id) => find.byKey(ValueKey<String>('discover-post-$id'));
    Finder reel(int id) => find.byKey(ValueKey<String>('discover-reel-$id'));

    testWidgets('tiles are laid out 3 per row, all the same size', (
      tester,
    ) async {
      _useTallSurface(tester);
      final fake = _FakeDiscoverRepository(
        pages: {
          null: FeedPage(
            items: [for (var i = 1; i <= 6; i++) _post(i)],
            nextCursor: null,
          ),
        },
      );

      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      final first = tester.getTopLeft(post(1));
      expect(tester.getTopLeft(post(2)).dy, first.dy);
      expect(tester.getTopLeft(post(3)).dy, first.dy);
      expect(tester.getTopLeft(post(4)).dy, greaterThan(first.dy));
      expect(tester.getTopLeft(post(2)).dx, greaterThan(first.dx));
      expect(tester.getSize(post(1)), tester.getSize(post(5)));
      expect(tester.getSize(post(1)).width, tester.getSize(post(1)).height);
    });

    testWidgets('a reel tile carries the video badge, a post tile does not', (
      tester,
    ) async {
      _useTallSurface(tester);
      final fake = _FakeDiscoverRepository(
        pages: {
          null: FeedPage(items: [_post(1), _reel(2)], nextCursor: null),
        },
      );

      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: reel(2),
          matching: find.byIcon(Icons.play_arrow),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: post(1),
          matching: find.byIcon(Icons.play_arrow),
        ),
        findsNothing,
      );
    });

    testWidgets('only tiles of a Featured business carry the Featured badge, '
        'and every tile stays in the grid', (tester) async {
      _useTallSurface(tester);
      final fake = _FakeDiscoverRepository(
        pages: {
          null: FeedPage(
            items: [
              _post(1),
              PostFeedItem(
                PublicPost(
                  id: 2,
                  businessId: 1,
                  caption: 'Post caption 2',
                  isFeatured: true,
                ),
              ),
              _post(3),
            ],
            nextCursor: null,
          ),
        },
      );

      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: post(2), matching: find.byType(FeaturedBadge)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: post(1), matching: find.byType(FeaturedBadge)),
        findsNothing,
      );
      expect(post(1), findsOneWidget);
      expect(post(3), findsOneWidget);
    });

    testWidgets('Arabic RTL: the first tile is at the right edge', (
      tester,
    ) async {
      _useTallSurface(tester);
      final fake = _FakeDiscoverRepository(
        pages: {
          null: FeedPage(items: [_post(1), _post(2)], nextCursor: null),
        },
      );

      await tester.pumpWidget(_wrap(fake, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(DiscoverScreen));
      expect(Directionality.of(context), TextDirection.rtl);
      expect(
        tester.getTopLeft(post(1)).dx,
        greaterThan(tester.getTopLeft(post(2)).dx),
      );
    });

    testWidgets('Arabic: the empty state is localized', (tester) async {
      final fake = _FakeDiscoverRepository(
        pages: {null: const FeedPage(items: [], nextCursor: null)},
      );

      await tester.pumpWidget(_wrap(fake, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(
        find.text(lookupAppLocalizations(const Locale('ar')).discoverEmpty),
        findsOneWidget,
      );
    });
  });
}
'@
Replace-RepoFile 'test\features\discover\presentation\discover_screen_test.dart' 'be2a2d6a3e0a3917f7700ffaeb97aa180be6ac90483634fdd23ba22347448e46' $dst $true

Write-Host ''
Write-Host '== 3/4 ARB files ==' -ForegroundColor Cyan
$enEntries = @'
  "featuredBadgeLabel": "Featured",
  "@featuredBadgeLabel": {
    "description": "Text of the amber Featured badge (Featured / Sponsored businesses)."
  },
  "searchFieldHint": "Search traders, factories, products...",
  "@searchFieldHint": {
    "description": "Hint of the search field on the Search screen."
  },
  "searchClearTooltip": "Clear search",
  "@searchClearTooltip": {
    "description": "Tooltip / screen-reader label of the clear button inside the search field."
  },
  "searchFiltersChip": "Filters",
  "@searchFiltersChip": {
    "description": "Search screen: label of the chip that opens the filter sheet (no filter active)."
  },
  "searchFiltersChipActive": "Filters ({count})",
  "@searchFiltersChipActive": {
    "description": "Search screen: label of the chip that opens the filter sheet when some filters are active. count is how many.",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "searchIdlePrompt": "Search for traders, factories, and products.\nType a keyword or set a filter to get started.",
  "@searchIdlePrompt": {
    "description": "Search screen: prompt before any search was made."
  },
  "searchNoResults": "No results found. Try a different search or adjust your filters.",
  "@searchNoResults": {
    "description": "Search screen: a search finished with zero results."
  },
  "searchLoadFailed": "Could not load search results.",
  "@searchLoadFailed": {
    "description": "Search screen: error message when a search fails."
  },
  "searchResultsLoadingLabel": "Loading results",
  "@searchResultsLoadingLabel": {
    "description": "Screen-reader label of the skeleton rows shown while search results load."
  },
  "discoverEmpty": "Nothing to discover yet.\nCheck back soon for new businesses.",
  "@discoverEmpty": {
    "description": "Discover screen: empty state."
  },
  "discoverLoadFailed": "Could not load Discover right now.",
  "@discoverLoadFailed": {
    "description": "Discover screen: error message when the first load fails."
  },
  "searchFilterTitle": "Filters",
  "@searchFilterTitle": {
    "description": "Title of the filter bottom sheet."
  },
  "searchFilterCategory": "Category",
  "@searchFilterCategory": {
    "description": "Filter sheet: label of the category field; also the text of the category chip when a category filter is active."
  },
  "searchFilterCategoryAll": "All categories",
  "@searchFilterCategoryAll": {
    "description": "Filter sheet: the dropdown entry meaning no category filter."
  },
  "searchFilterCategoriesFailed": "Could not load categories.",
  "@searchFilterCategoriesFailed": {
    "description": "Filter sheet: the category list failed to load."
  },
  "searchFilterCountry": "Country",
  "@searchFilterCountry": {
    "description": "Filter sheet: country field label."
  },
  "searchFilterCity": "City",
  "@searchFilterCity": {
    "description": "Filter sheet: city field label."
  },
  "searchFilterBusinessType": "Business type",
  "@searchFilterBusinessType": {
    "description": "Filter sheet: title of the business type chips."
  },
  "searchFilterAny": "Any",
  "@searchFilterAny": {
    "description": "Filter sheet: the option meaning no restriction (business type, rating)."
  },
  "searchFilterMinRating": "Minimum rating",
  "@searchFilterMinRating": {
    "description": "Filter sheet: title of the minimum rating dropdown."
  },
  "searchFilterMinRatingOption": "{stars, plural, one{{stars} star & up} other{{stars} stars & up}}",
  "@searchFilterMinRatingOption": {
    "description": "Filter sheet: one option of the minimum rating dropdown, also the text of the rating chip. stars is 1 to 4.",
    "placeholders": {
      "stars": {
        "type": "int"
      }
    }
  },
  "searchFilterFeaturedOnly": "Featured only",
  "@searchFilterFeaturedOnly": {
    "description": "Filter sheet: label of the Featured-only switch; also the text of its chip."
  },
  "searchFilterClear": "Clear",
  "@searchFilterClear": {
    "description": "Filter sheet: button that resets every filter."
  },
  "searchFilterApply": "Apply",
  "@searchFilterApply": {
    "description": "Filter sheet: button that applies the filters."
  }
'@
$arEntries = @'
  "featuredBadgeLabel": "\u0645\u0645\u064a\u0651\u0632",
  "searchFieldHint": "\u0627\u0628\u062d\u062b \u0639\u0646 \u062a\u062c\u0627\u0631 \u0648\u0645\u0635\u0627\u0646\u0639 \u0648\u0645\u0646\u062a\u062c\u0627\u062a...",
  "searchClearTooltip": "\u0645\u0633\u062d \u0627\u0644\u0628\u062d\u062b",
  "searchFiltersChip": "\u0627\u0644\u0641\u0644\u0627\u062a\u0631",
  "searchFiltersChipActive": "\u0627\u0644\u0641\u0644\u0627\u062a\u0631 ({count})",
  "searchIdlePrompt": "\u0627\u0628\u062d\u062b \u0639\u0646 \u062a\u062c\u0627\u0631 \u0648\u0645\u0635\u0627\u0646\u0639 \u0648\u0645\u0646\u062a\u062c\u0627\u062a.\n\u0627\u0643\u062a\u0628 \u0643\u0644\u0645\u0629 \u0623\u0648 \u0627\u062e\u062a\u0631 \u0641\u0644\u062a\u0631\u064b\u0627 \u0644\u0644\u0628\u062f\u0621.",
  "searchNoResults": "\u0644\u0645 \u064a\u062a\u0645 \u0627\u0644\u0639\u062b\u0648\u0631 \u0639\u0644\u0649 \u0646\u062a\u0627\u0626\u062c. \u062c\u0631\u0651\u0628 \u0628\u062d\u062b\u064b\u0627 \u0645\u062e\u062a\u0644\u0641\u064b\u0627 \u0623\u0648 \u0639\u062f\u0651\u0644 \u0627\u0644\u0641\u0644\u0627\u062a\u0631.",
  "searchLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0646\u062a\u0627\u0626\u062c \u0627\u0644\u0628\u062d\u062b.",
  "searchResultsLoadingLabel": "\u062c\u0627\u0631\u064d \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0646\u062a\u0627\u0626\u062c",
  "discoverEmpty": "\u0644\u0627 \u064a\u0648\u062c\u062f \u0645\u0627 \u064a\u0645\u0643\u0646 \u0627\u0643\u062a\u0634\u0627\u0641\u0647 \u0628\u0639\u062f.\n\u0639\u062f \u0642\u0631\u064a\u0628\u064b\u0627 \u0644\u062a\u0631\u0649 \u0623\u0646\u0634\u0637\u0629 \u062a\u062c\u0627\u0631\u064a\u0629 \u062c\u062f\u064a\u062f\u0629.",
  "discoverLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0635\u0641\u062d\u0629 \u0627\u0644\u0627\u0633\u062a\u0643\u0634\u0627\u0641 \u0627\u0644\u0622\u0646.",
  "searchFilterTitle": "\u0627\u0644\u0641\u0644\u0627\u062a\u0631",
  "searchFilterCategory": "\u0627\u0644\u062a\u0635\u0646\u064a\u0641",
  "searchFilterCategoryAll": "\u0643\u0644 \u0627\u0644\u062a\u0635\u0646\u064a\u0641\u0627\u062a",
  "searchFilterCategoriesFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u062a\u0635\u0646\u064a\u0641\u0627\u062a.",
  "searchFilterCountry": "\u0627\u0644\u062f\u0648\u0644\u0629",
  "searchFilterCity": "\u0627\u0644\u0645\u062f\u064a\u0646\u0629",
  "searchFilterBusinessType": "\u0646\u0648\u0639 \u0627\u0644\u0646\u0634\u0627\u0637",
  "searchFilterAny": "\u0627\u0644\u0643\u0644",
  "searchFilterMinRating": "\u0627\u0644\u062d\u062f \u0627\u0644\u0623\u062f\u0646\u0649 \u0644\u0644\u062a\u0642\u064a\u064a\u0645",
  "searchFilterMinRatingOption": "{stars, plural, one{\u0646\u062c\u0645\u0629 \u0641\u0623\u0643\u062b\u0631} two{\u0646\u062c\u0645\u062a\u0627\u0646 \u0641\u0623\u0643\u062b\u0631} few{{stars} \u0646\u062c\u0648\u0645 \u0641\u0623\u0643\u062b\u0631} other{{stars} \u0646\u062c\u0645\u0629 \u0641\u0623\u0643\u062b\u0631}}",
  "searchFilterFeaturedOnly": "\u0627\u0644\u0645\u0645\u064a\u0651\u0632 \u0641\u0642\u0637",
  "searchFilterClear": "\u0645\u0633\u062d",
  "searchFilterApply": "\u062a\u0637\u0628\u064a\u0642"
'@
Add-ArbEntries 'lib\l10n\app_en.arb' 'featuredBadgeLabel' $enEntries 24
Add-ArbEntries 'lib\l10n\app_ar.arb' 'featuredBadgeLabel' $arEntries 24

Write-Host ''
Write-Host '== 4/4 flutter gen-l10n ==' -ForegroundColor Cyan
if ($SkipGenL10n) {
  Write-Host '  skipped (-SkipGenL10n). Run: flutter gen-l10n'
} else {
  flutter gen-l10n
  if ($LASTEXITCODE -ne 0) { Fail 'flutter gen-l10n failed. Send me the output.' }
}

Write-Host ''
Write-Host 'STEP 3B applied. Next: flutter analyze, then the tests listed in the message.' -ForegroundColor Green