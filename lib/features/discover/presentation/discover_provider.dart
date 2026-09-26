/// Part P-062 scope: `activeStoryGroupsProvider` and `discoverFeedProvider`
/// -- the two providers `DiscoverScreen` (a later step) is built on.
///
/// ### `activeStoryGroupsProvider` -- who to put in the stories bar
///
/// `FutureProvider.autoDispose`, same "first page only, autoDispose,
/// retry disabled" convention as `businessStoriesProvider`
/// (`stories/presentation/story_public_provider.dart`, Part P-050).
/// Returns WHICH businesses currently have an active Story (via
/// `DiscoverRepository.fetchActiveStoryGroups`) -- `StoriesBarWidget`
/// (this part, next step) uses this list purely to know which
/// businesses to render a ring for; each `StoryRingWidget` still
/// independently fetches its own business's stories through the
/// EXISTING `businessStoriesProvider` (unmodified, per the Architecture
/// Rules), so a story that expires between this provider's fetch and
/// the ring's own fetch is still handled correctly by the ring itself
/// (which would then simply render nothing for that business) -- no
/// staleness bug from having two independent reads of overlapping data.
///
/// ### `discoverFeedProvider` -- the Recommended/general-content section
///
/// Reuses `FeedState` from `home_feed_provider.dart` (Part P-061)
/// as-is -- it is a generic "list + cursor + isLoadingMore" pagination
/// shape with no Home-specific field, so a second, duplicate class was
/// not written here. `DiscoverFeedNotifier` otherwise mirrors
/// `HomeFeedNotifier` method-for-method (`refresh()`/`loadMore()`, same
/// failure contract -- a failed `loadMore()` keeps already-loaded items
/// and rethrows -- same `autoDispose` + disabled-retry reasoning),
/// swapped only to call `DiscoverRepository.fetchDiscoverFeed` instead
/// of `FeedRepository.fetchHomeFeed`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/presentation/home_feed_provider.dart' show FeedState;
import '../data/discover_repository.dart';
import '../domain/active_story_group_entity.dart';

final activeStoryGroupsProvider =
    FutureProvider.autoDispose<List<ActiveStoryGroup>>((ref) async {
      return ref.watch(discoverRepositoryProvider).fetchActiveStoryGroups();
    }, retry: (retryCount, error) => null);

class DiscoverFeedNotifier extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final page = await ref
        .watch(discoverRepositoryProvider)
        .fetchDiscoverFeed();
    return FeedState(items: page.items, nextCursor: page.nextCursor);
  }

  /// Discards local state and fetches a genuine fresh first page --
  /// identical contract to `HomeFeedNotifier.refresh()`.
  Future<void> refresh() async {
    state = const AsyncValue<FeedState>.loading();
    state = await AsyncValue.guard<FeedState>(() async {
      final page = await ref
          .read(discoverRepositoryProvider)
          .fetchDiscoverFeed();
      return FeedState(items: page.items, nextCursor: page.nextCursor);
    });
  }

  /// Appends the next page using the current `nextCursor` -- identical
  /// contract to `HomeFeedNotifier.loadMore()`, including its failure
  /// behavior (already-loaded items are kept on a failed load-more).
  Future<void> loadMore() async {
    final current = state.value;

    if (current == null ||
        current.nextCursor == null ||
        current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final page = await ref
          .read(discoverRepositoryProvider)
          .fetchDiscoverFeed(cursor: current.nextCursor);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
          isLoadingMore: false,
          clearNextCursor: page.nextCursor == null,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
      rethrow;
    }
  }
}

/// Exposes [DiscoverFeedNotifier] to the rest of the app. `autoDispose`
/// and retry-disabled on purpose -- see the class docstring above.
final discoverFeedProvider =
    AsyncNotifierProvider.autoDispose<DiscoverFeedNotifier, FeedState>(
      DiscoverFeedNotifier.new,
      retry: (retryCount, error) => null,
    );