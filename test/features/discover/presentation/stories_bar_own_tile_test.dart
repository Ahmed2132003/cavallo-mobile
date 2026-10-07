import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/discover/data/discover_repository.dart';
import 'package:social_commerce_app/features/discover/domain/active_story_group_entity.dart';
import 'package:social_commerce_app/features/discover/domain/discover_repository.dart';
import 'package:social_commerce_app/features/discover/presentation/stories_bar_widget.dart';
import 'package:social_commerce_app/features/feed/domain/feed_page_entity.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-114 STEP 1: the Business "your story" tile of the stories tray.
class _FakeDiscoverRepository implements DiscoverRepository {
  _FakeDiscoverRepository(this.groups);

  final List<ActiveStoryGroup> groups;

  @override
  Future<List<ActiveStoryGroup>> fetchActiveStoryGroups() async => groups;

  @override
  Future<FeedPage> fetchDiscoverFeed({String? cursor}) =>
      throw UnimplementedError('Not exercised by these tests');
}

class _FakeBusinessProfileRepository
    implements BusinessProfilePublicRepository {
  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async {
    return BusinessProfile(
      id: id,
      businessName: 'Alpha Traders',
      businessType: BusinessType.trader,
      country: 'Egypt',
      city: 'Cairo',
      isVerified: false,
    );
  }
}

class _FakeStoryRepository implements StoryPublicRepository {
  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async {
    return PaginatedResponse<PublicStory>(
      results: <PublicStory>[
        PublicStory(
          id: 1,
          businessId: businessId,
          mediaUrl: 'https://cdn.example.com/stories/1.jpg',
          publishedAt: DateTime(2026, 1, 1),
          expiresAt: DateTime(2026, 1, 2),
        ),
      ],
      next: null,
      previous: null,
    );
  }

  @override
  Future<void> recordView(int storyId) async {}
}

Widget _wrap({
  required bool showOwnStoryTile,
  required List<ActiveStoryGroup> groups,
  TextDirection direction = TextDirection.ltr,
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: <RouteBase>[
      GoRoute(
        path: '/home',
        builder:
            (BuildContext context, GoRouterState state) => Scaffold(
              body: StoriesBarWidget(showOwnStoryTile: showOwnStoryTile),
            ),
      ),
      GoRoute(
        path: '/form',
        name: RouteNames.storyForm,
        builder:
            (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('STORY_FORM')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      discoverRepositoryProvider.overrideWithValue(
        _FakeDiscoverRepository(groups),
      ),
      businessProfilePublicRepositoryProvider.overrideWithValue(
        _FakeBusinessProfileRepository(),
      ),
      storyPublicRepositoryProvider.overrideWithValue(_FakeStoryRepository()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder:
          (BuildContext context, Widget? app) =>
              Directionality(textDirection: direction, child: app!),
    ),
  );
}

void main() {
  testWidgets('Business: the tile shows even with no active stories and opens '
      'the story form', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(showOwnStoryTile: true, groups: <ActiveStoryGroup>[]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your story'), findsOneWidget);

    await tester.tap(find.text('Your story'));
    await tester.pumpAndSettle();
    expect(find.text('STORY_FORM'), findsOneWidget);
  });

  testWidgets('Customer: no tile, and nothing at all without stories', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(showOwnStoryTile: false, groups: <ActiveStoryGroup>[]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your story'), findsNothing);
  });

  testWidgets('LTR: the own tile comes before (left of) the first ring', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        showOwnStoryTile: true,
        groups: <ActiveStoryGroup>[ActiveStoryGroup(businessId: 5, stories: [])],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('Your story')).dx,
      lessThan(tester.getCenter(find.text('Alpha Traders')).dx),
    );
  });

  testWidgets('RTL: the own tile comes before (right of) the first ring', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        showOwnStoryTile: true,
        groups: <ActiveStoryGroup>[ActiveStoryGroup(businessId: 5, stories: [])],
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('Your story')).dx,
      greaterThan(tester.getCenter(find.text('Alpha Traders')).dx),
    );
  });
}