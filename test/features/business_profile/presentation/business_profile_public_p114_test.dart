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
