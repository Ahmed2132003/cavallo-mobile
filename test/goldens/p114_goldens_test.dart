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

Widget _app(_Combo c, Widget home, {List<dynamic> overrides = const []}) {
  return ProviderScope(
    overrides: [...overrides],
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
