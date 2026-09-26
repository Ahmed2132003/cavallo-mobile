import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/discover/data/discover_repository.dart';
import 'package:social_commerce_app/features/discover/domain/active_story_group_entity.dart';
import 'package:social_commerce_app/features/discover/domain/discover_repository.dart';
import 'package:social_commerce_app/features/discover/presentation/stories_bar_widget.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-062 scope (STEP 4 tests). Hand-rolled fakes only, mirroring
/// `home_feed_screen_test.dart`'s (Part P-061) exact convention.
class _FakeDiscoverRepository implements DiscoverRepository {
  _FakeDiscoverRepository(this.groups);

  final List<ActiveStoryGroup> groups;

  @override
  Future<List<ActiveStoryGroup>> fetchActiveStoryGroups() async => groups;

  @override
  Future<dynamic> fetchDiscoverFeed({String? cursor}) =>
      throw UnimplementedError('Not exercised by StoriesBarWidget tests');
}

class _FakeBusinessProfilePublicRepository
    implements BusinessProfilePublicRepository {
  _FakeBusinessProfilePublicRepository(this.namesById);

  final Map<int, String> namesById;

  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async {
    final name = namesById[id];
    if (name == null) return null;
    return BusinessProfile(
      id: id,
      businessName: name,
      businessType: BusinessType.trader,
      country: 'Egypt',
      city: 'Cairo',
      isVerified: false,
    );
  }
}

class _FakeStoryPublicRepository implements StoryPublicRepository {
  _FakeStoryPublicRepository(this.storiesByBusiness);

  final Map<int, List<PublicStory>> storiesByBusiness;

  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async {
    return PaginatedResponse<PublicStory>(
      results: storiesByBusiness[businessId] ?? [],
      next: null,
      previous: null,
    );
  }

  @override
  Future<void> recordView(int storyId) async {}
}

PublicStory _story(int id, int businessId) => PublicStory(
  id: id,
  businessId: businessId,
  mediaUrl: 'https://cdn.example.com/stories/$id.jpg',
  publishedAt: DateTime(2026, 1, 1),
  expiresAt: DateTime(2026, 1, 2),
);

Widget _wrap({
  required List<ActiveStoryGroup> groups,
  required Map<int, String> businessNames,
  required Map<int, List<PublicStory>> storiesByBusiness,
}) {
  final router = GoRouter(
    initialLocation: '/discover',
    routes: [
      GoRoute(
        path: '/discover',
        name: 'discover',
        builder: (context, state) =>
            const Scaffold(body: StoriesBarWidget()),
      ),
      GoRoute(
        path: RouteNames.storyViewerPath,
        name: RouteNames.storyViewer,
        builder: (context, state) => Scaffold(
          body: Text('STORY_VIEWER_${state.pathParameters[RouteNames.idParam]}'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      discoverRepositoryProvider.overrideWithValue(
        _FakeDiscoverRepository(groups),
      ),
      businessProfilePublicRepositoryProvider.overrideWithValue(
        _FakeBusinessProfilePublicRepository(businessNames),
      ),
      storyPublicRepositoryProvider.overrideWithValue(
        _FakeStoryPublicRepository(storiesByBusiness),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('renders one ring per business with an active story', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        groups: [
          ActiveStoryGroup(businessId: 5, stories: [_story(1, 5)]),
          ActiveStoryGroup(businessId: 6, stories: [_story(2, 6)]),
        ],
        businessNames: {5: 'Alpha Traders', 6: 'Beta Factory'},
        storiesByBusiness: {
          5: [_story(1, 5)],
          6: [_story(2, 6)],
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha Traders'), findsOneWidget);
    expect(find.text('Beta Factory'), findsOneWidget);
  });

  testWidgets('renders nothing when there are no active story groups', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(groups: [], businessNames: {}, storiesByBusiness: {}),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SizedBox), findsWidgets);
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('tapping a ring navigates to the story viewer for that business', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        groups: [
          ActiveStoryGroup(businessId: 5, stories: [_story(1, 5)]),
        ],
        businessNames: {5: 'Alpha Traders'},
        storiesByBusiness: {
          5: [_story(1, 5)],
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha Traders'));
    await tester.pumpAndSettle();

    expect(find.text('STORY_VIEWER_5'), findsOneWidget);
  });
}