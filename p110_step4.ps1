# P-110 STEP 4 - adds the Featured badge UI tests.
# Run from D:\Cavallo\social_commerce_app
$ErrorActionPreference = 'Stop'
$target = 'test\features\featured\featured_badge_ui_test.dart'
New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null

if (Test-Path $target) {
    Write-Host "[SKIP  ] $target (already exists)"
    exit 0
}

$content = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_public_screen.dart';
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
import 'package:social_commerce_app/features/search/domain/search_result_entity.dart';
import 'package:social_commerce_app/features/search/presentation/search_result_card.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';

import '../social/fake_social_interaction_repository.dart';

/// Part P-110 STEP 4: UI tests proving the read-only Featured badge shows
/// when `isFeatured == true` and is absent when `isFeatured == false`, in
/// every location that displays a business or its content:
/// public profile (P-029), search result rows (P-065, business + product),
/// PostCard and ReelCard (P-045).

// ---------------------------------------------------------------- fixtures

const _business = BusinessProfile(
  id: 7,
  businessName: 'Al Ananka Store',
  businessType: BusinessType.trader,
  country: 'Egypt',
  city: 'Cairo',
  isVerified: true,
);

const _product = Product(
  id: 55,
  businessId: 7,
  categoryId: 1,
  name: 'Cotton Roll',
  description: '',
  price: '199.99',
  currency: Currency.egp,
);

const _post = PublicPost(id: 501, businessId: 7, caption: 'New arrivals');

const _reel = PublicReel(
  id: 601,
  businessId: 7,
  caption: 'Behind the scenes',
  videoUrl: 'https://example.com/reel-601.mp4',
  thumbnailUrl: 'https://example.com/reel-601-thumb.jpg',
  durationSeconds: 42,
);

// ------------------------------------------------------------------ fakes

class _FakeProfileRepo implements BusinessProfilePublicRepository {
  _FakeProfileRepo(this.result);
  final BusinessProfile result;

  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async => result;
}

class _EmptyProductRepo implements ProductPublicRepository {
  @override
  Future<Product?> fetchPublicProduct(int id) async => null;

  @override
  Future<PaginatedResponse<Product>> fetchBusinessProducts(
    int businessId,
  ) async =>
      const PaginatedResponse<Product>(results: [], next: null, previous: null);
}

class _EmptyPostRepo implements PostPublicRepository {
  @override
  Future<PublicPost?> fetchPublicPost(int id) async => null;

  @override
  Future<PaginatedResponse<PublicPost>> fetchBusinessPosts(
    int businessId,
  ) async => const PaginatedResponse<PublicPost>(
    results: [],
    next: null,
    previous: null,
  );
}

class _EmptyReelRepo implements ReelPublicRepository {
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

// ---------------------------------------------------------------- helpers

void _growSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpProfile(WidgetTester tester, BusinessProfile profile) async {
  _growSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessProfilePublicRepositoryProvider.overrideWithValue(
          _FakeProfileRepo(profile),
        ),
        socialInteractionRepositoryProvider.overrideWithValue(
          FakeSocialInteractionRepository(),
        ),
        productPublicRepositoryProvider.overrideWithValue(_EmptyProductRepo()),
        postPublicRepositoryProvider.overrideWithValue(_EmptyPostRepo()),
        reelPublicRepositoryProvider.overrideWithValue(_EmptyReelRepo()),
      ],
      child: MaterialApp(
        home: BusinessProfilePublicScreen(businessId: '${profile.id}'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSearchCard(WidgetTester tester, SearchResult result) async {
  _growSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SearchResultCard(result: result, onTap: () {}),
        ),
      ),
    ),
  );
}

Future<void> _pumpPost(WidgetTester tester, PublicPost post) async {
  _growSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        socialInteractionRepositoryProvider.overrideWithValue(
          FakeSocialInteractionRepository(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: PostCard(post: post, businessName: 'Al Ananka Store'),
        ),
      ),
    ),
  );
}

Future<void> _pumpReel(WidgetTester tester, PublicReel reel) async {
  _growSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        socialInteractionRepositoryProvider.overrideWithValue(
          FakeSocialInteractionRepository(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ReelCard(reel: reel, businessName: 'Al Ananka Store'),
        ),
      ),
    ),
  );
}

void main() {
  group('FeaturedBadge widget', () {
    testWidgets('shows a star icon and the word "Featured"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FeaturedBadge())),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text(FeaturedBadge.label), findsOneWidget);
      expect(FeaturedBadge.label, 'Featured');
    });

    testWidgets('is display-only: no tap target, no purchase action (ADR-006)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FeaturedBadge())),
      );

      final inBadge = find.descendant(
        of: find.byType(FeaturedBadge),
        matching: find.byWidgetPredicate(
          (w) =>
              w is InkWell ||
              w is GestureDetector ||
              w is ButtonStyleButton ||
              w is IconButton,
        ),
      );
      expect(inBadge, findsNothing);
    });
  });

  group('Public business profile (P-029)', () {
    testWidgets('Featured business shows the badge', (tester) async {
      await _pumpProfile(tester, _business.copyWith(isFeatured: true));

      expect(find.byType(FeaturedBadge), findsOneWidget);
      expect(find.text('Featured'), findsOneWidget);
    });

    testWidgets('non-Featured business shows NO badge', (tester) async {
      await _pumpProfile(tester, _business.copyWith(isFeatured: false));

      expect(find.byType(FeaturedBadge), findsNothing);
      expect(find.text('Featured'), findsNothing);
    });

    testWidgets('badge and verification badge are independent', (tester) async {
      await _pumpProfile(
        tester,
        _business.copyWith(isFeatured: true, isVerified: false),
      );
      expect(find.byType(FeaturedBadge), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsNothing);

      await _pumpProfile(
        tester,
        _business.copyWith(isFeatured: false, isVerified: true),
      );
      expect(find.byType(FeaturedBadge), findsNothing);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });
  });

  group('SearchResultCard (P-065)', () {
    testWidgets('Featured business result shows the badge', (tester) async {
      await _pumpSearchCard(
        tester,
        BusinessSearchResult(_business.copyWith(isFeatured: true)),
      );
      expect(find.text('Al Ananka Store'), findsOneWidget);
      expect(find.byType(FeaturedBadge), findsOneWidget);
    });

    testWidgets('non-Featured business result shows NO badge', (tester) async {
      await _pumpSearchCard(
        tester,
        BusinessSearchResult(_business.copyWith(isFeatured: false)),
      );
      expect(find.text('Al Ananka Store'), findsOneWidget);
      expect(find.byType(FeaturedBadge), findsNothing);
    });

    testWidgets('Featured product result shows the badge', (tester) async {
      await _pumpSearchCard(
        tester,
        ProductSearchResult(_product.copyWith(isFeatured: true)),
      );
      expect(find.text('Cotton Roll'), findsOneWidget);
      expect(find.byType(FeaturedBadge), findsOneWidget);
    });

    testWidgets('non-Featured product result shows NO badge', (tester) async {
      await _pumpSearchCard(
        tester,
        ProductSearchResult(_product.copyWith(isFeatured: false)),
      );
      expect(find.text('Cotton Roll'), findsOneWidget);
      expect(find.byType(FeaturedBadge), findsNothing);
    });
  });

  group('PostCard (P-045)', () {
    testWidgets('post of a Featured business shows the badge', (tester) async {
      await _pumpPost(tester, _post.copyWith(isFeatured: true));
      expect(find.text('Al Ananka Store'), findsOneWidget);
      expect(find.byType(FeaturedBadge), findsOneWidget);
    });

    testWidgets('post of a non-Featured business shows NO badge', (
      tester,
    ) async {
      await _pumpPost(tester, _post.copyWith(isFeatured: false));
      expect(find.text('Al Ananka Store'), findsOneWidget);
      expect(find.byType(FeaturedBadge), findsNothing);
    });
  });

  group('ReelCard (P-045)', () {
    testWidgets('reel of a Featured business shows the badge', (tester) async {
      await _pumpReel(tester, _reel.copyWith(isFeatured: true));
      expect(find.text('Al Ananka Store'), findsOneWidget);
      expect(find.byType(FeaturedBadge), findsOneWidget);
    });

    testWidgets('reel of a non-Featured business shows NO badge', (
      tester,
    ) async {
      await _pumpReel(tester, _reel.copyWith(isFeatured: false));
      expect(find.text('Al Ananka Store'), findsOneWidget);
      expect(find.byType(FeaturedBadge), findsNothing);
    });
  });
}
'@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path (Get-Location) $target), $content, $utf8NoBom)
Write-Host "[CREATE] $target" -ForegroundColor Green
Write-Host "P-110 STEP 4 script finished. Now run flutter test / flutter analyze."