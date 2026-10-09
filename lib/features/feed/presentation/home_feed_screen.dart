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
/// (Part P-114 STEP 2 restyled both cards in place; the feed still hands them
/// the same `post`/`reel`, `businessName` and `onTap`, plus the optional
/// `isBusinessVerified` flag it reads from the same business lookup.)
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
/// briefly renders [FeedSkeletonList] instead of the list for the
/// duration of a manual refresh (now as the skeleton, Part P-114 STEP 2),
/// rather than keeping the old items
/// visible under the pull spinner. Flagged rather than silently
/// patched: fixing it properly means changing `FeedState`/the
/// provider's contract, which is out of this screen's own scope.
///
/// ### Navigation - no debug menu (Part P-113, STEP 6B)
///
/// This screen has no debug or overflow menu. Every destination the old
/// debug menu opened is now reached from visible UI: the bottom bar (Explore,
/// Saved, Create, Moderation, Chats, Profile), the Home top bar (notifications
/// and chats), the stories tray at the top of this feed, and the Profile and
/// Settings hub (Business tools, language, appearance, log out). The
/// navigation manifest and its reachability test keep it that way.
///
/// ### Instagram-style assembly (Part P-114 STEP 2)
///
/// Presentation only: every provider call, route and callback is unchanged.
/// The list is full width (no side padding): the stories tray, a hairline,
/// then post and reel cards that carry their own hairline. The first load
/// shows [FeedSkeletonList] and loading more shows one [FeedPostSkeleton]
/// instead of spinners. The empty and error messages come from the ARB files.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/shell/home_top_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../routing/route_names.dart';
import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';
import '../../business_profile/presentation/business_profile_public_provider.dart';
import '../../chat/presentation/chat_unread_provider.dart';
import '../../content/domain/public_post_entity.dart';
import '../../content/domain/public_reel_entity.dart';
import '../../content/presentation/post_card.dart';
import '../../content/presentation/reel_card.dart';
import '../../discover/presentation/discover_provider.dart';
import '../../discover/presentation/stories_bar_widget.dart';
import '../../notifications/presentation/notification_list_provider.dart';
import '../domain/feed_item_entity.dart';
import 'feed_skeleton.dart';
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
      // Part P-113: the shared Home top bar (wordmark, bell and chats icons
      // with unread badges). No debug or overflow menu: every destination is
      // reached from the bottom bar, the top bar or the Profile hub.
      appBar: const HomeTopBar(),
      body: switch (feedAsync) {
        AsyncData(value: final state) => _FeedBody(
          state: state,
          scrollController: _scrollController,
        ),
        AsyncError(:final error) => _LoadErrorView(error: error),
        _ => const FeedSkeletonList(
          key: ValueKey<String>('home_feed_skeleton'),
        ),
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
    Future<void> handleRefresh() {
      // Part P-113 (STEP 5): a user-initiated refresh also re-reads the two
      // unread counts of the top bar (one request each, no polling).
      ref.invalidate(notificationListProvider);
      ref.invalidate(chatUnreadCountProvider);
      ref.invalidate(activeStoryGroupsProvider);
      return ref.read(homeFeedProvider.notifier).refresh();
    }

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const _HomeStoriesTray(),
            const SizedBox(height: 96),
            EmptyStateWidget(
              message: context.l10n.feedEmptyMessage,
              icon: Icons.dynamic_feed_outlined,
            ),
          ],
        ),
      );
    }

    // Index 0 is the stories tray (Part P-113 STEP 6A); feed items follow.
    final itemCount = 1 + state.items.length + (state.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _HomeStoriesTray();
          }
          final itemIndex = index - 1;
          if (itemIndex >= state.items.length) {
            // Part P-114 STEP 2: a skeleton card instead of a spinner.
            return const FeedPostSkeleton(
              key: ValueKey<String>('home_feed_loading_more'),
            );
          }
          return _FeedListItem(item: state.items[itemIndex]);
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
      AsyncData(value: final profile) =>
        profile?.businessName ?? context.l10n.businessUnknownName,
      _ => '',
    };
    // Part P-114 STEP 2: the same lookup also tells whether to show the blue
    // Verified mark (false while loading or when the profile is unknown).
    final bool isVerified = switch (profileAsync) {
      AsyncData(value: final profile) => profile?.isVerified ?? false,
      _ => false,
    };

    // Part P-114 STEP 2: no wrapper padding; each card carries its own
    // bottom hairline (full-width Instagram list).
    return switch (item) {
      PostFeedItem(:final post) => PostCard(
        post: post,
        businessName: businessName,
        isBusinessVerified: isVerified,
        onTap:
            () => context.pushNamed(
              RouteNames.postDetail,
              pathParameters: {RouteNames.idParam: '${post.id}'},
            ),
      ),
      ReelFeedItem(:final reel) => ReelCard(
        reel: reel,
        businessName: businessName,
        isBusinessVerified: isVerified,
        onTap:
            () => context.pushNamed(
              RouteNames.reelDetail,
              pathParameters: {RouteNames.idParam: '${reel.id}'},
            ),
      ),
    };
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
      message: context.l10n.feedLoadFailed,
      onRetry: () => ref.invalidate(homeFeedProvider),
    );
  }
}

/// Part P-113 (STEP 6A): the stories tray at the top of the Home feed - the
/// locked reachability matrix names it as the entry point to the Story viewer
/// ("Tab 1; story rings open Story viewer"). It reuses the existing
/// [StoriesBarWidget] (the same bar the Explore tab shows), draws nothing
/// while signed out, and nothing when no business has an active story.
class _HomeStoriesTray extends ConsumerWidget {
  const _HomeStoriesTray();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool signedIn = ref.watch(
      sessionProvider.select(
        (AsyncValue<User?> session) => switch (session) {
          AsyncData(:final value) => value != null,
          _ => false,
        },
      ),
    );
    if (!signedIn) return const SizedBox.shrink();
    // Part P-114 STEP 1: Business accounts see their own "+" tile first.
    final bool isBusiness = ref.watch(
      sessionProvider.select(
        (AsyncValue<User?> session) => switch (session) {
          AsyncData(:final value) => value?.accountType == AccountType.business,
          _ => false,
        },
      ),
    );
    // Part P-114 STEP 2: a hairline separates the tray from the first card.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: StoriesBarWidget(showOwnStoryTile: isBusiness),
        ),
        Divider(height: 0.5, thickness: 0.5, color: context.appColors.outline),
      ],
    );
  }
}
