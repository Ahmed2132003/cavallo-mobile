import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
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
import 'package:social_commerce_app/features/products/data/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_public_repository.dart';

/// Hand-rolled test double for [BusinessProfilePublicRepository] — this
/// project doesn't use mockito/mocktail anywhere (confirmed against
/// PROJECT_PROGRESS.md's own P-021a note); mirrors
/// `FakeBusinessProfileRepository` (Part P-028A/B/C2,
/// `business_profile_provider_test.dart`)'s exact shape: a mutable result
/// and a mutable error, a call counter so a test can assert Retry
/// actually re-fetches.
///
/// [fetchError], when set, is thrown as-is (not wrapped in a
/// [DioException]) — deliberately matching how
/// `FakeBusinessProfileRepository` throws directly in this project's
/// existing provider tests.
///
/// [pending], when set, makes [fetchPublicProfile] await it instead of
/// resolving/throwing immediately — needed to assert the loading state
/// deterministically.
class _FakeBusinessProfilePublicRepository
    implements BusinessProfilePublicRepository {
  _FakeBusinessProfilePublicRepository({
    this.fetchResult,
    this.fetchError,
    this.pending,
  });

  BusinessProfile? fetchResult;
  Object? fetchError;
  Completer<BusinessProfile?>? pending;
  int callCount = 0;

  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async {
    callCount++;
    if (pending != null) {
      return pending!.future;
    }
    if (fetchError != null) {
      throw fetchError!;
    }
    return fetchResult;
  }
}

/// Part P-034 addition: [BusinessProfilePublicScreen] shows a products
/// section, which watches `businessProductsProvider(id)` the moment a
/// profile is rendered — and that provider calls through
/// `productPublicRepositoryProvider` to the real Dio client by default.
/// Without an override, every "profile found" test in this file would
/// silently start firing a real `GET /api/v1/products/public/`.
///
/// This file's own assertions are about the profile header (and, since
/// Part P-045, the Posts/Reels sections' OWN dedicated test file) — the
/// fake here always resolves to an empty first page, the simplest fixed
/// outcome.
class _EmptyProductPublicRepository implements ProductPublicRepository {
  @override
  Future<Product?> fetchPublicProduct(int id) async => null;

  @override
  Future<PaginatedResponse<Product>> fetchBusinessProducts(
    int businessId,
  ) async =>
      const PaginatedResponse<Product>(results: [], next: null, previous: null);
}

/// Part P-045 (STEP 7) addition: same reasoning as
/// [_EmptyProductPublicRepository], now for `businessPostsProvider`
/// (`content_public_providers.dart`, this part's STEP 6 addition) —
/// [_PostsSection] watches it the moment a profile renders. Without this
/// override every test in this file would fire a real
/// `GET /api/v1/posts/public/`. Detailed Posts-section behavior (real
/// items, empty state, error/retry) is covered by
/// `business_profile_public_content_section_test.dart` (this part, STEP
/// 7) — this fake always resolves to an empty first page.
class _EmptyPostPublicRepository implements PostPublicRepository {
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

/// See [_EmptyPostPublicRepository]'s doc — identical reasoning, for
/// `businessReelsProvider`/[_ReelsSection].
class _EmptyReelPublicRepository implements ReelPublicRepository {
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

const _profile = BusinessProfile(
  id: 7,
  businessName: 'Al Ananka Store',
  businessType: BusinessType.trader,
  country: 'Egypt',
  city: 'Cairo',
  description: 'Fashion and accessories, wholesale and retail.',
  isVerified: true,
);

const _unverifiedProfile = BusinessProfile(
  id: 8,
  businessName: 'Unverified Shop',
  businessType: BusinessType.factory,
  country: 'Egypt',
  city: 'Alexandria',
  isVerified: false,
);

/// Pumps [BusinessProfilePublicScreen] for [businessId], with
/// [businessProfilePublicRepositoryProvider] overridden to [repository],
/// and Products/Posts/Reels all overridden to empty (Part P-045, STEP 7)
/// so this file's assertions stay about the profile header only.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required String businessId,
  required _FakeBusinessProfilePublicRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessProfilePublicRepositoryProvider.overrideWithValue(repository),
        productPublicRepositoryProvider.overrideWithValue(
          _EmptyProductPublicRepository(),
        ),
        postPublicRepositoryProvider.overrideWithValue(
          _EmptyPostPublicRepository(),
        ),
        reelPublicRepositoryProvider.overrideWithValue(
          _EmptyReelPublicRepository(),
        ),
      ],
      child: MaterialApp(
        home: BusinessProfilePublicScreen(businessId: businessId),
      ),
    ),
  );
}

void main() {
  group('BusinessProfilePublicScreen — non-numeric id', () {
    testWidgets(
      'a non-numeric :id shows not-found immediately, without calling the '
      'repository',
      (tester) async {
        final repository = _FakeBusinessProfilePublicRepository(
          fetchResult: _profile,
        );

        await _pumpScreen(
          tester,
          businessId: 'sample-business-1',
          repository: repository,
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Business not found.\nIt may have been removed.'),
          findsOneWidget,
        );
        expect(repository.callCount, 0);
      },
    );
  });

  group('BusinessProfilePublicScreen — loading', () {
    testWidgets('shows a LoadingIndicator before the fetch resolves', (
      tester,
    ) async {
      final completer = Completer<BusinessProfile?>();
      final repository = _FakeBusinessProfilePublicRepository(
        pending: completer,
      );

      await _pumpScreen(tester, businessId: '7', repository: repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(_profile);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Al Ananka Store'), findsOneWidget);
    });
  });

  group('BusinessProfilePublicScreen — found', () {
    testWidgets(
      'a verified business shows its name, badge, location, description, '
      'and a disabled Follow button',
      (tester) async {
        final repository = _FakeBusinessProfilePublicRepository(
          fetchResult: _profile,
        );

        await _pumpScreen(tester, businessId: '7', repository: repository);
        await tester.pumpAndSettle();

        expect(find.text('Al Ananka Store'), findsOneWidget);
        expect(find.text('Trader'), findsOneWidget);
        expect(find.text('Cairo, Egypt'), findsOneWidget);
        expect(
          find.text('Fashion and accessories, wholesale and retail.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.verified), findsOneWidget);

        final followButton = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Follow'),
        );
        expect(followButton.onPressed, isNull);
        expect(find.text('(coming soon)'), findsOneWidget);

        // Part P-045 (STEP 6): the Posts/Reels sections render their own
        // empty states here, since the fake repositories always resolve
        // to an empty first page in this file.
        expect(
          find.text('This business hasn\'t shared any posts yet.'),
          findsOneWidget,
        );
        expect(
          find.text('This business hasn\'t shared any reels yet.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('an unverified business shows no verification badge', (
      tester,
    ) async {
      final repository = _FakeBusinessProfilePublicRepository(
        fetchResult: _unverifiedProfile,
      );

      await _pumpScreen(tester, businessId: '8', repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Unverified Shop'), findsOneWidget);
      expect(find.text('Factory'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsNothing);
    });

    testWidgets(
      'an empty description shows the placeholder copy instead of a blank '
      'space',
      (tester) async {
        final repository = _FakeBusinessProfilePublicRepository(
          fetchResult: const BusinessProfile(
            id: 9,
            businessName: 'No Description Yet',
            businessType: BusinessType.trader,
            country: 'Egypt',
            city: 'Giza',
            isVerified: false,
          ),
        );

        await _pumpScreen(tester, businessId: '9', repository: repository);
        await tester.pumpAndSettle();

        expect(
          find.text("This business hasn't added a description yet."),
          findsOneWidget,
        );
      },
    );
  });

  group('BusinessProfilePublicScreen — not found (numeric id, real 404)', () {
    testWidgets(
      'a numeric id the backend reports as 404 (fetchResult null) shows '
      'the not-found state, not a generic error',
      (tester) async {
        final repository = _FakeBusinessProfilePublicRepository(
          fetchResult: null,
        );

        await _pumpScreen(tester, businessId: '999999', repository: repository);
        await tester.pumpAndSettle();

        expect(
          find.text('Business not found.\nIt may have been removed.'),
          findsOneWidget,
        );
      },
    );
  });

  group('BusinessProfilePublicScreen — error', () {
    testWidgets(
      'a genuine failure shows the backend message and a Retry button',
      (tester) async {
        final repository = _FakeBusinessProfilePublicRepository(
          fetchError: const ServerFailure(message: 'Something broke.'),
        );

        await _pumpScreen(tester, businessId: '7', repository: repository);
        await tester.pumpAndSettle();

        expect(find.text('Something broke.'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Retry'), findsOneWidget);
        expect(
          find.text('Business not found.\nIt may have been removed.'),
          findsNothing,
        );
      },
    );

    testWidgets('tapping Retry re-invokes the repository', (tester) async {
      final repository = _FakeBusinessProfilePublicRepository(
        fetchError: const ServerFailure(message: 'Something broke.'),
      );

      await _pumpScreen(tester, businessId: '7', repository: repository);
      await tester.pumpAndSettle();

      expect(repository.callCount, 1);

      repository.fetchError = null;
      repository.fetchResult = _profile;

      await tester.tap(find.widgetWithText(AppButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
      expect(find.text('Al Ananka Store'), findsOneWidget);
    });
  });
}