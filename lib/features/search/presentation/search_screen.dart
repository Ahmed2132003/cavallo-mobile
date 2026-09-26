/// Part P-065 STEP 4 scope: the real `/search` screen, replacing Part
/// P-007's placeholder (same file path, same `SearchScreen` class
/// name/no-arg constructor — `app_router.dart`'s existing `GoRoute` for
/// `RouteNames.searchPath` needs no edit at all, same as `DiscoverScreen`/
/// `HomeFeedScreen` before it).
///
/// Wires together every earlier STEP of this part: `searchProvider`
/// (STEP 3) for state/pagination, [SearchFilterPanel] (this STEP) for
/// filters, and [SearchResultCard] (this STEP) for each row.
///
/// ### Debounce — a plain [Timer], 400ms
///
/// No debounce utility exists elsewhere in this project to reuse (this
/// part's own execution prompt explicitly allows "a `Timer` or a
/// debounce utility"). Each keystroke cancels any pending [Timer] and
/// starts a new one; only the LAST one to survive 400ms actually calls
/// `searchProvider.notifier.search(...)` — the standard debounce
/// pattern, well inside this part's own 300-500ms range.
///
/// ### Idle vs. "no results" vs. loaded — three distinct states
///
/// `searchProvider`'s own `build()` resolves immediately to an idle,
/// zero-network-call [SearchState] (see that file's module docstring).
/// [_SearchResultsList] uses [SearchState.hasSearched] to tell that
/// idle state (show a "type to search" prompt) apart from a genuine
/// zero-result search (show "No results found") — both otherwise look
/// identical via `items.isEmpty`.
///
/// ### Retry does NOT use `ref.invalidate`, unlike `HomeFeedScreen`
///
/// `HomeFeedScreen`'s own retry is `ref.invalidate(homeFeedProvider)`,
/// which re-runs `build()` — correct there because `build()` IS the
/// fetch. Here, `build()` deliberately fetches nothing (see
/// `search_provider.dart`'s docstring), so invalidating on a failed
/// search would just drop back to the empty idle state, silently
/// losing whatever the user searched for. Retry here instead re-calls
/// `search()` with this screen's own remembered `_searchController.
/// text`/`_filters` — the only place that pair is held.
///
/// ### Filter panel result contract
///
/// `null` from [SearchFilterPanel] (dismissed without Apply/Clear)
/// means "keep the currently active filters" — no re-search happens.
/// Any non-null [SearchFilters] (including the "Clear" button's fresh
/// `const SearchFilters()`) replaces `_filters` and immediately
/// triggers a new [search] with the current text field's query — no
/// debounce delay, since this is an explicit tap, not a keystroke.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/route_names.dart';
import '../domain/search_filters.dart';
import '../domain/search_result_entity.dart';
import 'search_filter_panel.dart';
import 'search_provider.dart';
import 'search_result_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _debounceDuration = Duration(milliseconds: 400);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  SearchFilters _filters = const SearchFilters();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Identical 80%-of-scrollable-extent threshold as `HomeFeedScreen`/
  /// `DiscoverScreen` — `loadMore()` is already idempotent/no-op while a
  /// load is in flight or once `nextCursor` is `null` (STEP 3's own
  /// docstring), so no separate in-flight guard is needed here either.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    final threshold = position.maxScrollExtent * 0.8;
    if (position.pixels >= threshold) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  void _runSearch() {
    final q = _searchController.text.trim();
    ref
        .read(searchProvider.notifier)
        .search(q: q.isEmpty ? null : q, filters: _filters);
  }

  void _onQueryChanged(String value) {
    // Refreshes the clear-icon visibility only — the actual search
    // fires from the Timer below, after the debounce window.
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _runSearch);
  }

  Future<void> _openFilterPanel() async {
    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SearchFilterPanel(initialFilters: _filters),
    );
    // null means "dismissed without Apply/Clear" — see this file's
    // module docstring ("Filter panel result contract").
    if (result == null || !mounted) return;
    setState(() => _filters = result);
    _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          IconButton(
            key: const Key('searchScreen_filterButton'),
            icon: Icon(
              _filters.isEmpty ? Icons.filter_list : Icons.filter_list_alt,
            ),
            tooltip: 'Filters',
            onPressed: _openFilterPanel,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('searchScreen_queryField'),
              controller: _searchController,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search traders, factories, products...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: switch (searchAsync) {
              AsyncData(value: final state) => _SearchResultsList(
                state: state,
                scrollController: _scrollController,
                onRetry: _runSearch,
              ),
              AsyncError() => ErrorStateWidget(
                message: 'Could not load search results.',
                onRetry: _runSearch,
              ),
              _ => const LoadingIndicator(),
            },
          ),
        ],
      ),
    );
  }
}

/// The loaded results section — idle prompt, "no results", or the
/// paginated list. See this file's module docstring for the
/// idle/"no results" distinction via [SearchState.hasSearched].
class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.state,
    required this.scrollController,
    required this.onRetry,
  });

  final SearchState state;
  final ScrollController scrollController;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!state.hasSearched) {
      return const EmptyStateWidget(
        message:
            'Search for traders, factories, and products.\n'
            'Type a keyword or set a filter to get started.',
        icon: Icons.search,
      );
    }

    if (state.items.isEmpty) {
      return const EmptyStateWidget(
        message: 'No results found. Try a different search or adjust your filters.',
        icon: Icons.search_off,
      );
    }

    final itemCount = state.items.length + (state.isLoadingMore ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SearchListItem(result: state.items[index]),
        );
      },
    );
  }
}

/// One row of the results list — dispatches to `context.pushNamed` for
/// the correct existing screen. See `SearchResultCard`'s own docstring
/// for why the navigation call lives here rather than inside that card.
class _SearchListItem extends StatelessWidget {
  const _SearchListItem({required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    return SearchResultCard(
      result: result,
      onTap: () => switch (result) {
        BusinessSearchResult(:final business) => context.pushNamed(
          RouteNames.businessProfile,
          pathParameters: {RouteNames.idParam: business.id.toString()},
        ),
        ProductSearchResult(:final product) => context.pushNamed(
          RouteNames.productDetail,
          pathParameters: {RouteNames.idParam: product.id.toString()},
        ),
      },
    );
  }
}