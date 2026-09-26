import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/discover/data/discover_repository.dart';
import 'package:social_commerce_app/features/discover/domain/active_story_group_entity.dart';
import 'package:social_commerce_app/features/discover/domain/discover_repository.dart';
import 'package:social_commerce_app/features/discover/presentation/discover_provider.dart';
import 'package:social_commerce_app/features/feed/domain/feed_item_entity.dart';
import 'package:social_commerce_app/features/feed/domain/feed_page_entity.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';

/// Part P-062 scope. Mirrors `home_feed_provider_test.dart`'s (Part
/// P-061) exact hand-rolled-fake convention -- no mocking package.
class _FakeDiscoverRepository implements DiscoverRepository {
  _FakeDiscoverRepository({this.groups = const [], Map<String?, FeedPage>? pages})
    : pages = pages ?? {};

  List<ActiveStoryGroup> groups;
  Map<String?, FeedPage> pages;
  final List<String?> cursorsRequested = [];

  @override
  Future<List<ActiveStoryGroup>> fetchActiveStoryGroups() async => groups;

  @override
  Future<FeedPage> fetchDiscoverFeed({String? cursor}) async {
    cursorsRequested.add(cursor);
    final page = pages[cursor];
    if (page == null) {
      throw StateError('Unexpected cursor requested: $cursor');
    }
    return page;
  }
}

PostFeedItem _post(int id) =>
    PostFeedItem(PublicPost(id: id, businessId: 1, caption: 'caption $id'));

PublicStory _story(int id, int businessId) => PublicStory(
  id: id,
  businessId: businessId,
  mediaUrl: 'https://cdn.example.com/stories/$id.jpg',
  publishedAt: DateTime(2026, 1, 1),
  expiresAt: DateTime(2026, 1, 2),
);

void main() {
  group('activeStoryGroupsProvider', () {
    test('returns the groups the repository provides', () async {
      final fake = _FakeDiscoverRepository(
        groups: [
          ActiveStoryGroup(businessId: 5, stories: [_story(1, 5)]),
        ],
      );
      final container = ProviderContainer(
        overrides: [discoverRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final groups = await container.read(activeStoryGroupsProvider.future);

      expect(groups, hasLength(1));
      expect(groups.single.businessId, 5);
    });

    test('an empty repository result yields an empty list', () async {
      final fake = _FakeDiscoverRepository();
      final container = ProviderContainer(
        overrides: [discoverRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final groups = await container.read(activeStoryGroupsProvider.future);

      expect(groups, isEmpty);
    });
  });

  group('discoverFeedProvider', () {
    test('build() loads the first page with a null cursor', () async {
      final fake = _FakeDiscoverRepository(
        pages: {null: FeedPage(items: [_post(1), _post(2)], nextCursor: 'cursor-a')},
      );
      final container = ProviderContainer(
        overrides: [discoverRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final state = await container.read(discoverFeedProvider.future);

      expect(state.items, hasLength(2));
      expect(state.nextCursor, 'cursor-a');
      expect(fake.cursorsRequested, [null]);
    });

    test(
      'loadMore() appends items and advances the cursor, using the '
      'exact cursor string returned by the previous page',
      () async {
        final fake = _FakeDiscoverRepository(
          pages: {
            null: FeedPage(items: [_post(1)], nextCursor: 'cursor-a'),
            'cursor-a': FeedPage(items: [_post(2)], nextCursor: null),
          },
        );
        final container = ProviderContainer(
          overrides: [discoverRepositoryProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);
        await container.read(discoverFeedProvider.future);

        await container.read(discoverFeedProvider.notifier).loadMore();

        final state = container.read(discoverFeedProvider).value!;
        expect(state.items.map((i) => i.id), [1, 2]);
        expect(state.nextCursor, isNull);
        expect(fake.cursorsRequested, [null, 'cursor-a']);
      },
    );

    test('refresh() discards local state and re-fetches page 1', () async {
      final fake = _FakeDiscoverRepository(
        pages: {null: FeedPage(items: [_post(1)], nextCursor: 'cursor-a')},
      );
      final container = ProviderContainer(
        overrides: [discoverRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      await container.read(discoverFeedProvider.future);

      fake.pages[null] = FeedPage(items: [_post(9)], nextCursor: null);
      await container.read(discoverFeedProvider.notifier).refresh();

      final state = container.read(discoverFeedProvider).value!;
      expect(state.items.map((i) => i.id), [9]);
      expect(fake.cursorsRequested, [null, null]);
    });
  });
}