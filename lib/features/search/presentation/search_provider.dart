/// Part P-065 STEP 3 scope: `searchProvider` — the single source of
/// truth for "what does the Search screen show right now," covering
/// the current result list, its pagination cursor, and the in-flight
/// state `SearchFilterPanel`/`SearchScreen` (STEP 4) render against.
///
/// Mirrors `HomeFeedNotifier`'s (`feed/presentation/
/// home_feed_provider.dart`, Part P-061) exact `AsyncNotifier&lt;State&gt;`
/// shape and `refresh`/`loadMore` split, with two differences forced
/// by how Search actually works:
///
/// ### No fetch on `build()` — Search starts idle, not loaded
///
/// Unlike the Home Feed (a single, parameterless feed that always has
/// something to show), Search has no content to show until the user
/// has typed a query and/or set a filter — the screen's initial state
/// (before the user does anything) is an intentionally EMPTY,
/// zero-network-call idle screen, not a first page fetched with `q:
/// null` and no filters. [SearchState.hasSearched] is what lets
/// `SearchScreen` (STEP 4) tell "haven't searched yet" apart from
/// "searched and got zero results" — both have an empty `items` list,
/// but only the second should render a "no results" message instead
/// of nothing.
///
/// ### `search()` replaces `HomeFeedNotifier.refresh()` — always a
/// full reset, and it's what actually carries the query
///
/// There's no bare no-argument `refresh()` here: every call that
/// starts a brand new result set — the debounced text-search callback,
/// the "Apply filters" action, both in `SearchScreen`/
/// `SearchFilterPanel` (STEP 4) — goes through [search], which always
/// discards whatever was previously loaded (items AND cursor) and
/// fetches a genuine first page for the given `q`/`filters`. This is
/// also what keeps [SearchPage.nextCursor]'s own documented invariant
/// ("never reuse a cursor across a query-text present/absent switch")
/// automatically satisfied: [loadMore] only ever pairs a stored cursor
/// with the exact `q`/`filters` [search] most recently stored
/// alongside it, and [search] never carries a cursor forward from a
/// previous call — there is no code path where a cursor issued under
/// one `q` could be replayed under a different one.
///
/// [loadMore] otherwise behaves exactly like `HomeFeedNotifier.
/// loadMore()`: appends using the stored cursor, no-ops if there is no
/// more data or a load is already in flight, and on failure rethrows
/// to the caller while leaving the already-loaded items on screen and
/// resetting `isLoadingMore` so a later retry can proceed — same
/// reasoning as that method's own docstring.
///
/// ### Why `autoDispose`, and why retry is disabled
///
/// Same reasoning as `homeFeedProvider`: Search is live, per-session,
/// per-visit state — leaving the screen (or signing out) should not
/// keep a stale result list cached in memory, and Riverpod 3.x's
/// automatic retry is disabled since this screen shows its own
/// Retry/error affordance rather than a hidden background retry that
/// would only delay the visible error state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/search_repository_impl.dart';
import '../domain/search_filters.dart';
import '../domain/search_result_entity.dart';

class SearchState {
  const SearchState({
    this.items = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.hasSearched = false,
  });

  final List<SearchResult> items;
  final String? nextCursor;
  final bool isLoadingMore;

  /// `true` once at least one [SearchNotifier.search] call has
  /// completed successfully. Lets the screen distinguish "nothing
  /// searched yet" from "searched, zero results" — both otherwise
  /// look identical via `items.isEmpty`.
  final bool hasSearched;

  SearchState copyWith({
    List<SearchResult>? items,
    String? nextCursor,
    bool? isLoadingMore,
    bool? hasSearched,
    bool clearNextCursor = false,
  }) {
    return SearchState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

class SearchNotifier extends AsyncNotifier<SearchState> {
  /// The `q`/`filters` pair the currently-loaded [SearchState] was
  /// fetched with. [loadMore] reads these — never anything passed to
  /// it directly, since it takes no arguments — so a page requested
  /// mid-scroll can never drift from what's actually on screen.
  String? _currentQuery;
  SearchFilters _currentFilters = const SearchFilters();

  @override
  Future<SearchState> build() async {
    // Deliberately no repository call here — see this file's module
    // docstring ("No fetch on build()").
    return const SearchState();
  }

  /// Starts a brand new search, discarding any previously loaded
  /// items and cursor. Called by `SearchScreen` (STEP 4) after its
  /// debounce timer fires and whenever the filter panel's "Apply" is
  /// pressed — both a text-query change and a filter-only change go
  /// through this same method.
  Future<void> search({
    String? q,
    SearchFilters filters = const SearchFilters(),
  }) async {
    _currentQuery = q;
    _currentFilters = filters;

    state = const AsyncValue<SearchState>.loading();
    state = await AsyncValue.guard<SearchState>(() async {
      final page = await ref
          .read(searchRepositoryProvider)
          .search(q: q, filters: filters);
      return SearchState(
        items: page.items,
        nextCursor: page.nextCursor,
        hasSearched: true,
      );
    });
  }

  /// Appends the next page for the CURRENTLY loaded `q`/`filters`
  /// (see [_currentQuery]/[_currentFilters]), using the current
  /// `nextCursor`. No-op if there is no more data or a load is
  /// already in flight — identical guard to `HomeFeedNotifier.
  /// loadMore()`.
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
          .read(searchRepositoryProvider)
          .search(
            q: _currentQuery,
            filters: _currentFilters,
            cursor: current.nextCursor,
          );
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

/// Exposes [SearchNotifier] to the rest of the app. `autoDispose` and
/// retry-disabled on purpose — see this file's module docstring.
final searchProvider =
    AsyncNotifierProvider.autoDispose<SearchNotifier, SearchState>(
      SearchNotifier.new,
      retry: (retryCount, error) => null,
    );