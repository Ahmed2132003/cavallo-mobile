import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/feed/data/feed_repository.dart';
import 'package:social_commerce_app/features/feed/domain/feed_item_entity.dart';
import 'package:social_commerce_app/features/feed/domain/feed_page_entity.dart';
import 'package:social_commerce_app/features/feed/domain/feed_repository.dart';
import 'package:social_commerce_app/features/feed/presentation/home_feed_provider.dart';

/// A hand-written fake — no mocking package needed for this narrow an
/// interface, same convention as other provider-level tests in this
/// project that fake a single-method repository directly.
class _FakeFeedRepository implements FeedRepository {
  _FakeFeedRepository(this.pages);

  /// Keyed by the cursor that should return it (`null` = first page).
  final Map<String?, FeedPage> pages;
  int callCount = 0;
  final List<String?> cursorsRequested = [];

  @override
  Future<FeedPage> fetchHomeFeed({String? cursor}) async {
    callCount++;
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

void main() {
  test('build() loads the first page with a null cursor', () async {
    final fake = _FakeFeedRepository({
      null: FeedPage(items: [_post(1), _post(2)], nextCursor: 'cursor-a'),
    });
    final container = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final state = await container.read(homeFeedProvider.future);

    expect(state.items, hasLength(2));
    expect(state.nextCursor, 'cursor-a');
    expect(state.isLoadingMore, isFalse);
    expect(fake.cursorsRequested, [null]);
  });

  test(
    'loadMore() appends items and advances the cursor, using the '
    'exact cursor string returned by the previous page',
    () async {
      final fake = _FakeFeedRepository({
        null: FeedPage(items: [_post(1)], nextCursor: 'cursor-a'),
        'cursor-a': FeedPage(items: [_post(2)], nextCursor: 'cursor-b'),
      });
      final container = ProviderContainer(
        overrides: [feedRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      await container.read(homeFeedProvider.future);

      await container.read(homeFeedProvider.notifier).loadMore();

      final state = container.read(homeFeedProvider).value!;
      expect(state.items.map((i) => i.id), [1, 2]);
      expect(state.nextCursor, 'cursor-b');
      expect(state.isLoadingMore, isFalse);
      expect(fake.cursorsRequested, [null, 'cursor-a']);
    },
  );

  test('loadMore() is a no-op once nextCursor is null', () async {
    final fake = _FakeFeedRepository({
      null: FeedPage(items: [_post(1)], nextCursor: null),
    });
    final container = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(homeFeedProvider.future);

    await container.read(homeFeedProvider.notifier).loadMore();

    expect(fake.callCount, 1); // only the initial build() call
  });

  test('refresh() discards local state and re-fetches page 1', () async {
    final fake = _FakeFeedRepository({
      null: FeedPage(items: [_post(1), _post(2)], nextCursor: 'cursor-a'),
    });
    final container = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(homeFeedProvider.future);

    await container.read(homeFeedProvider.notifier).refresh();

    final state = container.read(homeFeedProvider).value!;
    expect(state.items, hasLength(2));
    expect(fake.cursorsRequested.first, isNull);
  });
}