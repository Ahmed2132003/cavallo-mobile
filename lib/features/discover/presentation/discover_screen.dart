/// Part P-062 scope (STEP 5): the real `/discover` screen, replacing
/// Part P-007's placeholder (same file path, same `DiscoverScreen`
/// class name/constructor — `app_router.dart`'s existing `GoRoute` for
/// `RouteNames.discoverPath` needs no edit at all).
///
/// Composes [StoriesBarWidget] (STEP 4, `story_ring_widget.dart` reused
/// unmodified) as the first row of one single scrollable list, with the
/// Recommended/general-content section — backed by `discoverFeedProvider`
/// (STEP 3) — filling the rest. One [ScrollController] and one
/// [RefreshIndicator] cover both, so the 80%-threshold infinite-scroll
/// and pull-to-refresh behavior mirror `HomeFeedScreen` (Part P-061)
/// exactly, just offset by one header row.
///
/// ### Card reuse — zero modification
///
/// Every Recommended item renders through the existing [PostCard]/
/// [ReelCard] (Part P-045) and the exact same `businessProfilePublicProvider`
/// per-row name resolution `HomeFeedScreen._FeedListItem` already uses
/// (Part P-029) — copied verbatim, not reinvented, per this part's own
/// "no duplicated component logic" Definition of Done.
///
/// ### Pull-to-refresh refreshes BOTH sections
///
/// [_handleRefresh] awaits `discoverFeedProvider.notifier.refresh()`
/// (genuine fresh first page, same contract as Home) AND synchronously
/// calls `ref.invalidate(activeStoryGroupsProvider)` so the stories bar
/// re-fetches too — NOT `ref.refresh(activeStoryGroupsProvider.future)`,
/// to avoid relying on a `.future`-modifier + `ref.refresh` combination
/// this project's pinned flutter_riverpod (3.3.2) has not already been
/// confirmed against elsewhere in the codebase (see `story_ring_widget.dart`'s
/// own note on the same version's `.valueOrNull` gap). `invalidate` is
/// fire-and-forget: [StoriesBarWidget] renders nothing during that brief
/// re-fetch (its own documented "small, decorative" empty/loading
/// behavior), so this never blocks or flashes an error over the
/// Recommended section below it.
///
/// ### Same known pull-to-refresh trade-off as Home
///
/// Identical to `HomeFeedScreen`'s own flagged note: `refresh()` sets
/// `state` to a bare `AsyncValue.loading()` with no previous data
/// attached (`copyWithPrevious` is the same already-ruled-out internal
/// member), so the top-level `switch` briefly shows [LoadingIndicator]
/// for the Recommended section during a manual pull — not a regression
/// introduced by this part.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/route_names.dart';
import '../../business_profile/presentation/business_profile_public_provider.dart';
import '../../content/presentation/post_card.dart';
import '../../content/presentation/reel_card.dart';
import '../../feed/domain/feed_item_entity.dart';
import '../../feed/presentation/home_feed_provider.dart' show FeedState;
import 'discover_provider.dart';
import 'stories_bar_widget.dart';

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
  /// (Part P-061) — see that screen's own docstring for why
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
      appBar: AppBar(title: const Text('Discover')),
      body: switch (feedAsync) {
        AsyncData(value: final state) => _DiscoverBody(
          state: state,
          scrollController: _scrollController,
        ),
        AsyncError(:final error) => _LoadErrorView(error: error),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// The loaded (or loading-more) Recommended section, with
/// [StoriesBarWidget] as row 0 of the same scrollable — see this file's
/// own doc above for why both sit under one `RefreshIndicator`/
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

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: StoriesBarWidget(),
            ),
            SizedBox(height: 64),
            EmptyStateWidget(
              message:
                  'Nothing to discover yet.\n'
                  'Check back soon for new businesses.',
              icon: Icons.explore_outlined,
            ),
          ],
        ),
      );
    }

    // Index 0 is always the stories-bar header row; the Recommended
    // items follow at `index - 1`. One further row for the
    // bottom-of-list spinner while `isLoadingMore` — identical
    // bookkeeping to `HomeFeedScreen._FeedBody.itemCount`, just offset
    // by the header.
    final itemCount = 1 + state.items.length + (state.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: StoriesBarWidget(),
            );
          }

          final itemIndex = index - 1;
          if (itemIndex >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }
          return _DiscoverListItem(item: state.items[itemIndex]);
        },
      ),
    );
  }
}

/// One Recommended-section row. Resolves its own `businessName` through
/// `businessProfilePublicProvider` (Part P-029) independently of every
/// other row — copied from `HomeFeedScreen._FeedListItem` verbatim —
/// then delegates to [PostCard]/[ReelCard] (Part P-045) unmodified.
class _DiscoverListItem extends ConsumerWidget {
  const _DiscoverListItem({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(
      businessProfilePublicProvider(item.businessId),
    );
    final businessName = switch (profileAsync) {
      AsyncData(value: final profile) =>
        profile?.businessName ?? 'Unknown business',
      _ => '',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: switch (item) {
        PostFeedItem(:final post) => PostCard(
          post: post,
          businessName: businessName,
          onTap: () => context.pushNamed(
            RouteNames.postDetail,
            pathParameters: {RouteNames.idParam: '${post.id}'},
          ),
        ),
        ReelFeedItem(:final reel) => ReelCard(
          reel: reel,
          businessName: businessName,
          onTap: () => context.pushNamed(
            RouteNames.reelDetail,
            pathParameters: {RouteNames.idParam: '${reel.id}'},
          ),
        ),
      },
    );
  }
}

/// A genuine first-load failure — retryable, same convention as
/// `HomeFeedScreen._LoadErrorView`: `discoverFeedProvider` also has
/// automatic retry disabled (STEP 3), so this button is the only thing
/// that retries.
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      message: 'Could not load Discover right now.',
      onRetry: () => ref.invalidate(discoverFeedProvider),
    );
  }
}