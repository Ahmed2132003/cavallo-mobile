/// Part P-061 scope: `HomeFeedScreen` — the real `/home` landing screen,
/// replacing Part P-007's placeholder (`home_screen.dart`, deleted by
/// this part). Infinite-scrolling, cursor-paginated feed of published
/// [PublicPost]s/[PublicReel]s, backed by `homeFeedProvider`
/// (`home_feed_provider.dart`, STEP 1/2).
///
/// ### Card reuse — zero modification
///
/// Every item renders through the existing [PostCard]/[ReelCard] (Part
/// P-045), exactly as `BusinessProfilePublicScreen`'s own Posts/Reels
/// sections already do — same `businessName` + `onTap` shape, same
/// `context.pushNamed(RouteNames.postDetail / reelDetail, ...)`
/// navigation convention. Neither card was touched by this part.
///
/// ### `businessName` resolution — per item, non-blocking
///
/// The feed payload only carries a `business` id per item (P-059's own
/// documented shape), so each row resolves its own display name through
/// the existing `businessProfilePublicProvider(id)` (Part P-029) inside
/// [_FeedListItem] — a small [ConsumerWidget] per row, so one slow or
/// failed name lookup never blocks the rest of the list from rendering
/// (per this part's execution prompt).
///
/// ### Infinite scroll — 80% threshold
///
/// [_HomeFeedScreenState] attaches a [ScrollController] listener that
/// calls `homeFeedProvider.notifier.loadMore()` once the scroll position
/// crosses 80% of the current scrollable extent. `loadMore()` is already
/// idempotent/no-op while a load is in flight or once `nextCursor` is
/// `null` (see that method's own docstring), so this listener does not
/// need its own in-flight guard.
///
/// ### Pull-to-refresh — a known, flagged trade-off
///
/// [RefreshIndicator] calls `homeFeedProvider.notifier.refresh()`, which
/// (per `home_feed_provider.dart`'s STEP 1/2 fix) sets `state` to a bare
/// `AsyncValue.loading()` with no attached previous data — Riverpod's
/// `copyWithPrevious` is an internal member this project's own analyzer
/// pass already ruled out. That means this screen's top-level `switch`
/// briefly renders [LoadingIndicator] instead of the list for the
/// duration of a manual refresh, rather than keeping the old items
/// visible under the pull spinner. Flagged rather than silently
/// patched: fixing it properly means changing `FeedState`/the
/// provider's contract, which is out of this screen's own scope.
///
/// ### Router-gate debug menu — ports P-007/P-021c/P-028/P-033/P-040/
/// P-050's five temporary debug affordances forward
///
/// The old placeholder `HomeScreen` was, incidentally, the only reachable
/// entry point for five temporary, non-product debug affordances added
/// by five different earlier parts (see each one's own comment on
/// [_DebugMenu] below). Deleting it outright would have made all five
/// unreachable with no replacement — flagged in this part's own STEP 4
/// plan rather than silently dropped. They're preserved here, moved into
/// a single AppBar overflow menu ([_DebugMenu]), with the exact same
/// visibility conditions the placeholder used. None of this is
/// permanent product surface; each entry remains labeled "(debug)" and
/// should be removed once its own real navigational home (named in each
/// part's original comment) exists.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/route_names.dart';
import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';
import '../../business_profile/presentation/business_profile_provider.dart';
import '../../business_profile/presentation/business_profile_public_provider.dart';
import '../../content/domain/public_post_entity.dart';
import '../../content/domain/public_reel_entity.dart';
import '../../content/presentation/post_card.dart';
import '../../content/presentation/reel_card.dart';
import '../domain/feed_item_entity.dart';
import 'home_feed_provider.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
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

  /// Fires `loadMore()` once the user has scrolled past 80% of the
  /// current scrollable extent. Guarded against `maxScrollExtent == 0`
  /// (a feed short enough to not scroll at all yet) to avoid firing on
  /// every frame in that case. `loadMore()` itself is the source of
  /// truth for "is there more to load" / "is a load already running" —
  /// see `home_feed_provider.dart`.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    final threshold = position.maxScrollExtent * 0.8;
    if (position.pixels >= threshold) {
      ref.read(homeFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeFeedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home'), actions: const [_DebugMenu()]),
      body: switch (feedAsync) {
        AsyncData(value: final state) => _FeedBody(
          state: state,
          scrollController: _scrollController,
        ),
        AsyncError(:final error) => _LoadErrorView(error: error),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// The loaded (or loading-more) feed: pull-to-refresh wrapping either
/// the scrollable item list or, for a genuinely empty feed (both the
/// following tier and the backfill returned nothing), an
/// [EmptyStateWidget] — still wrapped in a scrollable so
/// [RefreshIndicator] keeps working.
class _FeedBody extends ConsumerWidget {
  const _FeedBody({required this.state, required this.scrollController});

  final FeedState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleRefresh() =>
        ref.read(homeFeedProvider.notifier).refresh();

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 96),
            EmptyStateWidget(
              message:
                  'Your feed is empty right now.\n'
                  'Follow some businesses, or check back soon.',
              icon: Icons.dynamic_feed_outlined,
            ),
          ],
        ),
      );
    }

    final itemCount = state.items.length + (state.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
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
          return _FeedListItem(item: state.items[index]);
        },
      ),
    );
  }
}

/// One row of the feed. Resolves its own `businessName` through
/// `businessProfilePublicProvider` (Part P-029) — independent of every
/// other row's own lookup — then delegates to [PostCard]/[ReelCard]
/// (Part P-045) unmodified.
class _FeedListItem extends ConsumerWidget {
  const _FeedListItem({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(
      businessProfilePublicProvider(item.businessId),
    );
    final businessName = switch (profileAsync) {
      AsyncData(value: final profile) => profile?.businessName ?? 'Unknown business',
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

/// A genuine first-load failure (no connectivity, 5xx, an unexpected
/// payload) — retryable. `homeFeedProvider` has automatic retry
/// disabled (see that file's docstring), so this button is the only
/// thing that retries; `ref.invalidate` re-runs `build()` from scratch,
/// same convention as every other top-level screen error view in this
/// project (`BusinessProfilePublicScreen._LoadErrorView`, etc.).
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      message: 'Could not load your feed.',
      onRetry: () => ref.invalidate(homeFeedProvider),
    );
  }
}

/// Temporary debug affordances carried forward from the deleted P-007
/// placeholder `HomeScreen`, unified into one AppBar overflow menu so
/// nothing they gave access to becomes unreachable. Each entry keeps the
/// exact visibility condition and destination the placeholder used —
/// see that class's removed docstring (`git show` on the commit that
/// deleted `home_screen.dart`) for the full history of why each one
/// exists. **Access control for every gated destination is enforced by
/// `app_router.dart`'s redirect guard, not by this menu** — hiding an
/// entry here is a convenience only.
class _DebugMenu extends ConsumerWidget {
  const _DebugMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = switch (session) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final isBusinessUser =
        user != null && user.accountType == AccountType.business;
    final canModerate = user != null && (user.isModerator || user.isStaff);
    final isOnboardedBusinessUser =
        isBusinessUser &&
        switch (ref.watch(businessProfileProvider)) {
          AsyncData(:final value) => value != null,
          _ => false,
        };

    return PopupMenuButton<String>(
      tooltip: 'Debug menu',
      onSelected: (value) => _handleSelection(context, ref, value),
      itemBuilder: (context) => [
        if (isOnboardedBusinessUser)
          const PopupMenuItem(
            value: 'editProfile',
            child: Text('Edit business profile'),
          ),
        if (isBusinessUser)
          const PopupMenuItem(
            value: 'businessConsole',
            child: Text('Business Console (debug)'),
          ),
        if (canModerate)
          const PopupMenuItem(
            value: 'moderation',
            child: Text('Moderation queue (debug)'),
          ),
        const PopupMenuItem(
          value: 'viewStory',
          child: Text('View Story (debug, business 3)'),
        ),
        const PopupMenuItem(value: 'logout', child: Text('Logout (debug)')),
      ],
    );
  }

  void _handleSelection(BuildContext context, WidgetRef ref, String value) {
    switch (value) {
      case 'editProfile':
        context.goNamed(RouteNames.businessProfileEdit);
      case 'businessConsole':
        context.pushNamed(RouteNames.businessConsole);
      case 'moderation':
        context.pushNamed(RouteNames.moderation);
      case 'viewStory':
        context.pushNamed(
          RouteNames.storyViewer,
          pathParameters: {RouteNames.idParam: '3'},
          extra: 'Business 3',
        );
      case 'logout':
        ref.read(sessionProvider.notifier).logout();
    }
  }
}