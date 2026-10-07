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
