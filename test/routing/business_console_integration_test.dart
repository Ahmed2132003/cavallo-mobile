import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_console/data/analytics_repository.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_screen.dart';
import 'package:social_commerce_app/features/business_console/presentation/business_console_shell.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_provider.dart';
import 'package:social_commerce_app/features/categories/data/category_repository_impl.dart';
import 'package:social_commerce_app/features/categories/domain/category_entity.dart';
import 'package:social_commerce_app/features/categories/domain/category_repository.dart';
import 'package:social_commerce_app/features/content/data/post_repository_impl.dart';
import 'package:social_commerce_app/features/content/data/reel_repository_impl.dart';
import 'package:social_commerce_app/features/content/domain/post_entity.dart';
import 'package:social_commerce_app/features/content/domain/post_repository.dart';
import 'package:social_commerce_app/features/content/domain/reel_entity.dart';
import 'package:social_commerce_app/features/content/domain/reel_repository.dart';
import 'package:social_commerce_app/features/content/presentation/content_list_screen.dart';
import 'package:social_commerce_app/features/content/presentation/post_form_screen.dart';
import 'package:social_commerce_app/features/content/presentation/reel_form_screen.dart';
import 'package:social_commerce_app/features/feed/presentation/home_feed_screen.dart';
import 'package:social_commerce_app/features/products/data/product_repository_impl.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_repository.dart';
import 'package:social_commerce_app/features/products/presentation/product_form_screen.dart';
import 'package:social_commerce_app/features/products/presentation/product_list_screen.dart';
import 'package:social_commerce_app/features/stories/data/own_stories_repository.dart';
import 'package:social_commerce_app/features/stories/data/story_creation_repository.dart';
import 'package:social_commerce_app/features/stories/domain/own_stories_repository.dart';
import 'package:social_commerce_app/features/stories/domain/own_story_entity.dart';
import 'package:social_commerce_app/features/stories/presentation/story_creation_screen.dart';
import 'package:social_commerce_app/features/stories/presentation/story_list_screen.dart';
import 'package:social_commerce_app/features/stories/presentation/story_upload_queue_provider.dart';
import 'package:social_commerce_app/main.dart';
import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/route_names.dart';

import '../features/business_console/fake_analytics_repository.dart';

/// Part P-083 (Chat 4, phase B): end-to-end router integration test for
/// the Business Console.
///
/// Unlike `business_console_router_gate_test.dart` (which proves WHO may
/// enter, and is not repeated here) and `business_console_shell_test.dart`
/// (which proves the shell widget against fake pages), this file runs the
/// REAL `SocialCommerceApp` + REAL `appRouterProvider` + the REAL screens
/// behind every destination, and proves:
///
///  1. each of the four destinations opens the expected real screen;
///  2. the create/edit forms open ABOVE the shell and, when dismissed,
///     land the user back on the same tab (decision D6);
///  3. the story-upload banner sits above all four tabs (decision D3);
///  4. entering through `pushNamed` (the way the Home debug-menu button
///     navigates) lands on Products and popping returns to Home;
///  5. a Customer cannot enter the console, even through `pushNamed`.
///
/// Only the network edge is faked (repositories). Every screen, route,
/// redirect and provider above that is the production one.
///
/// ### Why `go` (not `push`) is the default way in
///
/// After an imperative `push`, `routerDelegate.currentConfiguration.uri`
/// keeps reporting the base location (`/home`) even though the pushed
/// page is on screen. Tests that assert the location therefore enter the
/// console with `go`, like `business_console_router_gate_test.dart`. The
/// `pushNamed` entry is covered by its own test, which asserts on the
/// widgets and the selected tab instead of the location.
///
/// ### Regression this file guards
///
/// `ProductListScreen` and `StoryListScreen` both have a
/// `FloatingActionButton.extended`. Alive together in the shell's
/// IndexedStack with the default hero tag they made Flutter assert when a
/// route was pushed above the shell. `StoryListScreen` now sets an
/// explicit `heroTag`; the "Stories: Create Story" test below fails
/// without it.

const _navBarKey = Key('business-console-nav-bar');
const _navProducts = Key('business-console-nav-products');
const _navContent = Key('business-console-nav-content');
const _navStories = Key('business-console-nav-stories');
const _navAnalytics = Key('business-console-nav-analytics');
const _bannerKey = Key('storyUploadStatusBanner');

const _customer = User(
  id: 1,
  email: 'customer@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

const _business = User(
  id: 2,
  email: 'business@example.com',
  accountType: AccountType.business,
  isModerator: false,
  isStaff: false,
);

const _profile = BusinessProfile(
  id: 1,
  businessName: 'Ahmed Trading Co.',
  businessType: BusinessType.trader,
  country: 'Egypt',
  city: 'Cairo',
  isVerified: false,
);

class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._initial);

  final User? _initial;

  @override
  Future<User?> build() async => _initial;
}

class _FakeBusinessProfileNotifier extends BusinessProfileNotifier {
  _FakeBusinessProfileNotifier(this._initial);

  final BusinessProfile? _initial;

  @override
  Future<BusinessProfile?> build() async => _initial;
}

class _FakeProductRepository implements ProductRepository {
  @override
  Future<PaginatedResponse<Product>> fetchOwnProducts() async =>
      const PaginatedResponse<Product>(results: [], next: null, previous: null);

  @override
  Future<Product> createProduct({
    required int categoryId,
    required String name,
    required String description,
    required String price,
    required Currency currency,
    File? imageFile,
    bool isActive = true,
  }) => throw UnimplementedError('Not exercised by this test');

  @override
  Future<Product> updateProduct({
    required int productId,
    int? categoryId,
    String? name,
    String? description,
    String? price,
    Currency? currency,
    File? imageFile,
    bool? isActive,
  }) => throw UnimplementedError('Not exercised by this test');

  @override
  Future<void> deleteProduct(int productId) async {}
}

class _FakeCategoryRepository implements CategoryRepository {
  @override
  Future<List<CategoryNode>> fetchCategoryTree({
    bool forceRefresh = false,
  }) async => const [];
}

class _FakePostRepository implements PostRepository {
  @override
  Future<PaginatedResponse<Post>> fetchOwnPosts() async =>
      const PaginatedResponse<Post>(results: [], next: null, previous: null);

  @override
  Future<Post> createPost({required String caption, File? imageFile}) =>
      throw UnimplementedError('Not exercised by this test');
}

class _FakeReelRepository implements ReelRepository {
  @override
  Future<PaginatedResponse<Reel>> fetchOwnReels() async =>
      const PaginatedResponse<Reel>(results: [], next: null, previous: null);

  @override
  Future<Reel> createReel({required String caption, required File videoFile}) =>
      throw UnimplementedError('Not exercised by this test');
}

class _FakeOwnStoriesRepository implements OwnStoriesRepository {
  @override
  Future<PaginatedResponse<OwnStory>> listOwnStories() async =>
      const PaginatedResponse<OwnStory>(
        results: [],
        next: null,
        previous: null,
      );
}

/// Never resolves: keeps an enqueued upload in the `uploading` state
/// deterministically (same technique as `business_console_shell_test.dart`).
class _NeverCompletesCreationRepository extends StoryCreationRepository {
  _NeverCompletesCreationRepository() : super(dio: Dio());

  @override
  Future<void> uploadStoryMedia({
    required File mediaFile,
    CancelToken? cancelToken,
  }) {
    return Completer<void>().future;
  }
}

class _App {
  _App(this.container);

  final ProviderContainer container;

  GoRouter get router => container.read(appRouterProvider);

  String get path => router.routerDelegate.currentConfiguration.uri.toString();
}

Future<_App> _pumpApp(
  WidgetTester tester, {
  required User user,
  BusinessProfile? profile,
}) async {
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSessionNotifier(user)),
      businessProfileProvider.overrideWith(
        () => _FakeBusinessProfileNotifier(profile),
      ),
      productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
      categoryRepositoryProvider.overrideWith(
        (ref) => _FakeCategoryRepository(),
      ),
      postRepositoryProvider.overrideWithValue(_FakePostRepository()),
      reelRepositoryProvider.overrideWithValue(_FakeReelRepository()),
      ownStoriesRepositoryProvider.overrideWithValue(
        _FakeOwnStoriesRepository(),
      ),
      analyticsRepositoryProvider.overrideWithValue(
        FakeAnalyticsRepository(stats: knownTrendStats()),
      ),
      storyCreationRepositoryProvider.overrideWithValue(
        _NeverCompletesCreationRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SocialCommerceApp(),
    ),
  );
  await tester.pumpAndSettle();

  return _App(container);
}

/// Opens the console with `go` (see the file doc for why): the
/// `businessConsole` route redirects to the Products tab.
Future<void> _enterConsole(WidgetTester tester, _App app) async {
  app.router.go(RouteNames.businessConsolePath);
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, Key navKey) async {
  await tester.tap(find.byKey(navKey));
  await tester.pumpAndSettle();
}

int _selectedIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byKey(_navBarKey)).selectedIndex;

Finder _appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

class _Destination {
  const _Destination({
    required this.name,
    required this.navKey,
    required this.index,
    required this.path,
    required this.screen,
    required this.appBarTitle,
  });

  final String name;
  final Key navKey;
  final int index;
  final String path;
  final Type screen;
  final String appBarTitle;
}

const _destinations = <_Destination>[
  _Destination(
    name: 'Products',
    navKey: _navProducts,
    index: 0,
    path: RouteNames.productListPath,
    screen: ProductListScreen,
    appBarTitle: 'My Products',
  ),
  _Destination(
    name: 'Posts/Reels',
    navKey: _navContent,
    index: 1,
    path: RouteNames.contentListPath,
    screen: ContentListScreen,
    appBarTitle: 'My Content',
  ),
  _Destination(
    name: 'Stories',
    navKey: _navStories,
    index: 2,
    path: RouteNames.storyListPath,
    screen: StoryListScreen,
    appBarTitle: 'Stories',
  ),
  _Destination(
    name: 'Analytics',
    navKey: _navAnalytics,
    index: 3,
    path: RouteNames.businessAnalyticsPath,
    screen: AnalyticsScreen,
    appBarTitle: 'Analytics',
  ),
];

void main() {
  group('Business Console integration (Part P-083) — Business account', () {
    testWidgets('entering the console lands on Products, and each of the four '
        'destinations opens its real screen', (tester) async {
      final app = await _pumpApp(tester, user: _business, profile: _profile);
      await _enterConsole(tester, app);

      expect(find.byType(BusinessConsoleShell), findsOneWidget);
      expect(app.path, RouteNames.productListPath);
      expect(_selectedIndex(tester), 0);

      for (final dest in _destinations) {
        await _openTab(tester, dest.navKey);

        expect(app.path, dest.path, reason: '${dest.name}: wrong location');
        expect(
          _selectedIndex(tester),
          dest.index,
          reason: '${dest.name}: wrong selected tab',
        );
        expect(
          find.byType(dest.screen),
          findsOneWidget,
          reason: '${dest.name}: expected screen missing',
        );
        expect(
          _appBarTitle(dest.appBarTitle),
          findsOneWidget,
          reason: '${dest.name}: expected AppBar title missing',
        );

        // Only the active destination's screen is visible.
        for (final other in _destinations.where((d) => d != dest)) {
          expect(
            find.byType(other.screen),
            findsNothing,
            reason: '${other.name} must not be visible on ${dest.name}',
          );
        }
      }
    });

    testWidgets('entering via pushNamed (the Home debug-menu path) lands on '
        'Products, and popping returns to Home', (tester) async {
      final app = await _pumpApp(tester, user: _business, profile: _profile);
      expect(find.byType(HomeFeedScreen), findsOneWidget);

      app.router.pushNamed(RouteNames.businessConsole);
      await tester.pumpAndSettle();

      // Widget/tab assertions only: after a push the router's reported
      // uri is not the pushed location (see the file doc).
      expect(find.byType(BusinessConsoleShell), findsOneWidget);
      expect(find.byType(ProductListScreen), findsOneWidget);
      expect(_selectedIndex(tester), 0);

      app.router.pop();
      await tester.pumpAndSettle();

      expect(find.byType(BusinessConsoleShell), findsNothing);
      expect(find.byType(HomeFeedScreen), findsOneWidget);
    });

    testWidgets(
      'the Stories tab shows the real StoryListScreen (empty state + the '
      'Create Story button) and Analytics shows the real AnalyticsScreen '
      '(P-085: the P-083 placeholder is gone)',
      (tester) async {
        final app = await _pumpApp(tester, user: _business, profile: _profile);
        await _enterConsole(tester, app);

        await _openTab(tester, _navStories);
        expect(find.byKey(const Key('story-list-empty')), findsOneWidget);
        expect(
          find.byKey(const Key('story-list-create-button')),
          findsOneWidget,
        );

        await _openTab(tester, _navAnalytics);
        expect(find.byType(AnalyticsScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('business-analytics-placeholder')),
          findsNothing,
        );
        expect(find.text('Analytics coming soon'), findsNothing);
        // Real data from the fake: the totals are the sum of the three
        // known rows (followers 1+2+3).
        expect(
          find.descendant(
            of: find.byKey(const Key('analytics-total-new-followers')),
            matching: find.text('6'),
            matchRoot: true,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Products: the create form opens above the shell and dismissing it '
      'returns to the Products tab (D6)',
      (tester) async {
        final app = await _pumpApp(tester, user: _business, profile: _profile);
        await _enterConsole(tester, app);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.byType(ProductFormScreen), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(ProductFormScreen), findsNothing);
        expect(find.byType(ProductListScreen), findsOneWidget);
        expect(app.path, RouteNames.productListPath);
        expect(_selectedIndex(tester), 0);
      },
    );

    testWidgets(
      'Posts/Reels: New Post and New Reel open their forms above the shell '
      'and dismissing each returns to the Posts/Reels tab (D6)',
      (tester) async {
        final app = await _pumpApp(tester, user: _business, profile: _profile);
        await _enterConsole(tester, app);
        await _openTab(tester, _navContent);

        await tester.tap(find.text('New Post'));
        await tester.pumpAndSettle();
        expect(find.byType(PostFormScreen), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(PostFormScreen), findsNothing);
        expect(find.byType(ContentListScreen), findsOneWidget);
        expect(app.path, RouteNames.contentListPath);
        expect(_selectedIndex(tester), 1);

        await tester.tap(find.text('New Reel'));
        await tester.pumpAndSettle();
        expect(find.byType(ReelFormScreen), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(ReelFormScreen), findsNothing);
        expect(find.byType(ContentListScreen), findsOneWidget);
        expect(app.path, RouteNames.contentListPath);
        expect(_selectedIndex(tester), 1);
      },
    );

    testWidgets(
      'Stories: Create Story opens StoryCreationScreen above the shell '
      '(with Products already visited, so two FABs share the IndexedStack) '
      'and dismissing it returns to the Stories tab (D6)',
      (tester) async {
        final app = await _pumpApp(tester, user: _business, profile: _profile);
        // Products is built first on purpose: its FAB (default hero tag)
        // stays alive in the IndexedStack beside the Stories FAB.
        await _enterConsole(tester, app);
        await _openTab(tester, _navStories);

        await tester.tap(find.byKey(const Key('story-list-create-button')));
        await tester.pumpAndSettle();
        expect(find.byType(StoryCreationScreen), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(StoryCreationScreen), findsNothing);
        expect(find.byType(StoryListScreen), findsOneWidget);
        expect(app.path, RouteNames.storyListPath);
        expect(_selectedIndex(tester), 2);
      },
    );

    testWidgets(
      'a story upload banner shows above all four tabs while a task exists '
      'and disappears when it ends (D3)',
      (tester) async {
        final app = await _pumpApp(tester, user: _business, profile: _profile);
        await _enterConsole(tester, app);
        expect(find.byKey(_bannerKey), findsNothing);

        final queue = app.container.read(storyUploadQueueProvider.notifier);
        final taskId = queue.enqueueUpload(
          File(
            '${Directory.systemTemp.path}/p083_integration_'
            '${DateTime.now().microsecondsSinceEpoch}.png',
          ),
        );
        await tester.pump();

        for (final dest in _destinations) {
          await _openTab(tester, dest.navKey);
          expect(
            find.byKey(_bannerKey),
            findsOneWidget,
            reason: 'banner must be visible on the ${dest.name} tab',
          );
          expect(
            find.byType(dest.screen),
            findsOneWidget,
            reason: '${dest.name} screen must still render under the banner',
          );
        }

        queue.cancel(taskId);
        await tester.pump();
        expect(find.byKey(_bannerKey), findsNothing);
      },
    );
  });

  group('Business Console integration (Part P-083) — Customer account', () {
    testWidgets(
      'a Customer pushing the businessConsole route (the Home debug-menu '
      'path) stays on /home and never builds the shell',
      (tester) async {
        final app = await _pumpApp(tester, user: _customer);
        expect(find.byType(HomeFeedScreen), findsOneWidget);

        app.router.pushNamed(RouteNames.businessConsole);
        await tester.pumpAndSettle();

        expect(app.path, RouteNames.homePath);
        expect(find.byType(HomeFeedScreen), findsOneWidget);
        expect(find.byType(BusinessConsoleShell), findsNothing);
      },
    );

    testWidgets(
      'a Customer cannot reach any of the four destinations by pushing or '
      'going to their paths',
      (tester) async {
        final app = await _pumpApp(tester, user: _customer);

        for (final dest in _destinations) {
          app.router.push(dest.path);
          await tester.pumpAndSettle();
          expect(
            app.path,
            RouteNames.homePath,
            reason: 'push to ${dest.name} must be blocked',
          );

          app.router.go(dest.path);
          await tester.pumpAndSettle();
          expect(
            app.path,
            RouteNames.homePath,
            reason: 'go to ${dest.name} must be blocked',
          );

          expect(find.byType(BusinessConsoleShell), findsNothing);
          expect(find.byType(dest.screen), findsNothing);
        }
      },
    );
  });
}
