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
import 'package:social_commerce_app/features/content/presentation/post_card.dart';
import 'package:social_commerce_app/features/content/presentation/reel_card.dart';
import 'package:social_commerce_app/features/products/data/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_public_repository.dart';

/// Part P-045 (STEP 7) scope: covers this part's own explicit acceptance
/// criterion — "the business profile screen's new section ... only ever
/// requests/displays what the public repository returns ... confirm the
/// screen trusts and correctly displays whatever the public endpoint
/// returns, without needing its own redundant filter." A profile fetch
/// is resolved once, fixed, in every test here — only the Post/Reel
/// repositories vary — so these tests isolate [_PostsSection]/
/// [_ReelsSection] behavior from `business_profile_public_screen_test.dart`'s
/// own header-focused assertions.

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

/// Configurable fake: [postsResult] is handed back verbatim as the
/// `/public/` list page — exactly the "backend already only returns
/// published rows" contract `PostPublicRepositoryImpl.fetchBusinessPosts`
/// (Part P-045, STEP 1) is built on. [postsError], when set, is thrown
/// as-is, same convention as this project's other hand-rolled fakes.
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

/// See [_FakePostPublicRepository]'s doc — identical shape, for Reel.
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
      ],
      child: const MaterialApp(
        home: BusinessProfilePublicScreen(businessId: '7'),
      ),
    ),
  );
}

void main() {
  group('BusinessProfilePublicScreen — Posts section', () {
    testWidgets(
      'lists every post the repository returns, trusting it as already '
      'published — no client-side re-filtering',
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

        expect(find.byType(PostCard), findsNWidgets(3));
        expect(find.text('First post.'), findsOneWidget);
        expect(find.text('Second post.'), findsOneWidget);
        expect(find.text('Third post.'), findsOneWidget);
      },
    );

    testWidgets(
      'an empty Posts result shows the section\'s own empty state, not a '
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
        expect(find.byType(PostCard), findsNothing);
      },
    );

    testWidgets(
      'a Posts fetch failure shows an inline, retryable error scoped to '
      'the Posts section, without hiding the rest of the profile',
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

        // The rest of the profile still renders — a Posts failure never
        // replaces the whole screen.
        expect(find.text('Al Ananka Store'), findsOneWidget);
        expect(find.text('Posts unavailable.'), findsOneWidget);

        final retryButtons = find.widgetWithText(AppButton, 'Retry');
        expect(retryButtons, findsOneWidget);

        postRepository.postsError = null;
        postRepository.postsResult = const [
          PublicPost(id: 501, businessId: 7, caption: 'Now it loads.'),
        ];

        // The screen is a single tall SingleChildScrollView (profile
        // header + Products + Posts + Reels sections), so the Retry
        // button can render below the default test viewport's fold.
        // ensureVisible scrolls it into view before tapping — tapping a
        // widget that exists in the tree but isn't hit-testable at its
        // current screen position throws, exactly what failed here.
        await tester.ensureVisible(retryButtons);
        await tester.pumpAndSettle();

        await tester.tap(retryButtons);
        await tester.pumpAndSettle();

        expect(postRepository.fetchBusinessPostsCallCount, 2);
        expect(find.text('Now it loads.'), findsOneWidget);
      },
    );
  });

  group('BusinessProfilePublicScreen — Reels section', () {
    testWidgets(
      'lists every reel the repository returns, trusting it as already '
      'published and fully processed — no client-side re-filtering',
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

        expect(find.byType(ReelCard), findsNWidgets(2));
        expect(find.text('First reel.'), findsOneWidget);
        expect(find.text('Second reel.'), findsOneWidget);
      },
    );

    testWidgets(
      'an empty Reels result shows the section\'s own empty state',
      (tester) async {
        await _pumpScreen(
          tester,
          postRepository: _FakePostPublicRepository(),
          reelRepository: _FakeReelPublicRepository(),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('This business hasn\'t shared any reels yet.'),
          findsOneWidget,
        );
        expect(find.byType(ReelCard), findsNothing);
      },
    );

    testWidgets(
      'a Reels fetch failure shows an inline, retryable error scoped to '
      'the Reels section only',
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

        expect(find.text('Al Ananka Store'), findsOneWidget);
        expect(find.text('Reels unavailable.'), findsOneWidget);
      },
    );
  });
}