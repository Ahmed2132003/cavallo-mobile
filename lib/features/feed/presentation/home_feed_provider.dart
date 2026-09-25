/// Part P-061 scope: `homeFeedProvider` — the single source of truth
/// for "what does the Home Feed look like right now," including
/// pagination position. Plain, non-code-gen Riverpod (`AsyncNotifier`),
/// same convention as `OwnProductsNotifier`/`ModerationQueueNotifier`.
///
/// ### Why a custom `FeedState`, not `AsyncNotifier<List<FeedItem>>`
///
/// Unlike `ownContentProvider`/`moderationQueueProvider` (a bare list is
/// the whole state), the Home Feed genuinely needs two more pieces of
/// state the screen must react to: [FeedState.nextCursor] (so
/// `loadMore()` knows what to send, and so the screen can stop calling
/// it once it's `null`) and [FeedState.isLoadingMore] (so the screen
/// can show a bottom-of-list spinner distinct from the initial
/// full-screen `LoadingIndicator`, which only applies to `AsyncLoading`
/// as a whole). `FeedState` lives here in `presentation/`, not
/// `domain/`, because it is UI-pagination bookkeeping, not a Home-Feed
/// business concept the backend has any notion of.
///
/// ### `refresh()` vs `loadMore()` — two different resets
///
/// * [refresh] discards ALL local state (items AND cursor) and calls
///   `fetchHomeFeed(cursor: null)` — a genuine fresh first page, per
///   P-061's own spec ("bypassing any locally-cached list state,
///   always hitting the real first-page endpoint"). Uses
///   [AsyncValue.guard], exactly like `OwnContentNotifier.refresh()`
///   (Part P-044) — a failed refresh settles into [AsyncError] without
///   rethrowing, since it's a non-destructive, retryable read.
/// * [loadMore] APPENDS to the existing list using the current
///   `nextCursor`. A no-op (returns immediately) if `nextCursor` is
///   already `null` (no more pages) or if a load is already in flight
///   — the same "ignore a duplicate call while one is running" guard
///   `ModerationQueueNotifier._inFlight` uses for approve/reject,
///   applied here to a scroll-triggered call instead of a tap.
///
/// ### Failure contract
///
/// [loadMore]'s failure does NOT clear the already-loaded items: it
/// rethrows to the caller (the screen's scroll listener, which is
/// expected to show a transient snackbar/retry affordance) while
/// resetting `isLoadingMore` back to `false` so a later scroll can
/// retry — losing everything already on screen because the NEXT page
/// failed to load would be a strictly worse user experience than the
/// backend/product screens' existing "just show the error" pattern.
///
/// ### Why `autoDispose`, and why retry is disabled
///
/// Same reasoning as `moderationQueueProvider`: the Home Feed is live,
/// per-session content — leaving via a signed-out session or the
/// screen going away should not keep a stale feed cached in memory.
/// Riverpod 3.x's automatic exponential-backoff retry is disabled
/// (`retry: (retryCount, error) => null`) — this screen shows its own
/// Retry button; a hidden background retry would only delay the
/// visible error state, matching every other `autoDispose` provider in
/// this project.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/feed_repository.dart';
import '../domain/feed_item_entity.dart';

class FeedState {
  const FeedState({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<FeedItem> items;
  final String? nextCursor;
  final bool isLoadingMore;

  FeedState copyWith({
    List<FeedItem>? items,
    String? nextCursor,
    bool? isLoadingMore,
    bool clearNextCursor = false,
  }) {
    return FeedState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class HomeFeedNotifier extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final page = await ref.watch(feedRepositoryProvider).fetchHomeFeed();
    return FeedState(items: page.items, nextCursor: page.nextCursor);
  }

  /// Discards local state and fetches a genuine fresh first page.
  Future<void> refresh() async {
    state = const AsyncValue<FeedState>.loading();
    state = await AsyncValue.guard<FeedState>(() async {
      final page = await ref.read(feedRepositoryProvider).fetchHomeFeed();
      return FeedState(items: page.items, nextCursor: page.nextCursor);
    });
  }

  /// Appends the next page using the current `nextCursor`. No-op if
  /// there is no more data or a load is already in flight.
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
          .read(feedRepositoryProvider)
          .fetchHomeFeed(cursor: current.nextCursor);
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

/// Exposes [HomeFeedNotifier] to the rest of the app. `autoDispose`
/// and retry-disabled on purpose — see the class docstring above.
final homeFeedProvider =
    AsyncNotifierProvider.autoDispose<HomeFeedNotifier, FeedState>(
      HomeFeedNotifier.new,
      retry: (retryCount, error) => null,
    );