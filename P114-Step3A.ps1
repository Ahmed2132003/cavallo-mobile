<#
  P114-Step3A.ps1
  PART P-114, STEP 3 (part A of 2) of 4: the public BUSINESS PROFILE, Instagram style.
  (STEP 3B, next, is Explore: search, discover, filters, result cards.)

  Run from the ROOT of the cavallo-mobile repo (the folder that contains pubspec.yaml),
  in Windows PowerShell or PowerShell 7, on branch part-111 (STEP 1 and STEP 2 already applied):

      powershell -ExecutionPolicy Bypass -File .\P114-Step3A.ps1

  What it does:
    1. Checks you are in the right repo and that STEP 1 and STEP 2 are in place.
    2. CREATES 1 test file.
    3. REPLACES app_button.dart, follow_button.dart, business_profile_public_screen.dart and
       business_profile_public_content_section_test.dart. Each one is first compared with the exact
       version this step was built against; if your copy differs the script stops and changes
       nothing (use -Force to overwrite anyway).
    4. PATCHES business_profile_public_screen_test.dart (small, documented edits).
    5. APPENDS 30 new keys to app_en.arb and app_ar.arb.
    6. Runs flutter gen-l10n.
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
  'lib\core\widgets\app_avatar.dart','lib\core\widgets\app_shimmer_box.dart','lib\core\widgets\stat_item.dart',
  'lib\core\widgets\profile_tab_bar.dart','lib\core\widgets\grid_tile_media.dart','lib\core\widgets\app_button.dart',
  'lib\core\l10n\formatters.dart','lib\core\l10n\l10n_context.dart',
  'lib\features\business_profile\presentation\business_profile_public_screen.dart',
  'lib\features\social\presentation\follow_button.dart',
  'lib\l10n\app_en.arb','lib\l10n\app_ar.arb')) {
  if (-not (Test-Path (Join-Path $RepoRoot (Fix-Rel $required)))) { Fail "Missing $required. Are P-114 STEP 1 and STEP 2 applied (branch part-111)?" }
}
if (-not (Select-String -Path (Join-Path $RepoRoot (Fix-Rel 'lib\l10n\app_en.arb')) -Pattern '"feedLoadingLabel"' -Quiet)) { Fail 'app_en.arb has no feedLoadingLabel key: P-114 STEP 2 is not applied.' }
if (-not (Select-String -Path (Join-Path $RepoRoot (Fix-Rel 'lib\l10n\app_en.arb')) -Pattern '"storyRingNewLabel"' -Quiet)) { Fail 'app_en.arb has no storyRingNewLabel key.' }
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
    Fail "$RelPath is not the version STEP 3A was built against (it has local changes, or STEP 2 was not applied exactly). Nothing was changed. Send me this file, or run again with -Force to overwrite it."
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
Write-Host '== 1/5 New test file ==' -ForegroundColor Cyan
$newTest1 = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/core/widgets/grid_tile_media.dart';
import 'package:social_commerce_app/core/widgets/profile_tab_bar.dart';
import 'package:social_commerce_app/core/widgets/stat_item.dart';
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
import 'package:social_commerce_app/features/products/data/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_public_repository.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import '../../social/fake_social_interaction_repository.dart';

/// Part P-114 STEP 3: the Instagram-style layout of the public business
/// profile, in English (LTR) and Arabic (RTL). The data and error behavior
/// stays covered by `business_profile_public_screen_test.dart` and
/// `business_profile_public_content_section_test.dart`.
///
/// This file is ASCII only: Arabic text is written as \uXXXX escapes.

class _ProfileRepo implements BusinessProfilePublicRepository {
  _ProfileRepo(this.profile);

  final BusinessProfile profile;

  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async => profile;
}

class _ProductRepo implements ProductPublicRepository {
  _ProductRepo(this.products);

  final List<Product> products;

  @override
  Future<Product?> fetchPublicProduct(int id) async => null;

  @override
  Future<PaginatedResponse<Product>> fetchBusinessProducts(
    int businessId,
  ) async => PaginatedResponse<Product>(
    results: products,
    next: null,
    previous: null,
  );
}

class _PostRepo implements PostPublicRepository {
  _PostRepo(this.posts);

  final List<PublicPost> posts;

  @override
  Future<PublicPost?> fetchPublicPost(int id) async => null;

  @override
  Future<PaginatedResponse<PublicPost>> fetchBusinessPosts(
    int businessId,
  ) async => PaginatedResponse<PublicPost>(
    results: posts,
    next: null,
    previous: null,
  );
}

class _ReelRepo implements ReelPublicRepository {
  @override
  Future<PublicReel?> fetchPublicReel(int id) async => null;

  @override
  Future<PaginatedResponse<PublicReel>> fetchBusinessReels(
    int businessId,
  ) async => const PaginatedResponse<PublicReel>(
    results: [],
    next: null,
    previous: null,
  );
}

class _NoStoriesRepo implements StoryPublicRepository {
  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async => const PaginatedResponse<PublicStory>(
    results: [],
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

const List<Product> _products = <Product>[
  Product(
    id: 1,
    businessId: 7,
    categoryId: 1,
    name: 'Leather bag',
    description: '',
    price: '100.00',
    currency: Currency.egp,
  ),
  Product(
    id: 2,
    businessId: 7,
    categoryId: 1,
    name: 'Silk scarf',
    description: '',
    price: '50.00',
    currency: Currency.egp,
  ),
  Product(
    id: 3,
    businessId: 7,
    categoryId: 1,
    name: 'Wool coat',
    description: '',
    price: '900.00',
    currency: Currency.egp,
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  int? ownBusinessId,
}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessProfilePublicRepositoryProvider.overrideWithValue(
          _ProfileRepo(_profile),
        ),
        productPublicRepositoryProvider.overrideWithValue(
          _ProductRepo(_products),
        ),
        postPublicRepositoryProvider.overrideWithValue(
          _PostRepo(const <PublicPost>[
            PublicPost(id: 501, businessId: 7, caption: 'One.'),
            PublicPost(id: 502, businessId: 7, caption: 'Two.'),
          ]),
        ),
        reelPublicRepositoryProvider.overrideWithValue(_ReelRepo()),
        storyPublicRepositoryProvider.overrideWithValue(_NoStoriesRepo()),
        socialInteractionRepositoryProvider.overrideWithValue(
          FakeSocialInteractionRepository(),
        ),
        ownBusinessIdProvider.overrideWithValue(ownBusinessId),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme ?? AppTheme.light,
        home: const BusinessProfilePublicScreen(businessId: '7'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _statValue(WidgetTester tester, String label) {
  return tester
      .widget<StatItem>(find.widgetWithText(StatItem, label))
      .value;
}

void main() {
  group('English (LTR)', () {
    testWidgets('the stats row shows Posts, Followers and Products', (
      tester,
    ) async {
      await _pump(tester);

      expect(_statValue(tester, 'Posts'), '2');
      expect(_statValue(tester, 'Followers'), '12');
      expect(_statValue(tester, 'Products'), '3');
    });

    testWidgets('the icon tab bar has four tabs and starts on Posts', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(ProfileTabBar), findsOneWidget);
      expect(find.byTooltip('Posts'), findsOneWidget);
      expect(find.byTooltip('Reels'), findsOneWidget);
      expect(find.byTooltip('Products'), findsOneWidget);
      expect(find.byTooltip('Info'), findsOneWidget);
      // Posts tab: two tiles.
      expect(find.byType(GridTileMedia), findsNWidgets(2));
    });

    testWidgets(
      'the Products tab is a grid of names with no price and no purchase '
      'affordance',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.byTooltip('Products'));
        await tester.pumpAndSettle();

        expect(find.text('Leather bag'), findsOneWidget);
        expect(find.text('Silk scarf'), findsOneWidget);
        expect(find.text('Wool coat'), findsOneWidget);
        expect(find.byType(GridTileMedia), findsNWidgets(3));
        expect(find.textContaining('100'), findsNothing);
        expect(find.byIcon(Icons.shopping_cart_outlined), findsNothing);
        expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
      },
    );

    testWidgets('the Info tab shows type, location and phone', (tester) async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Info'));
      await tester.pumpAndSettle();

      expect(find.text('Business type'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('+201000000000'), findsOneWidget);
    });

    testWidgets('a visitor sees Follow (filled) and Message (outlined)', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.widgetWithText(AppButton, 'Follow'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Message'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('following turns the button neutral and raises the count', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Follow'));
      await tester.pumpAndSettle();

      final AppButton following = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Following'),
      );
      expect(following.variant, AppButtonVariant.neutral);
      expect(_statValue(tester, 'Followers'), '13');
    });

    testWidgets('the owner of the business sees no Message button', (
      tester,
    ) async {
      await _pump(tester, ownBusinessId: 7);

      expect(find.widgetWithText(AppButton, 'Message'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Follow'), findsOneWidget);
    });

    testWidgets('works in the dark theme', (tester) async {
      await _pump(tester, theme: AppTheme.dark);

      expect(find.text('Al Ananka Store'), findsOneWidget);
      expect(find.byType(StatItem), findsNWidgets(3));
    });
  });

  group('Arabic (RTL)', () {
    const Locale ar = Locale('ar');

    testWidgets('the layout is right-to-left and the labels are Arabic', (
      tester,
    ) async {
      await _pump(tester, locale: ar);

      final BuildContext context = tester.element(find.byType(ProfileTabBar));
      expect(Directionality.of(context), TextDirection.rtl);

      // Followers, Posts, Products, Follow, Message.
      expect(
        find.text('\u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0648\u0646'),
        findsOneWidget,
      );
      expect(
        find.text('\u0627\u0644\u0645\u0646\u0634\u0648\u0631\u0627\u062a'),
        findsOneWidget,
      );
      expect(
        find.text('\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a'),
        findsOneWidget,
      );
      expect(
        find.text('\u0645\u062a\u0627\u0628\u0639\u0629'),
        findsOneWidget,
      );
      expect(
        find.text('\u0645\u0631\u0627\u0633\u0644\u0629'),
        findsOneWidget,
      );
    });

    testWidgets('the first tab sits at the start (right) side', (tester) async {
      await _pump(tester, locale: ar);

      final Rect postsTab = tester.getRect(
        find.byTooltip('\u0627\u0644\u0645\u0646\u0634\u0648\u0631\u0627\u062a'),
      );
      final Rect infoTab = tester.getRect(
        find.byTooltip('\u0645\u0639\u0644\u0648\u0645\u0627\u062a'),
      );
      expect(postsTab.center.dx, greaterThan(infoTab.center.dx));
    });
  });
}
'@
Write-RepoFile 'test\features\business_profile\presentation\business_profile_public_p114_test.dart' $newTest1 $true

Write-Host ''
Write-Host '== 2/5 Replaced files (presentation only) ==' -ForegroundColor Cyan
$rep1 = @'
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Visual weight of an [AppButton].
///
/// Part P-114 STEP 3: [neutral] (grey, used by "Following") and [outlined]
/// (used by "Message") were added next to the original filled button.
enum AppButtonVariant {
  /// Filled brand button: the primary action. This is the default.
  filled,

  /// Filled with the neutral surface colour: a secondary state such as
  /// "Following".
  neutral,

  /// Hairline outline, no fill: a secondary action such as "Message".
  outlined,
}

/// The one button of the app (Part P-006, extended by P-114 STEP 3).
///
/// Every variant is still an [AppButton], so tests and callers that look for
/// an [AppButton] with a label keep working whatever the variant is.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.filled,
  });

  final String label;

  final VoidCallback? onPressed;

  /// Shows a small spinner instead of the label and disables the button.
  final bool isLoading;

  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final VoidCallback? handler = isLoading ? null : onPressed;
    final Widget child =
        isLoading
            ? SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color:
                    variant == AppButtonVariant.filled
                        ? colors.brandText
                        : colors.textPrimary,
              ),
            )
            : Text(label);

    switch (variant) {
      case AppButtonVariant.filled:
        return FilledButton(onPressed: handler, child: child);
      case AppButtonVariant.neutral:
        return FilledButton(
          onPressed: handler,
          style: FilledButton.styleFrom(
            backgroundColor: colors.surfaceVariant,
            foregroundColor: colors.textPrimary,
          ),
          child: child,
        );
      case AppButtonVariant.outlined:
        return OutlinedButton(
          onPressed: handler,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textPrimary,
            side: BorderSide(color: colors.outline),
          ),
          child: child,
        );
    }
  }
}
'@
Replace-RepoFile 'lib\core\widgets\app_button.dart' 'b6261f84b868ef692a94da033b21d269fe7b721e7603ea19583a9383bb62aa70' $rep1 $true
$rep2 = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/app_localizations.dart';
import 'social_error_message.dart';
import 'social_interaction_provider.dart';

/// Part P-058: the real Follow / Following button for a business, plus its
/// followers count.
///
/// State lives in `businessFollowProvider`, keyed by [businessId] only, so
/// every place that shows the same business always agrees. This widget seeds
/// that provider once from [followerCount] (the real value the backend
/// returned with the profile).
///
/// KNOWN GAP (flagged, not silently worked around): the backend does not yet
/// say whether the current user already follows this business (no
/// is_following field on the business serializer), so a fresh app session
/// always starts as "Follow". Only follows made in the current session are
/// remembered. Following twice is harmless because the backend toggle is
/// idempotent.
///
/// [onToggled], when given, runs after a follow or unfollow request
/// succeeded (never after a failed one).
///
/// ## Part P-114 STEP 3 (presentation only)
///
/// * "Follow" is the filled blue button, "Following" is the neutral one
///   ([AppButtonVariant.neutral]).
/// * The labels and the count line come from the ARB files; the count goes
///   through `AppFormatters`.
/// * [showCount] (default true) draws the "N followers" line under the
///   button. The business profile passes false: it shows the count in its
///   stats row instead, and the button then stretches to the width it is
///   given.
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({
    super.key,
    required this.businessId,
    required this.followerCount,
    this.onToggled,
    this.showCount = true,
  });

  final int businessId;
  final int followerCount;
  final VoidCallback? onToggled;
  final bool showCount;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _seeded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Provider state can't be modified during the build phase, so defer.
    Future.microtask(() {
      if (!mounted) return;
      final current = ref.read(businessFollowProvider(widget.businessId));
      ref
          .read(businessFollowProvider(widget.businessId).notifier)
          .seed(
            // Keep whatever this session already knows about following.
            isFollowing: current.isFollowing,
            followersCount: widget.followerCount,
          );
      setState(() => _seeded = true);
    });
  }

  Future<void> _toggle() async {
    // Ignore a second tap while a request is in flight: two overlapping
    // follow/unfollow calls could reach the server in the wrong order.
    if (_busy) return;
    _busy = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(businessFollowProvider(widget.businessId).notifier)
          .toggleFollow();
      if (mounted) widget.onToggled?.call();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(socialErrorMessage(e))));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessFollowProvider(widget.businessId));
    final AppLocalizations l10n = context.l10n;
    // Before the one-time seed lands, show the value we were given instead
    // of a flash of "0 followers".
    final count = _seeded ? state.followersCount : widget.followerCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          widget.showCount
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: state.isFollowing
              ? l10n.followButtonFollowing
              : l10n.followButtonFollow,
          variant:
              state.isFollowing
                  ? AppButtonVariant.neutral
                  : AppButtonVariant.filled,
          onPressed: _toggle,
        ),
        if (widget.showCount) ...[
          const SizedBox(height: 6),
          Text(
            l10n.followersCountLine(count, AppFormatters(l10n).compactCount(count)),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ],
    );
  }
}
'@
Replace-RepoFile 'lib\features\social\presentation\follow_button.dart' '43dc37f11c62863b5f5362145559b9373db3cfe62caee501e79a86bbf019c6d3' $rep2 $true
$rep3 = @'
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/featured_badge.dart';
import '../../../core/widgets/grid_tile_media.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/profile_tab_bar.dart';
import '../../../core/widgets/stat_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';
import '../../chat/data/conversation_repository.dart';
import '../../content/presentation/content_public_providers.dart';
import '../../products/presentation/product_public_providers.dart';
import '../../social/presentation/follow_button.dart';
import '../../social/presentation/social_interaction_provider.dart';
import '../../stories/presentation/story_public_provider.dart';
import '../domain/business_profile_entity.dart';
import 'business_profile_public_provider.dart';
import 'own_business_id_provider.dart';
import 'own_profile_edit_button.dart';

/// Part P-029: the customer-facing, READ-ONLY business profile screen behind
/// `/business/:id`.
///
/// ## Part P-114 STEP 3: Instagram-style layout (presentation only)
///
/// Same provider, same routes, same callbacks as before. Only the widget tree
/// changed:
///
/// * Header: avatar (with the story ring when the business has active
///   stories; tapping it opens the story viewer like the Home tray does),
///   a stats row (Posts, Followers, Products), name with the Verified mark
///   and the Featured badge, business type, location, bio, and an action row
///   (Follow filled / Following neutral, Message outlined).
/// * An icon tab bar (Posts grid, Reels grid, Products grid, Info) with
///   3-column grids. The tab bodies live inside the one scroll view (no
///   nested scrolling).
/// * Every list keeps its own loading / empty / error states; loading is a
///   grid of skeleton tiles, never a spinner.
///
/// ## Data contracts that did not change
///
/// * Posts, Reels and Products come from `businessPostsProvider`,
///   `businessReelsProvider` and `businessProductsProvider` (first page only,
///   no client-side filtering: the backend only returns published rows).
/// * Follow state lives in `businessFollowProvider`; [FollowButton] seeds it.
/// * Messaging uses `ConversationRepository.startConversationWithBusiness`,
///   the same call as the product screen's "Message Business".
/// * Prices are not shown in the Products grid; the product screen keeps the
///   mandatory "approximate / negotiable" framing. No cart, checkout or buy
///   affordance exists here.
///
/// KNOWN GAPS (flagged): the Posts and Products counts in the stats row are
/// the number of items in the FIRST PAGE (the API returns no total yet);
/// `BusinessProfile` has no rating, logo or cover, so none is drawn; there is
/// no business-level report/share contract yet, so the action row has no
/// overflow menu.
class BusinessProfilePublicScreen extends ConsumerWidget {
  const BusinessProfilePublicScreen({super.key, required this.businessId});

  /// The raw `:id` path parameter, as `go_router` hands it over.
  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The backend route is `<int:pk>/`, so a non-numeric id can never
    // identify a business: resolve it to the not-found state without a
    // request.
    final id = int.tryParse(businessId);
    if (id == null) {
      return const Scaffold(body: SafeArea(child: _NotFoundView()));
    }

    final profileAsync = ref.watch(businessProfilePublicProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.profileScreenTitle),
        actions: <Widget>[OwnProfileEditButton(businessId: id)],
      ),
      body: switch (profileAsync) {
        // AsyncData is matched before the catch-all, and its null case (a
        // confirmed backend 404) is its own branch so "this business does
        // not exist" never renders as a generic error.
        AsyncData(value: final BusinessProfile profile) => _ProfileView(
          profile: profile,
        ),
        AsyncData(value: null) => const _NotFoundView(),
        AsyncError(:final error) => _LoadErrorView(error: error, id: id),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// The message of a failure, or [fallback] when it is not an [ApiFailure].
///
/// Both shapes are handled on purpose: `ErrorInterceptor` rethrows a new
/// DioException carrying the typed ApiFailure in its `.error` (production),
/// while hand-rolled fakes in tests throw the bare ApiFailure.
String _failureMessage(Object error, String fallback) {
  return switch (error) {
    DioException(error: final ApiFailure failure) => failure.message,
    ApiFailure(:final message) => message,
    _ => fallback,
  };
}

/// "This business doesn't exist": an [EmptyStateWidget], not an error, since
/// there is nothing to retry.
class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      message: context.l10n.profileNotFound,
      icon: Icons.storefront_outlined,
    );
  }
}

/// A genuine fetch failure (no connectivity, 5xx, unexpected payload):
/// retryable, unlike [_NotFoundView].
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error, required this.id});

  final Object error;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      message: _failureMessage(error, context.l10n.profileLoadFailed),
      // Automatic retry is disabled on this provider by design, so this
      // button is the only thing that retries.
      onRetry: () => ref.invalidate(businessProfilePublicProvider(id)),
    );
  }
}

/// The loaded profile: header, icon tab bar, and the selected tab's body, all
/// inside one scroll view.
class _ProfileView extends StatefulWidget {
  const _ProfileView({required this.profile});

  final BusinessProfile profile;

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 4;
  late final TabController _controller = TabController(
    length: _tabCount,
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final BusinessProfile profile = widget.profile;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ProfileHeader(profile: profile),
          const SizedBox(height: 12),
          ProfileTabBar(
            controller: _controller,
            items: <ProfileTabItem>[
              ProfileTabItem(icon: Icons.grid_on, label: l10n.profileTabPosts),
              ProfileTabItem(
                icon: Icons.movie_outlined,
                label: l10n.profileTabReels,
              ),
              ProfileTabItem(
                icon: Icons.inventory_2_outlined,
                label: l10n.profileTabProducts,
              ),
              ProfileTabItem(
                icon: Icons.info_outline,
                label: l10n.profileTabInfo,
              ),
            ],
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (BuildContext context, Widget? child) {
              return _TabBody(index: _controller.index, profile: profile);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.index, required this.profile});

  final int index;
  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return switch (index) {
      0 => _PostsTab(
        businessId: profile.id,
        businessName: profile.businessName,
      ),
      1 => _ReelsTab(
        businessId: profile.id,
        businessName: profile.businessName,
      ),
      2 => _ProductsTab(businessId: profile.id),
      _ => _InfoTab(profile: profile),
    };
  }
}

/// Avatar + stats row, name line, type, location, bio and the action row.
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.profile});

  final BusinessProfile profile;

  /// Shown instead of a count while the list is still loading or failed.
  static const String _countPlaceholder = '\u2013';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.appColors;
    final AppLocalizations l10n = context.l10n;
    final AppFormatters formatters = AppFormatters(l10n);
    final TextTheme text = Theme.of(context).textTheme;

    final String typeLabel = switch (profile.businessType) {
      BusinessType.trader => l10n.businessTypeTrader,
      BusinessType.factory => l10n.businessTypeFactory,
    };

    // The same providers the tabs use: no extra request, and the counts are
    // the first page only (see the class docs of the screen).
    final String postsText = switch (ref.watch(
      businessPostsProvider(profile.id),
    )) {
      AsyncData(:final value) => formatters.compactCount(value.length),
      _ => _countPlaceholder,
    };
    final String productsText = switch (ref.watch(
      businessProductsProvider(profile.id),
    )) {
      AsyncData(:final value) => formatters.compactCount(value.length),
      _ => _countPlaceholder,
    };

    // Before FollowButton seeds the provider (one microtask after the first
    // frame) the state still holds its defaults: show the profile's value.
    final follow = ref.watch(businessFollowProvider(profile.id));
    final int followers =
        (follow.followersCount == 0 && !follow.isFollowing)
            ? profile.followerCount
            : follow.followersCount;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _ProfileAvatar(profile: profile),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: StatItem(
                        value: postsText,
                        label: l10n.profileStatPosts,
                      ),
                    ),
                    Expanded(
                      child: StatItem(
                        value: formatters.compactCount(followers),
                        label: l10n.profileStatFollowers,
                      ),
                    ),
                    Expanded(
                      child: StatItem(
                        value: productsText,
                        label: l10n.profileStatProducts,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  profile.businessName,
                  style: text.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Rendered ONLY when the backend says the business is
              // verified (set exclusively by an Admin action server-side).
              if (profile.isVerified) ...<Widget>[
                const SizedBox(width: 6),
                Icon(
                  Icons.verified,
                  size: 18,
                  color: colors.brand,
                  semanticLabel: l10n.feedVerifiedLabel,
                ),
              ],
              // Display-only Featured badge (real P-087 state, P-110).
              if (profile.isFeatured) ...<Widget>[
                const SizedBox(width: 8),
                const FeaturedBadge(),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            typeLabel,
            style: text.labelLarge?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.profileLocation(profile.city, profile.country),
                  style: text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profile.description.isEmpty
                ? l10n.profileNoDescription
                : profile.description,
            style: text.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 16),
          _ProfileActions(profile: profile),
        ],
      ),
    );
  }
}

/// The avatar, with the story ring when the business has active stories.
///
/// Uses the same providers as the Home tray's `StoryRingWidget`
/// (`businessStoriesProvider`, `viewedStoriesProvider`) and opens the same
/// route. A failed or empty stories fetch simply means "no ring".
class _ProfileAvatar extends ConsumerWidget {
  const _ProfileAvatar({required this.profile});

  final BusinessProfile profile;

  static const double _size = 86;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final stories = switch (ref.watch(businessStoriesProvider(profile.id))) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final Set<int> viewed = ref.watch(viewedStoriesProvider(profile.id));

    final bool hasStories = stories != null && stories.isNotEmpty;
    final bool hasUnviewed =
        stories != null &&
        stories.any((story) => !viewed.contains(story.id));

    final AppAvatarRing ring =
        !hasStories
            ? AppAvatarRing.none
            : (hasUnviewed ? AppAvatarRing.unseen : AppAvatarRing.seen);

    return Padding(
      // Same outer size with and without a ring, so the stats row does not
      // jump when the stories arrive.
      padding: EdgeInsets.all(
        hasStories ? 0 : AppAvatar.ringWidth + AppAvatar.ringGap,
      ),
      child: AppAvatar(
        name: profile.businessName,
        size: _size,
        ring: ring,
        semanticLabel:
            !hasStories
                ? null
                : (hasUnviewed
                    ? l10n.storyRingNewLabel(profile.businessName)
                    : l10n.storyRingSeenLabel(profile.businessName)),
        onTap:
            !hasStories
                ? null
                : () => context.pushNamed(
                  RouteNames.storyViewer,
                  pathParameters: <String, String>{
                    RouteNames.idParam: profile.id.toString(),
                  },
                  extra: profile.businessName,
                ),
      ),
    );
  }
}

/// Follow (filled) / Following (neutral) and Message (outlined).
///
/// The owner of the business sees no Message button: the backend refuses a
/// conversation with your own business.
class _ProfileActions extends ConsumerStatefulWidget {
  const _ProfileActions({required this.profile});

  final BusinessProfile profile;

  @override
  ConsumerState<_ProfileActions> createState() => _ProfileActionsState();
}

class _ProfileActionsState extends ConsumerState<_ProfileActions> {
  bool _isStartingConversation = false;

  /// Starts (or resumes) the conversation with this business, then opens its
  /// thread. Same flow as the product screen's "Message Business". The
  /// router, messenger and texts are captured BEFORE the await so they are
  /// still valid afterwards; a second tap while a request is in flight is
  /// ignored.
  Future<void> _messageBusiness() async {
    if (_isStartingConversation) return;

    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    setState(() => _isStartingConversation = true);

    try {
      final conversation = await ref
          .read(conversationRepositoryProvider)
          .startConversationWithBusiness(businessId: widget.profile.id);
      if (!mounted) return;
      setState(() => _isStartingConversation = false);

      if (conversation == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileMessageStarted)),
        );
        return;
      }

      router.pushNamed(
        RouteNames.chatThread,
        pathParameters: <String, String>{
          RouteNames.idParam: conversation.id.toString(),
        },
        extra: conversation,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStartingConversation = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiFailure ? e.message : l10n.profileMessageFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int? ownId = ref.watch(ownBusinessIdProvider);
    final bool isOwner = ownId != null && ownId == widget.profile.id;

    return Row(
      children: <Widget>[
        Expanded(
          child: FollowButton(
            businessId: widget.profile.id,
            followerCount: widget.profile.followerCount,
            showCount: false,
          ),
        ),
        if (!isOwner) ...<Widget>[
          const SizedBox(width: 8),
          Expanded(
            child: AppButton(
              label: l10n.profileMessageButton,
              variant: AppButtonVariant.outlined,
              isLoading: _isStartingConversation,
              onPressed: _messageBusiness,
            ),
          ),
        ],
      ],
    );
  }
}

/// A 3-column grid inside the profile's scroll view (so it never scrolls on
/// its own). The tiles have a fixed aspect ratio, so nothing jumps while the
/// images load.
class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.children, this.childAspectRatio = 1});

  final List<Widget> children;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

/// Skeleton tiles shown while a tab loads (never a spinner).
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton({this.childAspectRatio = 1});

  final double childAspectRatio;

  static const Key skeletonKey = ValueKey<String>('profile_grid_skeleton');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: skeletonKey,
      label: context.l10n.profileGridLoadingLabel,
      child: ExcludeSemantics(
        child: _MediaGrid(
          childAspectRatio: childAspectRatio,
          children: List<Widget>.generate(
            6,
            (int index) => const SizedBox.expand(
              child: AppShimmerBox(borderRadius: 0),
            ),
          ),
        ),
      ),
    );
  }
}

/// Posts tab: the business's published posts, first page only.
class _PostsTab extends ConsumerWidget {
  const _PostsTab({required this.businessId, required this.businessName});

  final int businessId;
  final String businessName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final postsAsync = ref.watch(businessPostsProvider(businessId));

    return switch (postsAsync) {
      AsyncData(value: final posts) when posts.isEmpty => EmptyStateWidget(
        message: l10n.profilePostsEmpty,
        icon: Icons.article_outlined,
      ),
      AsyncData(value: final posts) => _MediaGrid(
        children: <Widget>[
          for (final post in posts)
            GridTileMedia(
              key: ValueKey<String>('profile_post_${post.id}'),
              imageUrl: post.imageUrl,
              semanticLabel: l10n.feedPostMediaLabel(businessName),
              onTap:
                  () => context.pushNamed(
                    RouteNames.postDetail,
                    pathParameters: <String, String>{
                      RouteNames.idParam: '${post.id}',
                    },
                  ),
            ),
        ],
      ),
      AsyncError(:final error) => ErrorStateWidget(
        message: _failureMessage(error, l10n.profilePostsLoadFailed),
        onRetry: () => ref.invalidate(businessPostsProvider(businessId)),
      ),
      _ => const _GridSkeleton(),
    };
  }
}

/// Reels tab: 9:16 tiles with the video mark.
class _ReelsTab extends ConsumerWidget {
  const _ReelsTab({required this.businessId, required this.businessName});

  final int businessId;
  final String businessName;

  static const double _aspect = 9 / 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final reelsAsync = ref.watch(businessReelsProvider(businessId));

    return switch (reelsAsync) {
      AsyncData(value: final reels) when reels.isEmpty => EmptyStateWidget(
        message: l10n.profileReelsEmpty,
        icon: Icons.movie_outlined,
      ),
      AsyncData(value: final reels) => _MediaGrid(
        childAspectRatio: _aspect,
        children: <Widget>[
          for (final reel in reels)
            GridTileMedia(
              key: ValueKey<String>('profile_reel_${reel.id}'),
              imageUrl: reel.thumbnailUrl,
              aspectRatio: _aspect,
              badge: GridTileBadge.video,
              semanticLabel: l10n.feedReelMediaLabel(businessName),
              onTap:
                  () => context.pushNamed(
                    RouteNames.reelDetail,
                    pathParameters: <String, String>{
                      RouteNames.idParam: '${reel.id}',
                    },
                  ),
            ),
        ],
      ),
      AsyncError(:final error) => ErrorStateWidget(
        message: _failureMessage(error, l10n.profileReelsLoadFailed),
        onRetry: () => ref.invalidate(businessReelsProvider(businessId)),
      ),
      _ => const _GridSkeleton(childAspectRatio: _aspect),
    };
  }
}

/// Products tab: square tiles with the product name under each one. The price
/// is deliberately not drawn here; the product screen shows it with the
/// mandatory discovery-only framing.
class _ProductsTab extends ConsumerWidget {
  const _ProductsTab({required this.businessId});

  final int businessId;

  /// Tile (square image) plus one line of text under it.
  static const double _aspect = 0.72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final productsAsync = ref.watch(businessProductsProvider(businessId));

    return switch (productsAsync) {
      AsyncData(value: final products) when products.isEmpty =>
        EmptyStateWidget(
          message: l10n.profileProductsEmpty,
          icon: Icons.inventory_2_outlined,
        ),
      AsyncData(value: final products) => _MediaGrid(
        childAspectRatio: _aspect,
        children: <Widget>[
          for (final product in products)
            _ProductTile(
              key: ValueKey<String>('profile_product_${product.id}'),
              name: product.name,
              imageUrl: product.imageUrl,
              // `push` (not `go`) so the back button returns to this profile.
              onTap:
                  () => context.pushNamed(
                    RouteNames.productDetail,
                    pathParameters: <String, String>{
                      RouteNames.idParam: '${product.id}',
                    },
                  ),
            ),
        ],
      ),
      AsyncError(:final error) => ErrorStateWidget(
        message: _failureMessage(error, l10n.profileProductsLoadFailed),
        onRetry: () => ref.invalidate(businessProductsProvider(businessId)),
      ),
      _ => const _GridSkeleton(childAspectRatio: _aspect),
    };
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GridTileMedia(imageUrl: imageUrl, semanticLabel: name, onTap: onTap),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// Info tab: business type, location and phone (the bio is in the header).
class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String typeLabel = switch (profile.businessType) {
      BusinessType.trader => l10n.businessTypeTrader,
      BusinessType.factory => l10n.businessTypeFactory,
    };
    final String? phone = profile.phoneNumber;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: <Widget>[
          _InfoRow(
            icon: Icons.storefront_outlined,
            label: l10n.profileInfoType,
            value: typeLabel,
          ),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: l10n.profileInfoLocation,
            value: l10n.profileLocation(profile.city, profile.country),
          ),
          if (phone != null && phone.isNotEmpty)
            _InfoRow(
              icon: Icons.phone_outlined,
              label: l10n.profileInfoPhone,
              value: phone,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    return ListTile(
      leading: Icon(icon, color: colors.textSecondary),
      title: Text(
        label,
        style: text.labelMedium?.copyWith(color: colors.textSecondary),
      ),
      subtitle: Text(
        value,
        style: text.bodyMedium?.copyWith(color: colors.textPrimary),
      ),
    );
  }
}
'@
Replace-RepoFile 'lib\features\business_profile\presentation\business_profile_public_screen.dart' 'e0c4cc9f55624f47c6aa07bc07601178b9e5b0218f4a4dac8cc08020b58a914e' $rep3 $true
$rep4 = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/core/widgets/grid_tile_media.dart';
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
import 'package:social_commerce_app/features/products/data/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_public_repository.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';

/// Part P-045 (STEP 7), rewritten in Part P-114 STEP 3.
///
/// Covers the acceptance criterion "the business profile screen only ever
/// requests/displays what the public repository returns, without needing its
/// own redundant filter".
///
/// WHAT CHANGED IN P-114 STEP 3 (documented test change): the Posts and
/// Reels sections used to be lists of PostCard / ReelCard stacked on the
/// profile. They are now the Posts and Reels TABS of the Instagram-style
/// profile, drawn as 3-column grids of [GridTileMedia]. So these tests count
/// grid tiles instead of cards, open the Reels tab before looking at reels,
/// and no longer look for captions (a grid tile shows no caption). The
/// trust-the-repository, empty-state and retry assertions are unchanged.

class _FixedBusinessProfilePublicRepository
    implements BusinessProfilePublicRepository {
  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async => _profile;
}

class _EmptyProductPublicRepository implements ProductPublicRepository {
  @override
  Future<Product?> fetchPublicProduct(int id) async => null;

  @override
  Future<PaginatedResponse<Product>> fetchBusinessProducts(
    int businessId,
  ) async =>
      const PaginatedResponse<Product>(results: [], next: null, previous: null);
}

/// The profile avatar asks for the business's stories (story ring). No
/// stories here, so no ring and no real request.
class _NoStoriesRepository implements StoryPublicRepository {
  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async => const PaginatedResponse<PublicStory>(
    results: [],
    next: null,
    previous: null,
  );

  @override
  Future<void> recordView(int storyId) async {}
}

class _FakePostPublicRepository implements PostPublicRepository {
  _FakePostPublicRepository({this.postsResult = const [], this.postsError});

  List<PublicPost> postsResult;
  Object? postsError;
  int fetchBusinessPostsCallCount = 0;

  @override
  Future<PublicPost?> fetchPublicPost(int id) async => null;

  @override
  Future<PaginatedResponse<PublicPost>> fetchBusinessPosts(
    int businessId,
  ) async {
    fetchBusinessPostsCallCount++;
    if (postsError != null) {
      throw postsError!;
    }
    return PaginatedResponse<PublicPost>(
      results: postsResult,
      next: null,
      previous: null,
    );
  }
}

class _FakeReelPublicRepository implements ReelPublicRepository {
  _FakeReelPublicRepository({this.reelsResult = const [], this.reelsError});

  List<PublicReel> reelsResult;
  Object? reelsError;
  int fetchBusinessReelsCallCount = 0;

  @override
  Future<PublicReel?> fetchPublicReel(int id) async => null;

  @override
  Future<PaginatedResponse<PublicReel>> fetchBusinessReels(
    int businessId,
  ) async {
    fetchBusinessReelsCallCount++;
    if (reelsError != null) {
      throw reelsError!;
    }
    return PaginatedResponse<PublicReel>(
      results: reelsResult,
      next: null,
      previous: null,
    );
  }
}

const _profile = BusinessProfile(
  id: 7,
  businessName: 'Al Ananka Store',
  businessType: BusinessType.trader,
  country: 'Egypt',
  city: 'Cairo',
  description: 'Fashion and accessories, wholesale and retail.',
  isVerified: true,
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakePostPublicRepository postRepository,
  required _FakeReelPublicRepository reelRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessProfilePublicRepositoryProvider.overrideWithValue(
          _FixedBusinessProfilePublicRepository(),
        ),
        productPublicRepositoryProvider.overrideWithValue(
          _EmptyProductPublicRepository(),
        ),
        postPublicRepositoryProvider.overrideWithValue(postRepository),
        reelPublicRepositoryProvider.overrideWithValue(reelRepository),
        storyPublicRepositoryProvider.overrideWithValue(_NoStoriesRepository()),
        ownBusinessIdProvider.overrideWithValue(null),
      ],
      child: const MaterialApp(
        home: BusinessProfilePublicScreen(businessId: '7'),
      ),
    ),
  );
}

Future<void> _openReelsTab(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Reels'));
  await tester.pumpAndSettle();
}

void main() {
  group('BusinessProfilePublicScreen - Posts tab', () {
    testWidgets(
      'shows one grid tile per post the repository returns, trusting it as '
      'already published - no client-side re-filtering',
      (tester) async {
        final postRepository = _FakePostPublicRepository(
          postsResult: const [
            PublicPost(id: 501, businessId: 7, caption: 'First post.'),
            PublicPost(id: 502, businessId: 7, caption: 'Second post.'),
            PublicPost(id: 503, businessId: 7, caption: 'Third post.'),
          ],
        );

        await _pumpScreen(
          tester,
          postRepository: postRepository,
          reelRepository: _FakeReelPublicRepository(),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GridTileMedia), findsNWidgets(3));
        expect(find.byKey(const ValueKey<String>('profile_post_501')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('profile_post_503')), findsOneWidget);
      },
    );

    testWidgets(
      'an empty Posts result shows the tab\'s own empty state, not a '
      'spinner or a generic error',
      (tester) async {
        await _pumpScreen(
          tester,
          postRepository: _FakePostPublicRepository(),
          reelRepository: _FakeReelPublicRepository(),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('This business hasn\'t shared any posts yet.'),
          findsOneWidget,
        );
        expect(find.byType(GridTileMedia), findsNothing);
      },
    );

    testWidgets(
      'a Posts fetch failure shows an inline, retryable error scoped to '
      'the Posts tab, without hiding the rest of the profile',
      (tester) async {
        final postRepository = _FakePostPublicRepository(
          postsError: const ServerFailure(message: 'Posts unavailable.'),
        );

        await _pumpScreen(
          tester,
          postRepository: postRepository,
          reelRepository: _FakeReelPublicRepository(),
        );
        await tester.pumpAndSettle();

        // The rest of the profile still renders - a Posts failure never
        // replaces the whole screen.
        expect(find.text('Al Ananka Store'), findsOneWidget);
        expect(find.text('Posts unavailable.'), findsOneWidget);

        final retryButtons = find.widgetWithText(AppButton, 'Retry');
        expect(retryButtons, findsOneWidget);

        postRepository.postsError = null;
        postRepository.postsResult = const [
          PublicPost(id: 501, businessId: 7, caption: 'Now it loads.'),
        ];

        // The screen is one tall scroll view, so the Retry button can render
        // below the fold of the default test viewport.
        await tester.ensureVisible(retryButtons);
        await tester.pumpAndSettle();

        await tester.tap(retryButtons);
        await tester.pumpAndSettle();

        expect(postRepository.fetchBusinessPostsCallCount, 2);
        expect(find.byType(GridTileMedia), findsOneWidget);
      },
    );
  });

  group('BusinessProfilePublicScreen - Reels tab', () {
    testWidgets(
      'shows one grid tile per reel the repository returns, trusting it as '
      'already published and fully processed - no client-side re-filtering',
      (tester) async {
        final reelRepository = _FakeReelPublicRepository(
          reelsResult: const [
            PublicReel(id: 601, businessId: 7, caption: 'First reel.'),
            PublicReel(id: 602, businessId: 7, caption: 'Second reel.'),
          ],
        );

        await _pumpScreen(
          tester,
          postRepository: _FakePostPublicRepository(),
          reelRepository: reelRepository,
        );
        await tester.pumpAndSettle();
        await _openReelsTab(tester);

        expect(find.byType(GridTileMedia), findsNWidgets(2));
        expect(find.byKey(const ValueKey<String>('profile_reel_601')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('profile_reel_602')), findsOneWidget);
      },
    );

    testWidgets('an empty Reels result shows the tab\'s own empty state', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        postRepository: _FakePostPublicRepository(),
        reelRepository: _FakeReelPublicRepository(),
      );
      await tester.pumpAndSettle();
      await _openReelsTab(tester);

      expect(
        find.text('This business hasn\'t shared any reels yet.'),
        findsOneWidget,
      );
      expect(find.byType(GridTileMedia), findsNothing);
    });

    testWidgets(
      'a Reels fetch failure shows an inline, retryable error scoped to '
      'the Reels tab only',
      (tester) async {
        final reelRepository = _FakeReelPublicRepository(
          reelsError: const ServerFailure(message: 'Reels unavailable.'),
        );

        await _pumpScreen(
          tester,
          postRepository: _FakePostPublicRepository(),
          reelRepository: reelRepository,
        );
        await tester.pumpAndSettle();
        await _openReelsTab(tester);

        expect(find.text('Al Ananka Store'), findsOneWidget);
        expect(find.text('Reels unavailable.'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Retry'), findsOneWidget);
      },
    );
  });
}
'@
Replace-RepoFile 'test\features\business_profile\presentation\business_profile_public_content_section_test.dart' '2cdac91e83737b753d4865544da40d95a31d66a5abfe5cd5dc226daf7b732469' $rep4 $true

Write-Host ''
Write-Host '== 3/5 ARB files ==' -ForegroundColor Cyan
$enEntries = @'
  "profileScreenTitle": "Business",
  "@profileScreenTitle": {
    "description": "App bar title of the public business profile screen."
  },
  "profileStatPosts": "Posts",
  "@profileStatPosts": {
    "description": "Business profile stats row: label under the number of posts."
  },
  "profileStatFollowers": "Followers",
  "@profileStatFollowers": {
    "description": "Business profile stats row: label under the number of followers."
  },
  "profileStatProducts": "Products",
  "@profileStatProducts": {
    "description": "Business profile stats row: label under the number of products."
  },
  "profileTabPosts": "Posts",
  "@profileTabPosts": {
    "description": "Business profile: tooltip and screen-reader label of the Posts grid tab."
  },
  "profileTabReels": "Reels",
  "@profileTabReels": {
    "description": "Business profile: tooltip and screen-reader label of the Reels grid tab."
  },
  "profileTabProducts": "Products",
  "@profileTabProducts": {
    "description": "Business profile: tooltip and screen-reader label of the Products grid tab."
  },
  "profileTabInfo": "Info",
  "@profileTabInfo": {
    "description": "Business profile: tooltip and screen-reader label of the Info tab."
  },
  "followButtonFollow": "Follow",
  "@followButtonFollow": {
    "description": "Label of the Follow button on a business."
  },
  "followButtonFollowing": "Following",
  "@followButtonFollowing": {
    "description": "Label of the button once the business is followed (tap to unfollow)."
  },
  "followersCountLine": "{count, plural, one{{formatted} follower} other{{formatted} followers}}",
  "@followersCountLine": {
    "description": "Followers line under the Follow button. count is the exact number (plural form); formatted is the compact text.",
    "placeholders": {
      "count": {
        "type": "int"
      },
      "formatted": {
        "type": "String"
      }
    }
  },
  "profileMessageButton": "Message",
  "@profileMessageButton": {
    "description": "Business profile: button that opens a conversation with the business."
  },
  "profileMessageStarted": "Conversation started. Open it from Messages.",
  "@profileMessageStarted": {
    "description": "Snackbar shown when the conversation was started but could not be opened directly."
  },
  "profileMessageFailed": "Could not start the conversation. Please try again.",
  "@profileMessageFailed": {
    "description": "Snackbar shown when starting a conversation with the business failed."
  },
  "profileNotFound": "Business not found.\nIt may have been removed.",
  "@profileNotFound": {
    "description": "Business profile: message when the business does not exist."
  },
  "profileLoadFailed": "Could not load this business profile.",
  "@profileLoadFailed": {
    "description": "Business profile: fallback message when loading failed."
  },
  "profileNoDescription": "This business hasn't added a description yet.",
  "@profileNoDescription": {
    "description": "Business profile: text shown when the bio is empty."
  },
  "profileLocation": "{city}, {country}",
  "@profileLocation": {
    "description": "City and country of a business.",
    "placeholders": {
      "city": {
        "type": "String"
      },
      "country": {
        "type": "String"
      }
    }
  },
  "businessTypeTrader": "Trader",
  "@businessTypeTrader": {
    "description": "Business type label: trader."
  },
  "businessTypeFactory": "Factory",
  "@businessTypeFactory": {
    "description": "Business type label: factory."
  },
  "profilePostsEmpty": "This business hasn't shared any posts yet.",
  "@profilePostsEmpty": {
    "description": "Business profile, Posts tab: empty state."
  },
  "profilePostsLoadFailed": "Could not load this business's posts.",
  "@profilePostsLoadFailed": {
    "description": "Business profile, Posts tab: fallback error message."
  },
  "profileReelsEmpty": "This business hasn't shared any reels yet.",
  "@profileReelsEmpty": {
    "description": "Business profile, Reels tab: empty state."
  },
  "profileReelsLoadFailed": "Could not load this business's reels.",
  "@profileReelsLoadFailed": {
    "description": "Business profile, Reels tab: fallback error message."
  },
  "profileProductsEmpty": "This business hasn't added any products yet.",
  "@profileProductsEmpty": {
    "description": "Business profile, Products tab: empty state."
  },
  "profileProductsLoadFailed": "Could not load this business's products.",
  "@profileProductsLoadFailed": {
    "description": "Business profile, Products tab: fallback error message."
  },
  "profileInfoType": "Business type",
  "@profileInfoType": {
    "description": "Business profile, Info tab: label of the business type row."
  },
  "profileInfoLocation": "Location",
  "@profileInfoLocation": {
    "description": "Business profile, Info tab: label of the location row."
  },
  "profileInfoPhone": "Phone",
  "@profileInfoPhone": {
    "description": "Business profile, Info tab: label of the phone row."
  },
  "profileGridLoadingLabel": "Loading content",
  "@profileGridLoadingLabel": {
    "description": "Screen-reader label of the skeleton tiles shown while a profile tab loads."
  }
'@
$arEntries = @'
  "profileScreenTitle": "\u0646\u0634\u0627\u0637 \u062a\u062c\u0627\u0631\u064a",
  "profileStatPosts": "\u0627\u0644\u0645\u0646\u0634\u0648\u0631\u0627\u062a",
  "profileStatFollowers": "\u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0648\u0646",
  "profileStatProducts": "\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a",
  "profileTabPosts": "\u0627\u0644\u0645\u0646\u0634\u0648\u0631\u0627\u062a",
  "profileTabReels": "\u0627\u0644\u0631\u064a\u0644\u0632",
  "profileTabProducts": "\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a",
  "profileTabInfo": "\u0645\u0639\u0644\u0648\u0645\u0627\u062a",
  "followButtonFollow": "\u0645\u062a\u0627\u0628\u0639\u0629",
  "followButtonFollowing": "\u0645\u062a\u0627\u0628\u064e\u0639",
  "followersCountLine": "{count, plural, zero{{formatted} \u0645\u062a\u0627\u0628\u0639} one{\u0645\u062a\u0627\u0628\u0639 \u0648\u0627\u062d\u062f} two{\u0645\u062a\u0627\u0628\u0639\u0627\u0646} few{{formatted} \u0645\u062a\u0627\u0628\u0639\u064a\u0646} many{{formatted} \u0645\u062a\u0627\u0628\u0639\u064b\u0627} other{{formatted} \u0645\u062a\u0627\u0628\u0639}}",
  "profileMessageButton": "\u0645\u0631\u0627\u0633\u0644\u0629",
  "profileMessageStarted": "\u0628\u062f\u0623\u062a \u0627\u0644\u0645\u062d\u0627\u062f\u062b\u0629. \u0627\u0641\u062a\u062d\u0647\u0627 \u0645\u0646 \u0627\u0644\u0631\u0633\u0627\u0626\u0644.",
  "profileMessageFailed": "\u062a\u0639\u0630\u0651\u0631 \u0628\u062f\u0621 \u0627\u0644\u0645\u062d\u0627\u062f\u062b\u0629. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.",
  "profileNotFound": "\u0644\u0645 \u064a\u062a\u0645 \u0627\u0644\u0639\u062b\u0648\u0631 \u0639\u0644\u0649 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a.\n\u0631\u0628\u0645\u0627 \u062a\u0645\u062a \u0625\u0632\u0627\u0644\u062a\u0647.",
  "profileLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0645\u0644\u0641 \u0647\u0630\u0627 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a.",
  "profileNoDescription": "\u0644\u0645 \u064a\u0636\u0641 \u0647\u0630\u0627 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a \u0648\u0635\u0641\u064b\u0627 \u0628\u0639\u062f.",
  "profileLocation": "{city}\u060c {country}",
  "businessTypeTrader": "\u062a\u0627\u062c\u0631",
  "businessTypeFactory": "\u0645\u0635\u0646\u0639",
  "profilePostsEmpty": "\u0644\u0645 \u064a\u0634\u0627\u0631\u0643 \u0647\u0630\u0627 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a \u0623\u064a \u0645\u0646\u0634\u0648\u0631\u0627\u062a \u0628\u0639\u062f.",
  "profilePostsLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0645\u0646\u0634\u0648\u0631\u0627\u062a \u0647\u0630\u0627 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a.",
  "profileReelsEmpty": "\u0644\u0645 \u064a\u0634\u0627\u0631\u0643 \u0647\u0630\u0627 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a \u0623\u064a \u0631\u064a\u0644\u0632 \u0628\u0639\u062f.",
  "profileReelsLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0631\u064a\u0644\u0632 \u0647\u0630\u0627 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a.",
  "profileProductsEmpty": "\u0644\u0645 \u064a\u0636\u0641 \u0647\u0630\u0627 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a \u0623\u064a \u0645\u0646\u062a\u062c\u0627\u062a \u0628\u0639\u062f.",
  "profileProductsLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0645\u0646\u062a\u062c\u0627\u062a \u0647\u0630\u0627 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a.",
  "profileInfoType": "\u0646\u0648\u0639 \u0627\u0644\u0646\u0634\u0627\u0637",
  "profileInfoLocation": "\u0627\u0644\u0645\u0648\u0642\u0639",
  "profileInfoPhone": "\u0627\u0644\u0647\u0627\u062a\u0641",
  "profileGridLoadingLabel": "\u062c\u0627\u0631\u064d \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0645\u062d\u062a\u0648\u0649"
'@
Add-ArbEntries 'lib\l10n\app_en.arb' 'profileScreenTitle' $enEntries 30
Add-ArbEntries 'lib\l10n\app_ar.arb' 'profileScreenTitle' $arEntries 30

Write-Host ''
Write-Host '== 4/5 Patch the existing screen test ==' -ForegroundColor Cyan
$pa0Old = @'
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
'@
$pa0New = @'
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/core/widgets/stat_item.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
'@
Patch-Once 'test\features\business_profile\presentation\business_profile_public_screen_test.dart' $pa0Old $pa0New 'core/widgets/stat_item.dart'
$pa1Old = @'
const _profile = BusinessProfile(
'@
$pa1New = @'
/// Part P-114 STEP 3: the profile avatar asks for the business's stories (story
/// ring). No stories here: no ring and no real request.
class _EmptyStoryPublicRepository implements StoryPublicRepository {
  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async => const PaginatedResponse<PublicStory>(
    results: [],
    next: null,
    previous: null,
  );

  @override
  Future<void> recordView(int storyId) async {}
}

const _profile = BusinessProfile(
'@
Patch-Once 'test\features\business_profile\presentation\business_profile_public_screen_test.dart' $pa1Old $pa1New 'class _EmptyStoryPublicRepository'
$pa2Old = @'
        reelPublicRepositoryProvider.overrideWithValue(
          _EmptyReelPublicRepository(),
        ),
'@
$pa2New = @'
        reelPublicRepositoryProvider.overrideWithValue(
          _EmptyReelPublicRepository(),
        ),
        storyPublicRepositoryProvider.overrideWithValue(
          _EmptyStoryPublicRepository(),
        ),
'@
Patch-Once 'test\features\business_profile\presentation\business_profile_public_screen_test.dart' $pa2Old $pa2New '_EmptyStoryPublicRepository(),
        ),'
$pa3Old = @'
        expect(find.text('12 followers'), findsOneWidget);
        expect(find.text('(coming soon)'), findsNothing);
'@
$pa3New = @'
        // Part P-114 STEP 3: the count is the Followers cell of the stats row.
        expect(
          tester
              .widget<StatItem>(find.widgetWithText(StatItem, 'Followers'))
              .value,
          '12',
        );
        expect(find.text('(coming soon)'), findsNothing);
'@
Patch-Once 'test\features\business_profile\presentation\business_profile_public_screen_test.dart' $pa3Old $pa3New 'the count is the Followers cell of the stats row'
$pa4Old = @'
        expect(
          find.text('This business hasn\'t shared any reels yet.'),
          findsOneWidget,
        );
'@
$pa4New = @'
        // Part P-114 STEP 3: Reels is its own tab now; open it first.
        await tester.tap(find.byTooltip('Reels'));
        await tester.pumpAndSettle();
        expect(
          find.text('This business hasn\'t shared any reels yet.'),
          findsOneWidget,
        );
'@
Patch-Once 'test\features\business_profile\presentation\business_profile_public_screen_test.dart' $pa4Old $pa4New 'Reels is its own tab now; open it first'
$pa5Old = @'
      expect(find.text('13 followers'), findsOneWidget);
'@
$pa5New = @'
      // Part P-114 STEP 3: the count after Follow is the Followers cell.
      expect(
        tester
            .widget<StatItem>(find.widgetWithText(StatItem, 'Followers'))
            .value,
        '13',
      );
'@
Patch-Once 'test\features\business_profile\presentation\business_profile_public_screen_test.dart' $pa5Old $pa5New 'the count after Follow is the Followers cell'

Write-Host ''
Write-Host '== 5/5 flutter gen-l10n ==' -ForegroundColor Cyan
if ($SkipGenL10n) {
  Write-Host '  skipped (-SkipGenL10n). Run: flutter gen-l10n'
} else {
  flutter gen-l10n
  if ($LASTEXITCODE -ne 0) { Fail 'flutter gen-l10n failed. Send me the output.' }
}

Write-Host ''
Write-Host 'STEP 3A applied. Next: flutter analyze, then the tests listed in the message.' -ForegroundColor Green