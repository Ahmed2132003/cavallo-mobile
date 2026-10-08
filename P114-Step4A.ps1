<#
  P114-Step4A.ps1
  PART P-114, STEP 4 (part A of 3) of 4: PRODUCT DETAIL, Instagram style
  (full-width 1:1 image, name + Featured badge, price framing, description, variants as
  read-only pills, Message Business as the primary action, Save + Share in the app bar,
  skeleton instead of a spinner, fully localized). Presentation only.
  (STEP 4B = comments sheet, STEP 4C = golden tests + manual check + progress notes.)

  Run from the ROOT of the cavallo-mobile repo (the folder that contains pubspec.yaml),
  in Windows PowerShell or PowerShell 7, on branch part-111 (STEP 1, 2, 3A and 3B already applied):

      powershell -ExecutionPolicy Bypass -File .\P114-Step4A.ps1

  What it does:
    1. Checks you are in the right repo and that the earlier P-114 steps are in place.
    2. CREATES 1 test file (product_detail_p114_test.dart).
    3. REPLACES 2 presentation files (product_price_framing, product_detail_screen). Each one is
       first compared with the exact version this step was built against; if your copy differs
       the script stops and changes nothing (use -Force to overwrite anyway).
    4. PATCHES 1 existing test (product_detail_screen_test): spinner -> skeleton and the
       IconButton / button counts (Save was added next to Share).
    5. APPENDS 10 new keys to app_en.arb and app_ar.arb.
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
  'lib\core\widgets\app_shimmer_box.dart','lib\core\widgets\media_carousel.dart','lib\core\widgets\featured_badge.dart',
  'lib\core\widgets\app_button.dart','lib\core\l10n\l10n_context.dart','lib\core\theme\app_colors.dart',
  'lib\features\products\presentation\product_detail_screen.dart','lib\features\products\presentation\product_price_framing.dart',
  'lib\features\social\presentation\social_interaction_provider.dart','lib\features\social\presentation\social_error_message.dart',
  'test\features\products\presentation\product_detail_screen_test.dart','test\features\search\presentation\search_p114_test.dart',
  'lib\l10n\app_en.arb','lib\l10n\app_ar.arb')) {
  if (-not (Test-Path (Join-Path $RepoRoot (Fix-Rel $required)))) { Fail "Missing $required. Are P-114 STEP 1, 2, 3A and 3B applied (branch part-111)?" }
}
if (-not (Select-String -Path (Join-Path $RepoRoot (Fix-Rel 'lib\l10n\app_en.arb')) -Pattern '"searchFilterApply"' -Quiet)) { Fail 'app_en.arb has no searchFilterApply key: P-114 STEP 3B is not applied.' }
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
Write-Host '== 1/5 New test file ==' -ForegroundColor Cyan
$newTest1 = @'
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
import 'package:social_commerce_app/features/products/data/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_variant_entity.dart';
import 'package:social_commerce_app/features/products/presentation/product_detail_screen.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/social/domain/social_interaction_repository.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-114 STEP 4A: product detail restyle. Presentation only: these
/// tests prove the new anatomy (Featured badge, variants, skeleton, Save)
/// in English LTR and Arabic RTL, and that no purchase affordance exists.
class _FakeProductRepository implements ProductPublicRepository {
  _FakeProductRepository({this.result, this.pending});

  final Product? result;
  final Completer<Product?>? pending;

  @override
  Future<Product?> fetchPublicProduct(int id) async {
    if (pending != null) return pending!.future;
    return result;
  }

  @override
  Future<PaginatedResponse<Product>> fetchBusinessProducts(int businessId) {
    throw UnimplementedError('not used by ProductDetailScreen');
  }
}

/// Only the Save endpoints are needed; every other call would be a test bug.
class _FakeSocialRepository implements SocialInteractionRepository {
  final List<String> saved = <String>[];

  @override
  Future<bool> saveContent({
    required String contentType,
    required int objectId,
  }) async {
    saved.add('$contentType:$objectId');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const Product _featured = Product(
  id: 10,
  businessId: 7,
  categoryId: 3,
  name: 'Cotton T-Shirt',
  description: 'Plain white cotton t-shirt.',
  price: '199.99',
  currency: Currency.egp,
  isFeatured: true,
  variants: [ProductVariant(id: 1, name: 'Size', value: 'Large')],
);

const Product _plain = Product(
  id: 11,
  businessId: 7,
  categoryId: 3,
  name: 'Plain Cap',
  description: '',
  price: '50.00',
  currency: Currency.sar,
);

Widget _app(
  _FakeProductRepository products, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  _FakeSocialRepository? social,
}) {
  return ProviderScope(
    overrides: [
      productPublicRepositoryProvider.overrideWithValue(products),
      if (social != null)
        socialInteractionRepositoryProvider.overrideWithValue(social),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.light,
      home: const ProductDetailScreen(productId: '10'),
    ),
  );
}

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

  testWidgets('English LTR: anatomy, Featured badge, variants, no purchase UI', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeProductRepository(result: _featured)));
    await tester.pumpAndSettle();

    expect(find.text('Cotton T-Shirt'), findsOneWidget);
    expect(find.byType(FeaturedBadge), findsOneWidget);
    expect(find.text('Starting from 199.99 EGP'), findsOneWidget);
    expect(find.text('Size: Large'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Message Business'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(find.byTooltip('Save'), findsOneWidget);
    expect(find.byIcon(Icons.shopping_cart_outlined), findsNothing);
    expect(
      find.textContaining(
        RegExp(r'buy now|add to cart|checkout|purchase', caseSensitive: false),
      ),
      findsNothing,
    );
    expect(Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.ltr);
  });

  testWidgets('a product without Featured has no badge', (tester) async {
    await tester.pumpWidget(_app(_FakeProductRepository(result: _plain)));
    await tester.pumpAndSettle();

    expect(find.text('Plain Cap'), findsOneWidget);
    expect(find.byType(FeaturedBadge), findsNothing);
    expect(find.text(en.productNoDescription), findsOneWidget);
  });

  testWidgets('Arabic RTL: localized copy, tooltips and direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _FakeProductRepository(result: _featured),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.rtl);
    expect(find.text(ar.productPriceHeadline('199.99', 'EGP')), findsOneWidget);
    expect(find.text(ar.productPriceNote), findsOneWidget);
    expect(find.text(ar.productMessageBusiness), findsOneWidget);
    expect(find.text(ar.productVariantsTitle), findsOneWidget);
    expect(find.byTooltip(ar.actionShare), findsOneWidget);
    expect(find.byTooltip(ar.actionSave), findsOneWidget);
    // The Arabic copy really differs from the English copy.
    expect(ar.productMessageBusiness, isNot(en.productMessageBusiness));
  });

  testWidgets('dark theme builds without errors', (tester) async {
    await tester.pumpWidget(
      _app(
        _FakeProductRepository(result: _featured),
        theme: AppTheme.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cotton T-Shirt'), findsOneWidget);
  });

  testWidgets('loading shows a skeleton, not a spinner', (tester) async {
    final completer = Completer<Product?>();
    await tester.pumpWidget(
      _app(_FakeProductRepository(pending: completer)),
    );
    await tester.pump();

    expect(find.byType(AppShimmerBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    completer.complete(_featured);
    await tester.pumpAndSettle();
    expect(find.byType(AppShimmerBox), findsNothing);
    expect(find.text('Cotton T-Shirt'), findsOneWidget);
  });

  testWidgets('Save toggles the bookmark and calls the save endpoint', (
    tester,
  ) async {
    final social = _FakeSocialRepository();
    await tester.pumpWidget(
      _app(_FakeProductRepository(result: _featured), social: social),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(social.saved, ['product:10']);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byTooltip(en.savedUnsave), findsOneWidget);
  });
}
'@
Write-RepoFile 'test\features\products\presentation\product_detail_p114_test.dart' $newTest1 $true

Write-Host ''
Write-Host '== 2/5 Replace presentation files ==' -ForegroundColor Cyan
$priceFile = @'
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/product_entity.dart';

/// Part P-034 scope: the single source of truth for the price-framing
/// copy required by architecture Section 20 ("{{U+0644}}{{U+0627}}{{U+0632}}{{U+0645}} {{U+064A}}{{U+062A}}{{U+0648}}{{U+0636}}{{U+0651}}{{U+062D}} {{U+0641}}{{U+064A}} {{U+0627}}{{U+0644}}{{U+0640}} UI/Copy
/// {{U+0625}}{{U+0646}} {{U+0627}}{{U+0644}}{{U+0633}}{{U+0639}}{{U+0631}} {{U+062A}}{{U+0642}}{{U+0631}}{{U+064A}}{{U+0628}}{{U+064A}} {{U+0648}}{{U+0628}}{{U+064A}}{{U+062A}}{{U+0641}}{{U+0627}}{{U+0648}}{{U+0636}} {{U+0639}}{{U+0644}}{{U+064A}}{{U+0647}} {{U+0645}}{{U+0639}} {{U+0627}}{{U+0644}}{{U+062A}}{{U+0627}}{{U+062C}}{{U+0631}} {{U+0645}}{{U+0628}}{{U+0627}}{{U+0634}}{{U+0631}}{{U+0629}}").
///
/// This is a real content requirement, not styling: a customer must
/// never mistake a product's price for a transactional checkout price
/// (this platform has no cart/checkout/payment {{U+2014}} architecture
/// Section 1/20). Every screen that displays a product price must render
/// it through [ProductPriceFraming] rather than composing its own text,
/// so the wording lives in exactly one place:
///
/// * Part P-034: `ProductDetailScreen` and the products section of the
///   public business profile screen.
/// * Phase 11 (Search results) reuses this widget for any product shown
///   in a result list.
///
/// Part P-114 STEP 4A: the wording now comes from the ARB files
/// (`productPriceHeadline`, `productPriceNote`), so it is shown in Arabic
/// and English. [ProductPriceCopy] keeps the English wording as plain
/// constants: tests and any non-widget caller can still read it, and it
/// must stay identical to the English ARB text.
abstract final class ProductPriceCopy {
  /// e.g. `Starting from 199.99 EGP`. [price] is the backend's raw
  /// decimal string, passed through untouched (see `Product.price`).
  static String headline(String price, Currency currency) =>
      'Starting from $price ${currency.toWire()}';

  /// The mandatory framing note shown directly under the price.
  static const String note =
      'Approximate price, negotiable directly with the business. '
      'Message the business to confirm.';
}

/// Renders a product's price together with its mandatory framing note.
///
/// Contains only [Text] widgets {{U+2014}} deliberately no icon, button, or
/// stepper of any kind: nothing here may resemble an "Add to Cart" /
/// "Buy Now" / quantity-selector pattern (Part P-034's hard rule).
///
/// [compact] only shrinks the text styles for use inside list/grid
/// cards; the copy itself is identical in both modes.
///
/// The price number is the backend's raw decimal string, passed through
/// untouched on purpose (Part P-034): it is NOT run through
/// `AppFormatters.price`, which groups thousands and drops `.00`.
class ProductPriceFraming extends StatelessWidget {
  const ProductPriceFraming({
    super.key,
    required this.price,
    required this.currency,
    this.compact = false,
  });

  final String price;
  final Currency currency;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final headlineStyle = (compact
            ? theme.textTheme.titleSmall
            : theme.textTheme.titleLarge)
        ?.copyWith(fontWeight: FontWeight.w700, color: colors.textPrimary);
    final noteStyle = (compact
            ? theme.textTheme.bodySmall
            : theme.textTheme.bodyMedium)
        ?.copyWith(color: colors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.productPriceHeadline(price, currency.toWire()),
          style: headlineStyle,
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(context.l10n.productPriceNote, style: noteStyle),
      ],
    );
  }
}
'@
Replace-RepoFile 'lib\features\products\presentation\product_price_framing.dart' 'f65949966bb696dd399333d759e65bae1e9fa33833c48224a7b356f05f20eb71' $priceFile $true

$detailFile = @'
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/featured_badge.dart';
import '../../../core/widgets/media_carousel.dart';
import '../../../routing/route_names.dart';
import '../../chat/data/conversation_repository.dart';
import '../../chat/domain/shared_content.dart';
import '../../chat/presentation/share_to_conversation_sheet.dart';
import '../../social/presentation/content_interaction_key.dart';
import '../../social/presentation/social_error_message.dart';
import '../../social/presentation/social_interaction_provider.dart';
import '../domain/product_entity.dart';
import 'product_price_framing.dart';
import 'product_public_providers.dart';

/// Part P-034 scope: the customer-facing, READ-ONLY product detail
/// screen behind `/product/:id`. Replaces Part P-007's placeholder for
/// the same route {{U+2014}} the constructor is unchanged, so `app_router.dart`
/// needed no edit.
///
/// ## {{U+26A0}}{{U+FE0F}} Price framing is a REQUIREMENT, not styling
///
/// Architecture Section 20 mandates that the price is shown as
/// approximate / negotiable with the business, never as a transactional
/// price. The price is therefore only ever rendered through
/// [ProductPriceFraming] (`product_price_framing.dart`) {{U+2014}} never as a
/// bare number.
///
/// ## {{U+26A0}}{{U+FE0F}} No transactional UI, by rule
///
/// Nothing on this screen may resemble a purchase flow: no cart icon, no
/// "Buy Now" button, no quantity selector. The only body action is
/// "Message Business" (Part P-077): it starts (or resumes) a real
/// conversation with the business's owner
/// (`ConversationRepository.startConversationWithBusiness`) and opens
/// that conversation's thread. The AppBar carries Save and Share.
///
/// ## Part P-114 STEP 4A (presentation only)
///
/// Instagram-style layout: a full-width 1:1 image, then name (with the
/// read-only [FeaturedBadge] when the product is featured), price framing,
/// description, variants as read-only pills and the primary
/// "Message Business" button. Loading shows a skeleton instead of a
/// spinner. Every string comes from the ARB files and every color from
/// `context.appColors`. No provider, repository, route or callback was
/// changed. Save reuses the existing `contentInteractionProvider` with
/// content type `product` (the same toggle the Saved tab already relies
/// on); see the STEP 4A notes about its initial state.
///
/// ## States
///
/// Mirrors `BusinessProfilePublicScreen` (Part P-029): a non-numeric
/// `:id` resolves to not-found with zero network calls; `AsyncData(null)`
/// (backend 404, or an inactive product) is a not-found empty state with
/// no Retry; a genuine failure shows `ErrorStateWidget` with Retry.
///
/// Phase 11's Search results link into this same screen {{U+2014}} do not create
/// a second product detail screen.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  /// The raw `:id` path parameter, as `go_router` hands it over {{U+2014}} a
  /// [String], parsed here rather than by the router.
  final String productId;

  /// Part P-077: the Share icon's two options {{U+2014}} native share sheet
  /// (unchanged style, no share tracking: P-056's endpoint covers only
  /// Post/Reel) or "Share to conversation".
  void _share(BuildContext context, Product product) {
    final String shareText = context.l10n.productShareText(product.name);
    showShareOptionsSheet(
      context,
      contentType: SharedContentType.product,
      objectId: product.id,
      onNativeShare: () async {
        try {
          await SharePlus.instance.share(ShareParams(text: shareText));
        } catch (_) {}
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    // The backend route is `<int:pk>/`, so a non-numeric id can never
    // identify a product {{U+2014}} nothing to fetch. Resolve it to not-found
    // here instead of firing a request guaranteed to fail.
    final id = int.tryParse(productId);
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.productDetailTitle)),
        body: const SafeArea(child: _NotFoundView()),
      );
    }

    final productAsync = ref.watch(productPublicDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.productDetailTitle),
        actions: [
          if (productAsync case AsyncData(value: final Product product)) ...[
            _SaveAction(productId: product.id),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: l10n.actionShare,
              onPressed: () => _share(context, product),
            ),
          ],
        ],
      ),
      body: switch (productAsync) {
        AsyncData(value: final Product product) => _ProductView(
          product: product,
        ),
        AsyncData(value: null) => const _NotFoundView(),
        AsyncError(:final error) => _LoadErrorView(error: error, id: id),
        _ => const _ProductSkeleton(),
      },
    );
  }
}

/// Save (bookmark) for the product, through the existing
/// `contentInteractionProvider` (content type `product`). The bookmark is
/// not mirrored in RTL. A failed toggle is rolled back by the notifier and
/// explained in a SnackBar.
///
/// KNOWN GAP: the product endpoint does not say whether the viewer already
/// saved this product, so the icon starts as "not saved". Saving is
/// idempotent on the server, so tapping always ends in the right state.
class _SaveAction extends ConsumerWidget {
  const _SaveAction({required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ContentInteractionKey key = (
      contentType: 'product',
      objectId: productId,
    );
    final bool saved = ref.watch(
      contentInteractionProvider(key).select((state) => state.isSaved),
    );
    final l10n = context.l10n;

    return IconButton(
      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
      tooltip: saved ? l10n.savedUnsave : l10n.actionSave,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(contentInteractionProvider(key).notifier).toggleSave();
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text(socialErrorMessage(e))),
          );
        }
      },
    );
  }
}

/// Loading placeholder with the same proportions as the real screen (a 1:1
/// image block, then text lines and a button), so nothing jumps when the
/// product arrives. Replaces the spinner.
class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.productLoadingLabel,
      child: const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: AppShimmerBox(borderRadius: 0),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerBox(width: 220, height: 24),
                  SizedBox(height: 12),
                  AppShimmerBox(width: 160, height: 20),
                  SizedBox(height: 8),
                  AppShimmerBox(height: 14),
                  SizedBox(height: 16),
                  AppShimmerBox(height: 14),
                  SizedBox(height: 8),
                  AppShimmerBox(width: 200, height: 14),
                  SizedBox(height: 24),
                  AppShimmerBox(height: 48, borderRadius: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "This product doesn't exist (or is no longer available)" {{U+2014}} an
/// [EmptyStateWidget], not [ErrorStateWidget]: nothing to retry.
class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      message: context.l10n.productNotFoundMessage,
      icon: Icons.inventory_2_outlined,
    );
  }
}

/// A genuine fetch failure {{U+2014}} retryable, unlike [_NotFoundView].
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error, required this.id});

  final Object error;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both error shapes are handled on purpose (see
    // `business_profile_public_screen.dart`'s `_LoadErrorView` and
    // `product_list_screen.dart`'s `_apiFailureMessage`): production
    // throws a DioException carrying the typed ApiFailure in `.error`;
    // hand-rolled test fakes throw a bare ApiFailure.
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => failure.message,
      ApiFailure(:final message) => message,
      _ => context.l10n.productLoadFailed,
    };

    return ErrorStateWidget(
      message: message,
      // Automatic retry is disabled on the provider by design, so this
      // button is the only thing that retries.
      onRetry: () => ref.invalidate(productPublicDetailProvider(id)),
    );
  }
}

class _ProductView extends ConsumerStatefulWidget {
  const _ProductView({required this.product});

  final Product product;

  @override
  ConsumerState<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends ConsumerState<_ProductView> {
  bool _isStartingConversation = false;

  /// Part P-077: "Message Business". Starts (or resumes) the
  /// conversation with this product's business, then opens its thread.
  ///
  /// The router, messenger and localizations are captured BEFORE the await
  /// so they are still valid afterwards. A second tap while a request is in
  /// flight is ignored, so it can't start two.
  Future<void> _messageBusiness() async {
    if (_isStartingConversation) return;

    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _isStartingConversation = true);

    try {
      final conversation = await ref
          .read(conversationRepositoryProvider)
          .startConversationWithBusiness(businessId: widget.product.businessId);
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
        pathParameters: {RouteNames.idParam: conversation.id.toString()},
        extra: conversation,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStartingConversation = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is ApiFailure ? e.message : l10n.profileMessageFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final l10n = context.l10n;
    final product = widget.product;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(imageUrl: product.imageUrl, label: product.name),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (product.isFeatured) ...[
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsetsDirectional.only(top: 6),
                        child: FeaturedBadge(),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // The ONLY place the price is rendered on this screen {{U+2014}}
                // always together with its mandatory framing note
                // (Section 20).
                ProductPriceFraming(
                  price: product.price,
                  currency: product.currency,
                ),
                const SizedBox(height: 16),
                Divider(height: 1, thickness: 0.5, color: colors.outline),
                const SizedBox(height: 16),
                Text(
                  product.description.isEmpty
                      ? l10n.productNoDescription
                      : product.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                if (product.variants.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    l10n.productVariantsTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Read-only info {{U+2014}} a customer cannot select or configure
                  // a variant (that would imply a purchase flow). Plain
                  // containers, deliberately not chips or buttons.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final variant in product.variants)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: colors.outline,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${variant.name}: ${variant.value}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                // Part P-077: the primary action. Its ancestor stays the
                // scroll view, which tests rely on.
                AppButton(
                  label: l10n.productMessageBusiness,
                  isLoading: _isStartingConversation,
                  onPressed: _messageBusiness,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The product's single primary image (the backend has one `image`
/// field, not a gallery {{U+2014}} Part P-032), full width in a fixed 1:1 frame so
/// the page never jumps while it loads. Falls back to a neutral
/// placeholder when there is no image; [MediaCarousel] handles load and
/// error states for a real URL and shows page dots only for 2+ images.
class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl, required this.label});

  final String? imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final url = imageUrl;

    if (url == null || url.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: colors.surfaceVariant,
          alignment: Alignment.center,
          child: Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: colors.textSecondary,
          ),
        ),
      );
    }

    return MediaCarousel(
      imageUrls: [url],
      aspectRatio: 1,
      semanticLabel: label,
    );
  }
}
'@
Replace-RepoFile 'lib\features\products\presentation\product_detail_screen.dart' '3386d4d85361b5b6ec15a33ca579ffa046f396f7caf5044e8ae5fdf9d90da9a1' $detailFile $true

Write-Host ''
Write-Host '== 3/5 Patch the existing product detail test ==' -ForegroundColor Cyan
$o = @'
import 'package:social_commerce_app/core/widgets/app_button.dart';
'@
$n = @'
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';
'@
$m = @'
core/widgets/app_shimmer_box.dart
'@
Patch-Once 'test\features\products\presentation\product_detail_screen_test.dart' $o $n $m
$o = @'
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
'@
$n = @'
      // Part P-114 STEP 4A: a skeleton replaces the spinner.
      expect(find.byType(AppShimmerBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
'@
$m = @'
expect(find.byType(AppShimmerBox), findsWidgets);
'@
Patch-Once 'test\features\products\presentation\product_detail_screen_test.dart' $o $n $m
$o = @'
      expect(find.byType(IconButton), findsOneWidget);
'@
$n = @'
      // Part P-114 STEP 4A: Save (bookmark) now sits next to Share.
      expect(find.byType(IconButton), findsNWidgets(2));
'@
$m = @'
expect(find.byType(IconButton), findsNWidgets(2));
'@
Patch-Once 'test\features\products\presentation\product_detail_screen_test.dart' $o $n $m
$o = @'
      expect(find.bySubtype<ButtonStyleButton>(), findsNWidgets(2));
'@
$n = @'
      expect(find.bySubtype<ButtonStyleButton>(), findsNWidgets(3));
'@
$m = @'
expect(find.bySubtype<ButtonStyleButton>(), findsNWidgets(3));
'@
Patch-Once 'test\features\products\presentation\product_detail_screen_test.dart' $o $n $m
$o = @'
          of: find.byType(AppBar),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
        findsOneWidget,
'@
$n = @'
          of: find.byType(AppBar),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
        findsNWidgets(2),
'@
$m = @'
matching: find.bySubtype<ButtonStyleButton>(),
        ),
        findsNWidgets(2),
'@
Patch-Once 'test\features\products\presentation\product_detail_screen_test.dart' $o $n $m

Write-Host ''
Write-Host '== 4/5 ARB keys (10 per language) ==' -ForegroundColor Cyan
$enEntries = @'
  "productDetailTitle": "Product",
  "@productDetailTitle": {
    "description": "Title of the product detail screen (app bar)."
  },
  "productPriceHeadline": "Starting from {price} {currency}",
  "@productPriceHeadline": {
    "description": "Price line of a product. price is the backend decimal text, currency is the currency code. It is a discovery price, never a checkout total.",
    "placeholders": {
      "price": {
        "type": "String"
      },
      "currency": {
        "type": "String"
      }
    }
  },
  "productPriceNote": "Approximate price, negotiable directly with the business. Message the business to confirm.",
  "@productPriceNote": {
    "description": "Mandatory note under every product price: the price is approximate and negotiated with the business (architecture Section 20)."
  },
  "productNotFoundMessage": "Product not found.\nIt may have been removed.",
  "@productNotFoundMessage": {
    "description": "Empty state of the product detail screen when the product does not exist or is no longer available."
  },
  "productLoadFailed": "Could not load this product.",
  "@productLoadFailed": {
    "description": "Fallback error text of the product detail screen when the failure has no message of its own."
  },
  "productNoDescription": "This business hasn't added a description yet.",
  "@productNoDescription": {
    "description": "Shown on the product detail screen when the product has no description."
  },
  "productVariantsTitle": "Variants",
  "@productVariantsTitle": {
    "description": "Heading of the read-only variants list on the product detail screen."
  },
  "productMessageBusiness": "Message Business",
  "@productMessageBusiness": {
    "description": "Primary button on the product detail screen: starts a conversation with the business. Not a purchase action."
  },
  "productShareText": "Check out {name} on Cavallo",
  "@productShareText": {
    "description": "Text sent by the native share sheet when sharing a product. name is the product name.",
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  },
  "productLoadingLabel": "Loading product",
  "@productLoadingLabel": {
    "description": "Screen-reader label of the product detail loading skeleton."
  }
'@
$arEntries = @'
  "productDetailTitle": "\u0627\u0644\u0645\u0646\u062a\u062c",
  "productPriceHeadline": "\u0627\u0628\u062a\u062f\u0627\u0621\u064b \u0645\u0646 {price} {currency}",
  "productPriceNote": "\u0627\u0644\u0633\u0639\u0631 \u062a\u0642\u0631\u064a\u0628\u064a \u0648\u0642\u0627\u0628\u0644 \u0644\u0644\u062a\u0641\u0627\u0648\u0636 \u0645\u0628\u0627\u0634\u0631\u0629 \u0645\u0639 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a. \u0631\u0627\u0633\u0644 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a \u0644\u0644\u062a\u0623\u0643\u064a\u062f.",
  "productNotFoundMessage": "\u0644\u0645 \u064a\u062a\u0645 \u0627\u0644\u0639\u062b\u0648\u0631 \u0639\u0644\u0649 \u0627\u0644\u0645\u0646\u062a\u062c.\n\u0631\u0628\u0645\u0627 \u062a\u0645\u062a \u0625\u0632\u0627\u0644\u062a\u0647.",
  "productLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0647\u0630\u0627 \u0627\u0644\u0645\u0646\u062a\u062c.",
  "productNoDescription": "\u0644\u0645 \u064a\u0636\u0641 \u0647\u0630\u0627 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a \u0648\u0635\u0641\u064b\u0627 \u0628\u0639\u062f.",
  "productVariantsTitle": "\u0627\u0644\u062e\u064a\u0627\u0631\u0627\u062a",
  "productMessageBusiness": "\u0645\u0631\u0627\u0633\u0644\u0629 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a",
  "productShareText": "\u0634\u0627\u0647\u062f {name} \u0639\u0644\u0649 \u0643\u0627\u0641\u0627\u0644\u0648",
  "productLoadingLabel": "\u062c\u0627\u0631\u064d \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0645\u0646\u062a\u062c"
'@
Add-ArbEntries 'lib\l10n\app_en.arb' 'productDetailTitle' (Expand-U $enEntries) 10
Add-ArbEntries 'lib\l10n\app_ar.arb' 'productDetailTitle' (Expand-U $arEntries) 10

Write-Host ''
Write-Host '== 5/5 flutter gen-l10n ==' -ForegroundColor Cyan
if ($SkipGenL10n) {
  Write-Host '  skipped (-SkipGenL10n). Run: flutter gen-l10n'
} else {
  flutter gen-l10n
  if ($LASTEXITCODE -ne 0) { Fail 'flutter gen-l10n failed. Send me the output.' }
}

Write-Host ''
Write-Host 'STEP 4A applied. Next: flutter analyze, then the tests listed in the message.' -ForegroundColor Green