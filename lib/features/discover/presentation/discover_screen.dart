/// Part P-062 scope (STEP 5): the real `/discover` screen, replacing
/// Part P-007's placeholder (same file path, same `DiscoverScreen`
/// class name/constructor - `app_router.dart`'s existing `GoRoute` for
/// `RouteNames.discoverPath` needs no edit at all).
///
/// Composes [StoriesBarWidget] as the first item of one single scrollable,
/// with the Recommended/general-content section - backed by
/// `discoverFeedProvider` - filling the rest. One [ScrollController] and one
/// [RefreshIndicator] cover both, so the 80%-threshold infinite-scroll and
/// pull-to-refresh behavior mirror `HomeFeedScreen` (Part P-061) exactly.
///
/// ### Pull-to-refresh refreshes BOTH sections
///
/// [_handleRefresh] awaits `discoverFeedProvider.notifier.refresh()` AND
/// synchronously calls `ref.invalidate(activeStoryGroupsProvider)` so the
/// stories bar re-fetches too.
///
/// ### Same known pull-to-refresh trade-off as Home
///
/// `refresh()` sets `state` to a bare `AsyncValue.loading()`, so the
/// top-level `switch` briefly shows the skeleton during a manual pull.
///
/// ### Part P-114 STEP 3B (presentation only)
///
/// * The Recommended section is a 3-column grid of square tiles (posts and
///   reels mixed, in server order) instead of full cards: Explore is for
///   browsing, the card is one tap away. A reel tile carries the video badge.
/// * A tile of a Featured business carries the single [FeaturedBadge]; tiles
///   of other businesses are listed exactly the same way.
/// * Skeleton tiles ([AppShimmerBox]) replace the spinners (first load and
///   load-more).
/// * Taps open the SAME routes as before (`postDetail` / `reelDetail`); each
///   tile still resolves its own business name through
///   `businessProfilePublicProvider` for its screen-reader label.
/// * Test hooks: each tile is wrapped in a `ValueKey('discover-post-<id>')` /
///   `ValueKey('discover-reel-<id>')`.
/// No provider, repository, route or callback changed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/featured_badge.dart';
import '../../../core/widgets/grid_tile_media.dart';
import '../../../routing/route_names.dart';
import '../../business_profile/presentation/business_profile_public_provider.dart';
import '../../feed/domain/feed_item_entity.dart';
import '../../feed/presentation/home_feed_provider.dart' show FeedState;
import 'discover_provider.dart';
import 'discover_search_bar.dart';
import 'stories_bar_widget.dart';

/// 3 equal columns with a thin gap, like the profile grids.
const SliverGridDelegate _gridDelegate =
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
    );

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Identical 80%-of-scrollable-extent threshold as `HomeFeedScreen`
  /// (Part P-061) - see that screen's own docstring for why
  /// `loadMore()` itself needs no separate in-flight guard here.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    final threshold = position.maxScrollExtent * 0.8;
    if (position.pixels >= threshold) {
      ref.read(discoverFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(discoverFeedProvider);

    return Scaffold(
      // Part P-113 (STEP 6A): the title is the search entry point.
      appBar: AppBar(title: const DiscoverSearchBar()),
      body: switch (feedAsync) {
        AsyncData(value: final state) => _DiscoverBody(
          state: state,
          scrollController: _scrollController,
        ),
        AsyncError() => const _LoadErrorView(),
        _ => const _DiscoverSkeleton(),
      },
    );
  }
}

/// The loaded (or loading-more) Recommended section, with
/// [StoriesBarWidget] as the first sliver of the same scrollable - see this
/// file's own doc above for why both sit under one `RefreshIndicator`/
/// `ScrollController` pair rather than two separate scroll regions.
class _DiscoverBody extends ConsumerWidget {
  const _DiscoverBody({required this.state, required this.scrollController});

  final FeedState state;
  final ScrollController scrollController;

  Future<void> _handleRefresh(WidgetRef ref) {
    ref.invalidate(activeStoryGroupsProvider);
    return ref.read(discoverFeedProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleRefresh() => _handleRefresh(ref);
    final l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsetsDirectional.only(top: 12, bottom: 12),
              child: StoriesBarWidget(),
            ),
          ),
          if (state.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                message: l10n.discoverEmpty,
                icon: Icons.explore_outlined,
              ),
            )
          else ...<Widget>[
            SliverGrid(
              gridDelegate: _gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) =>
                    _DiscoverTile(item: state.items[index]),
                childCount: state.items.length,
              ),
            ),
            if (state.isLoadingMore)
              SliverGrid(
                gridDelegate: _gridDelegate,
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) =>
                      const AppShimmerBox(borderRadius: 0),
                  childCount: 3,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One Recommended-section tile. Resolves its own business name through
/// `businessProfilePublicProvider` (Part P-029) independently of every other
/// tile - used for the screen-reader label - then opens the same detail
/// route the card used to open.
class _DiscoverTile extends ConsumerWidget {
  const _DiscoverTile({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profileAsync = ref.watch(
      businessProfilePublicProvider(item.businessId),
    );
    final businessName = switch (profileAsync) {
      AsyncData(value: final profile) =>
        profile?.businessName ?? l10n.businessUnknownName,
      _ => '',
    };

    final Key key;
    final Widget tile;
    final bool featured;
    switch (item) {
      case PostFeedItem(:final post):
        key = ValueKey<String>('discover-post-${post.id}');
        featured = post.isFeatured;
        tile = GridTileMedia(
          imageUrl: post.imageUrl,
          semanticLabel: l10n.feedPostMediaLabel(businessName),
          onTap: () => context.pushNamed(
            RouteNames.postDetail,
            pathParameters: {RouteNames.idParam: '${post.id}'},
          ),
        );
      case ReelFeedItem(:final reel):
        key = ValueKey<String>('discover-reel-${reel.id}');
        featured = reel.isFeatured;
        tile = GridTileMedia(
          imageUrl: reel.thumbnailUrl,
          badge: GridTileBadge.video,
          semanticLabel: l10n.feedReelMediaLabel(businessName),
          onTap: () => context.pushNamed(
            RouteNames.reelDetail,
            pathParameters: {RouteNames.idParam: '${reel.id}'},
          ),
        );
    }

    return KeyedSubtree(
      key: key,
      child: featured
          ? Stack(
              fit: StackFit.expand,
              children: <Widget>[
                tile,
                const PositionedDirectional(
                  bottom: 6,
                  start: 6,
                  child: FeaturedBadge(),
                ),
              ],
            )
          : tile,
    );
  }
}

/// First-load placeholder: a grid of skeleton tiles (no spinner).
class _DiscoverSkeleton extends StatelessWidget {
  const _DiscoverSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.profileGridLoadingLabel,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: _gridDelegate,
        itemCount: 18,
        itemBuilder: (BuildContext context, int index) =>
            const AppShimmerBox(borderRadius: 0),
      ),
    );
  }
}

/// A genuine first-load failure - retryable, same convention as
/// `HomeFeedScreen._LoadErrorView`: `discoverFeedProvider` also has
/// automatic retry disabled, so this button is the only thing that retries.
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      message: context.l10n.discoverLoadFailed,
      onRetry: () => ref.invalidate(discoverFeedProvider),
    );
  }
}
