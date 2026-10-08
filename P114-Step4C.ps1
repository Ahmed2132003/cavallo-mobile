<#
  P114-Step4C.ps1
  PART P-114, STEP 4 (part C of 3) of 4: GOLDEN TESTS + PROGRESS NOTES + MANUAL CHECK LIST.
  (STEP 4A = product detail, STEP 4B = comments sheet: already applied.)

  Run from the ROOT of the cavallo-mobile repo (the folder that contains pubspec.yaml),
  on branch part-111 with STEP 4B applied:

      powershell -ExecutionPolicy Bypass -File .\P114-Step4C.ps1

  What it does:
    1. Checks the repo and that STEP 4B is in place.
    2. CREATES test\goldens\p114_goldens_test.dart: 6 subjects x 4 combinations
       (English LTR / Arabic RTL x Light / Dark) = 28 golden images:
         post card (4), reel card (4), story ring unseen (4) + seen (4),
         business profile header (4), search result card Featured + organic (4),
         product detail header (4).
    3. CREATES P114-Step4C-PROGRESS-UPDATE.md (text to paste into PROJECT_PROGRESS.md,
       plus the manual four-combination checklist).
    4. Unless -SkipRun: runs  flutter test --update-goldens test\goldens  (writes the PNG files
       under test\goldens\p114\) and then  flutter test test\goldens  (must pass WITHOUT update).
  It does NOT change anything under lib\ : presentation tests only.
  Safe to run twice (the test file is overwritten; the goldens are regenerated).
  Nothing is committed: undo with  git checkout -- .  and  git clean -fd test
#>
param([switch]$SkipRun)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Get-Location).Path
$Sep = [System.IO.Path]::DirectorySeparatorChar

function Fail([string]$Message) { Write-Host "ERROR: $Message" -ForegroundColor Red; exit 1 }
function Fix-Rel([string]$RelPath) { return ($RelPath -replace '[\\/]', [string]$Sep) }

if (-not (Test-Path (Join-Path $RepoRoot 'pubspec.yaml'))) { Fail 'pubspec.yaml not found. Run this script from the cavallo-mobile repo root.' }
if (-not (Select-String -Path (Join-Path $RepoRoot 'pubspec.yaml') -Pattern 'name: social_commerce_app' -Quiet)) { Fail 'This is not the social_commerce_app repo.' }
foreach ($required in @(
  'lib\core\theme\app_theme.dart',
  'lib\core\widgets\featured_badge.dart',
  'lib\features\content\presentation\post_card.dart',
  'lib\features\content\presentation\reel_card.dart',
  'lib\features\stories\presentation\story_ring_widget.dart',
  'lib\features\business_profile\presentation\business_profile_public_screen.dart',
  'lib\features\search\presentation\search_result_card.dart',
  'lib\features\products\presentation\product_detail_screen.dart',
  'test\features\social\fake_social_interaction_repository.dart',
  'test\features\social\comments_sheet_p114_test.dart',
  'test\features\products\presentation\product_detail_p114_test.dart')) {
  if (-not (Test-Path (Join-Path $RepoRoot (Fix-Rel $required)))) { Fail "Missing $required. Are you on branch part-111 with STEP 4A and 4B applied?" }
}
try { $branch = (git rev-parse --abbrev-ref HEAD).Trim(); Write-Host "Git branch: $branch" } catch { Write-Host 'WARNING: git not available.' -ForegroundColor Yellow }

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function ToCrLf([string]$Text) { return ($Text -replace "`r?`n", "`r`n") }
function Write-RepoFile([string]$RelPath, [string]$Content) {
  $full = Join-Path $RepoRoot (Fix-Rel $RelPath)
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $existed = Test-Path $full
  [System.IO.File]::WriteAllText($full, (ToCrLf ($Content + "`n")), $Utf8NoBom)
  if ($existed) { Write-Host "  UPDATED  $RelPath" } else { Write-Host "  CREATED  $RelPath" }
}

Write-Host '== 1/3 Golden test file =='

$goldenTest = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_public_screen.dart';
import 'package:social_commerce_app/features/business_profile/presentation/own_business_id_provider.dart';
import 'package:social_commerce_app/features/content/data/post_public_repository.dart';
import 'package:social_commerce_app/features/content/data/reel_public_repository.dart';
import 'package:social_commerce_app/features/content/domain/post_public_repository.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';
import 'package:social_commerce_app/features/content/domain/reel_public_repository.dart';
import 'package:social_commerce_app/features/content/presentation/post_card.dart';
import 'package:social_commerce_app/features/content/presentation/reel_card.dart';
import 'package:social_commerce_app/features/products/data/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_variant_entity.dart';
import 'package:social_commerce_app/features/products/presentation/product_detail_screen.dart';
import 'package:social_commerce_app/features/search/domain/search_result_entity.dart';
import 'package:social_commerce_app/features/search/presentation/search_result_card.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/presentation/story_public_provider.dart';
import 'package:social_commerce_app/features/stories/presentation/story_ring_widget.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import '../features/social/fake_social_interaction_repository.dart';

/// Part P-114 STEP 4C: golden images of the restyled content surfaces, in the
/// four combinations English LTR / Arabic RTL x Light / Dark.
///
/// Images live in `test/goldens/p114/`. To (re)create them after an intended
/// visual change:
///
///     flutter test --update-goldens test/goldens
///
/// and review the PNG files before committing them. A plain
/// `flutter test test/goldens` compares against the committed images.
///
/// Everything is offline: no network image is ever requested, the data comes
/// from fakes, and no timestamp is shown (relative time would change daily).
/// This file is ASCII only.

class _Combo {
  const _Combo(this.tag, this.locale, this.dark);

  final String tag;
  final Locale locale;
  final bool dark;

  ThemeData get theme => dark ? AppTheme.dark : AppTheme.light;
}

const List<_Combo> _combos = <_Combo>[
  _Combo('en_light', Locale('en'), false),
  _Combo('en_dark', Locale('en'), true),
  _Combo('ar_light', Locale('ar'), false),
  _Combo('ar_dark', Locale('ar'), true),
];

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _expectGolden(String name) {
  return expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('p114/$name.png'),
  );
}

Widget _app(_Combo c, Widget home, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: c.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: c.theme,
      home: home,
    ),
  );
}

// ---------------------------------------------------------------- fakes

class _StoryRepo implements StoryPublicRepository {
  _StoryRepo(this.stories);

  final List<PublicStory> stories;

  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async {
    return PaginatedResponse<PublicStory>(
      results: stories,
      next: null,
      previous: null,
    );
  }

  @override
  Future<void> recordView(int storyId) async {}
}

PublicStory _story(int id) => PublicStory(
  id: id,
  businessId: 1,
  mediaUrl: 'https://example.com/story-$id.jpg',
  publishedAt: DateTime(2026, 1, 1),
  expiresAt: DateTime(2026, 1, 2),
);

class _ProfileRepo implements BusinessProfilePublicRepository {
  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async => _profile;
}

class _ProfileProductRepo implements ProductPublicRepository {
  @override
  Future<Product?> fetchPublicProduct(int id) async => null;

  @override
  Future<PaginatedResponse<Product>> fetchBusinessProducts(
    int businessId,
  ) async => const PaginatedResponse<Product>(
    results: <Product>[
      Product(
        id: 1,
        businessId: 7,
        categoryId: 1,
        name: 'Leather bag',
        description: '',
        price: '100.00',
        currency: Currency.egp,
      ),
    ],
    next: null,
    previous: null,
  );
}

class _ProfilePostRepo implements PostPublicRepository {
  @override
  Future<PublicPost?> fetchPublicPost(int id) async => null;

  @override
  Future<PaginatedResponse<PublicPost>> fetchBusinessPosts(
    int businessId,
  ) async => const PaginatedResponse<PublicPost>(
    results: <PublicPost>[
      PublicPost(id: 501, businessId: 7, caption: 'One.'),
      PublicPost(id: 502, businessId: 7, caption: 'Two.'),
      PublicPost(id: 503, businessId: 7, caption: 'Three.'),
    ],
    next: null,
    previous: null,
  );
}

class _ProfileReelRepo implements ReelPublicRepository {
  @override
  Future<PublicReel?> fetchPublicReel(int id) async => null;

  @override
  Future<PaginatedResponse<PublicReel>> fetchBusinessReels(
    int businessId,
  ) async => const PaginatedResponse<PublicReel>(
    results: <PublicReel>[],
    next: null,
    previous: null,
  );
}

class _NoStoriesRepo implements StoryPublicRepository {
  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async => const PaginatedResponse<PublicStory>(
    results: <PublicStory>[],
    next: null,
    previous: null,
  );

  @override
  Future<void> recordView(int storyId) async {}
}

const BusinessProfile _profile = BusinessProfile(
  id: 7,
  businessName: 'Al Ananka Store',
  businessType: BusinessType.trader,
  country: 'Egypt',
  city: 'Cairo',
  description: 'Fashion and accessories.',
  phoneNumber: '+201000000000',
  isVerified: true,
  followerCount: 12,
);

class _DetailProductRepo implements ProductPublicRepository {
  @override
  Future<Product?> fetchPublicProduct(int id) async => _detailProduct;

  @override
  Future<PaginatedResponse<Product>> fetchBusinessProducts(int businessId) {
    throw UnimplementedError('not used by ProductDetailScreen');
  }
}

const Product _detailProduct = Product(
  id: 10,
  businessId: 7,
  categoryId: 3,
  name: 'Cotton T-Shirt',
  description: 'Plain white cotton t-shirt.',
  price: '199.99',
  currency: Currency.egp,
  isFeatured: true,
  variants: <ProductVariant>[ProductVariant(id: 1, name: 'Size', value: 'Large')],
);

BusinessSearchResult _biz(int id, {bool featured = false}) =>
    BusinessSearchResult(
      BusinessProfile(
        id: id,
        businessName: 'Business $id',
        businessType: BusinessType.trader,
        country: 'Egypt',
        city: 'Cairo',
        isVerified: true,
        isFeatured: featured,
        followerCount: 12,
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

// ---------------------------------------------------------------- goldens

void main() {
  group('P-114 goldens', () {
    for (final _Combo c in _combos) {
      testWidgets('post card (${c.tag})', (tester) async {
        _size(tester, const Size(400, 700));
        await tester.pumpWidget(
          _app(
            c,
            const Scaffold(
              body: SingleChildScrollView(
                child: PostCard(
                  post: PublicPost(
                    id: 701,
                    businessId: 7,
                    caption: 'New arrivals just landed.',
                    likesCount: 128,
                    commentsCount: 9,
                    isFeatured: true,
                  ),
                  businessName: 'Al Ananka Store',
                  isBusinessVerified: true,
                ),
              ),
            ),
            overrides: [
              socialInteractionRepositoryProvider.overrideWithValue(
                FakeSocialInteractionRepository(),
              ),
            ],
          ),
        );
        await tester.pump();
        await _expectGolden('post_card_${c.tag}');
      });

      testWidgets('reel card (${c.tag})', (tester) async {
        _size(tester, const Size(400, 1000));
        await tester.pumpWidget(
          _app(
            c,
            const Scaffold(
              body: SingleChildScrollView(
                child: ReelCard(
                  reel: PublicReel(
                    id: 801,
                    businessId: 7,
                    caption: 'Behind the scenes.',
                    likesCount: 2300,
                    commentsCount: 41,
                  ),
                  businessName: 'Al Ananka Store',
                  isBusinessVerified: true,
                ),
              ),
            ),
            overrides: [
              socialInteractionRepositoryProvider.overrideWithValue(
                FakeSocialInteractionRepository(),
              ),
            ],
          ),
        );
        await tester.pump();
        await _expectGolden('reel_card_${c.tag}');
      });

      for (final bool seen in <bool>[false, true]) {
        final String state = seen ? 'seen' : 'unseen';
        testWidgets('story ring $state (${c.tag})', (tester) async {
          _size(tester, const Size(240, 140));
          final ProviderContainer container = ProviderContainer(
            overrides: [
              storyPublicRepositoryProvider.overrideWithValue(
                _StoryRepo(<PublicStory>[_story(101)]),
              ),
            ],
          );
          addTearDown(container.dispose);
          container.listen(viewedStoriesProvider(1), (_, __) {});
          if (seen) {
            container.read(viewedStoriesProvider(1).notifier).state =
                <int>{101};
          }
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: c.locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: c.theme,
                home: const Scaffold(
                  body: Center(
                    child: StoryRingWidget(
                      businessId: 1,
                      businessName: 'Alpha Traders',
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          await _expectGolden('story_ring_${state}_${c.tag}');
        });
      }

      testWidgets('business profile header (${c.tag})', (tester) async {
        _size(tester, const Size(400, 900));
        await tester.pumpWidget(
          _app(
            c,
            const BusinessProfilePublicScreen(businessId: '7'),
            overrides: [
              businessProfilePublicRepositoryProvider.overrideWithValue(
                _ProfileRepo(),
              ),
              productPublicRepositoryProvider.overrideWithValue(
                _ProfileProductRepo(),
              ),
              postPublicRepositoryProvider.overrideWithValue(
                _ProfilePostRepo(),
              ),
              reelPublicRepositoryProvider.overrideWithValue(
                _ProfileReelRepo(),
              ),
              storyPublicRepositoryProvider.overrideWithValue(
                _NoStoriesRepo(),
              ),
              socialInteractionRepositoryProvider.overrideWithValue(
                FakeSocialInteractionRepository(),
              ),
              ownBusinessIdProvider.overrideWithValue(null),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await _expectGolden('business_profile_header_${c.tag}');
      });

      testWidgets('search result card, Featured and organic (${c.tag})', (
        tester,
      ) async {
        _size(tester, const Size(400, 480));
        await tester.pumpWidget(
          _app(
            c,
            Scaffold(
              body: ListView(
                children: <Widget>[
                  SearchResultCard(result: _biz(1, featured: true), onTap: () {}),
                  SearchResultCard(result: _biz(2), onTap: () {}),
                  SearchResultCard(result: _prod(3, featured: true), onTap: () {}),
                  SearchResultCard(result: _prod(4), onTap: () {}),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await _expectGolden('search_result_card_${c.tag}');
      });

      testWidgets('product detail header (${c.tag})', (tester) async {
        _size(tester, const Size(400, 800));
        await tester.pumpWidget(
          _app(
            c,
            const ProductDetailScreen(productId: '10'),
            overrides: [
              productPublicRepositoryProvider.overrideWithValue(
                _DetailProductRepo(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await _expectGolden('product_detail_header_${c.tag}');
      });
    }
  });
}
'@

Write-RepoFile 'test\goldens\p114_goldens_test.dart' $goldenTest

Write-Host '== 2/3 Progress update + manual checklist =='

$progress = @'
### P-114 - STEP 4C (goldens + closing notes) - PASTE THIS AT THE END OF PROJECT_PROGRESS.md

Status: P-114 code is DONE through STEP 4C. P-114 is NOT yet marked COMPLETE: the manual
four-combination walk-through (below) has not been recorded. Mark COMPLETE only after it.

What STEP 4C added (tests only, nothing under lib\ changed)
- New: test\goldens\p114_goldens_test.dart. 6 subjects x 4 combinations (English LTR / Arabic RTL
  x Light / Dark): post card, reel card, story ring (unseen and seen), business profile header,
  search result card (Featured + organic rows in one list), product detail header.
  = 28 PNG files under test\goldens\p114\ (named <subject>_<en|ar>_<light|dark>.png).
- Regenerate after an intended visual change: flutter test --update-goldens test\goldens
  (review the PNGs, then commit them). Plain flutter test test\goldens compares to the commit.
- Goldens use no network, no timestamp (relative time would change daily) and fakes only.

Where the other P-114 test requirements live (already green before 4C)
- Story viewer tap zones in LTR and RTL: test\features\stories\presentation\story_viewer_rtl_and_hold_test.dart
- Action row callbacks: test\features\social\content_action_row_p114_test.dart (+ content_action_row_test.dart)
- Follow button states: test\features\social\follow_button_test.dart
- Comments sheet: test\features\social\comments_sheet_p114_test.dart (4B)
- Product detail: test\features\products\presentation\product_detail_p114_test.dart (4A)

Existing tests changed by STEP 4A (assert removed visual details, documented)
- Loading: CircularProgressIndicator replaced by AppShimmerBox (skeleton required by the part).
- Product detail now has two AppBar IconButtons (Save + Share) instead of one; ButtonStyleButton
  counts changed accordingly (3 instead of 2 overall, 2 instead of 1 in the AppBar). The body still
  has exactly one button (Message Business).

Known issues (carry to P-115 / follow-up)
- Product Save icon starts as "not saved": the Product entity has no isSaved field, so a product that
  is already saved shows the empty bookmark until tapped. Saving is idempotent on the server, so the end
  state is correct. Fixing the initial icon needs a DTO/provider change (out of scope for P-114).
- Product detail shows no Availability: the Product entity has no availability field; nothing was invented.
- Product price is still the raw backend text (Western digits), per the P-034 rule. AppFormatters.price
  would break existing tests (it drops ".00").
- Golden images are generated on the developer's machine (Windows). If CI runs on another OS, regenerate
  there or the comparison may differ by font rasterization.
- Carried from P-113: BusinessConsoleScreen placeholder hardcoded English + "Back to splash" button
  (P-115 scope); confirm the Language selector PATCHes preferred_language on /api/v1/auth/me/ before the
  P-115 l10n sweep.

GitHub: cavallo-mobile, branch part-111: STEP 1 = 24683f2; STEP 3 = 9fbe551; STEP 3A = 766470c;
STEP 3B = 0597d87; STEP 4A = 3c74f5d; STEP 4B = 78994f2; STEP 4C = (add the hash after pushing).
(STEP 2 and its two fixes are in the history between 24683f2 and 9fbe551; check git log.)

Manual check to record (real device, 4 combinations: Light/EN, Light/AR, Dark/EN, Dark/AR)
For each combination tick: [ ] Home feed + stories tray (skeleton while loading, pull to refresh)
[ ] Story viewer (tap zones: in Arabic the reading-start side = right side goes BACK, left goes FORWARD;
    hold = pause; swipe down = close) [ ] Post card (Like, Comment sheet, Share, Save, caption "more")
[ ] Reel card [ ] Business profile (stats, Follow/Message, 4 tabs, Info) [ ] Explore (sticky search, chips,
    filter bottom sheet, Featured badge + organic results visible) [ ] Product detail (Message Business is
    the only primary action, no cart/buy anywhere, Save/Share) [ ] Comments sheet (input above keyboard)
Result: ______ (fill in; list anything that failed).

Remaining work
- Run the manual check above and record it; then mark P-114 COMPLETE.
- Exact next starting point after that: P-115 (chat, notifications, business console, moderation
  restyle + final QA sweep). Keep every navigation manifest entry and keep
  test\routing\navigation_reachability_test.dart green.
'@

Write-RepoFile 'P114-Step4C-PROGRESS-UPDATE.md' $progress

Write-Host '== 3/3 Goldens =='
if ($SkipRun) {
  Write-Host 'SkipRun: not running flutter. Next commands:'
  Write-Host '  flutter test --update-goldens test\goldens'
  Write-Host '  flutter test test\goldens'
} else {
  Write-Host 'Generating golden images (flutter test --update-goldens test\goldens) ...'
  & flutter test --update-goldens test\goldens
  if ($LASTEXITCODE -ne 0) { Fail 'flutter test --update-goldens failed. Send me the output.' }
  $pngs = @(Get-ChildItem -Path (Join-Path $RepoRoot 'test\goldens\p114') -Filter '*.png' -ErrorAction SilentlyContinue)
  Write-Host ("  PNG files written: " + $pngs.Count + " (expected 28)")
  Write-Host 'Comparing (flutter test test\goldens, no update) ...'
  & flutter test test\goldens
  if ($LASTEXITCODE -ne 0) { Fail 'Golden comparison failed right after generating. Send me the output.' }
}

Write-Host ''
Write-Host 'STEP 4C applied.' -ForegroundColor Green
Write-Host 'Next: flutter analyze ; open test\goldens\p114 and LOOK at the images ; run the manual check.'