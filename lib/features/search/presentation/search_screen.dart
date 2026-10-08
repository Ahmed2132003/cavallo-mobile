/// Part P-065 STEP 4 scope: the real `/search` screen, replacing Part
/// P-007's placeholder (same file path, same `SearchScreen` class
/// name/no-arg constructor - `app_router.dart`'s existing `GoRoute` for
/// `RouteNames.searchPath` needs no edit at all).
///
/// Wires together `searchProvider` (STEP 3) for state/pagination,
/// [SearchFilterPanel] for filters, and [SearchResultCard] for each row.
///
/// ### Debounce - a plain [Timer], 400ms
///
/// Each keystroke cancels any pending [Timer] and starts a new one; only the
/// LAST one to survive 400ms actually calls `searchProvider.notifier.search`.
///
/// ### Idle vs. "no results" vs. loaded - three distinct states
///
/// [SearchState.hasSearched] tells the idle state (show a "type to search"
/// prompt) apart from a genuine zero-result search (show "No results found").
///
/// ### Retry does NOT use `ref.invalidate`
///
/// `build()` of `searchProvider` fetches nothing, so retry re-calls
/// `search()` with this screen's own remembered text and filters.
///
/// ### Filter panel result contract
///
/// `null` from [SearchFilterPanel] (dismissed without Apply/Clear) means
/// "keep the active filters" - no re-search. Any non-null [SearchFilters]
/// replaces `_filters` and immediately triggers a new search.
///
/// ### Part P-114 STEP 3B (presentation only)
///
/// * The search field sits in the app bar and stays put while the results
///   scroll (sticky).
/// * A horizontal chip row under it: a "Filters" chip (key
///   `searchScreen_filterButton`, with the active count) plus one chip per
///   active filter. Every chip opens the SAME [SearchFilterPanel].
/// * Skeleton rows ([AppShimmerBox]) replace the spinners (first load and
///   load-more).
/// * Results stay a plain list: Featured results carry the amber badge,
///   organic results are listed exactly the same way, in server order.
/// * Every string comes from the ARB files.
/// No provider, repository, route or callback changed.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
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
  /// `DiscoverScreen` - `loadMore()` is already idempotent/no-op while a
  /// load is in flight or once `nextCursor` is `null`.
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
    // Refreshes the clear-icon visibility only - the actual search
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
    // null means "dismissed without Apply/Clear" - see this file's
    // module docstring ("Filter panel result contract").
    if (result == null || !mounted) return;
    setState(() => _filters = result);
    _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(searchProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsetsDirectional.only(end: 16),
          child: TextField(
            key: const Key('searchScreen_queryField'),
            controller: _searchController,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: l10n.searchFieldHint,
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.searchClearTooltip,
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _FilterChipsRow(filters: _filters, onOpen: _openFilterPanel),
          Expanded(
            child: switch (searchAsync) {
              AsyncData(value: final state) => _SearchResultsList(
                state: state,
                scrollController: _scrollController,
              ),
              AsyncError() => ErrorStateWidget(
                message: l10n.searchLoadFailed,
                onRetry: _runSearch,
              ),
              _ => const _ResultsSkeleton(),
            },
          ),
        ],
      ),
    );
  }
}

/// The horizontal chip row under the search field. Every chip opens the
/// existing filter panel; the active ones show what is applied.
class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({required this.filters, required this.onOpen});

  final SearchFilters filters;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String? country = filters.country;
    final String? city = filters.city;
    final String? rating = filters.minRating;
    final int? ratingStars = rating == null ? null : int.tryParse(rating);

    final List<String> active = <String>[
      if (filters.categoryId != null) l10n.searchFilterCategory,
      if (country != null) country,
      if (city != null) city,
      if (filters.businessType == 'trader') l10n.businessTypeTrader,
      if (filters.businessType == 'factory') l10n.businessTypeFactory,
      if (rating != null)
        ratingStars == null
            ? rating
            : l10n.searchFilterMinRatingOption(ratingStars),
      if (filters.featuredOnly) l10n.searchFilterFeaturedOnly,
    ];

    final List<Widget> chips = <Widget>[
      ActionChip(
        key: const Key('searchScreen_filterButton'),
        avatar: const Icon(Icons.tune, size: 18),
        label: Text(
          active.isEmpty
              ? l10n.searchFiltersChip
              : l10n.searchFiltersChipActive(active.length),
        ),
        onPressed: onOpen,
      ),
      for (final String label in active)
        FilterChip(
          label: Text(label),
          selected: true,
          showCheckmark: false,
          onSelected: (_) => onOpen(),
        ),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 6),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => Center(child: chips[index]),
      ),
    );
  }
}

/// The loaded results section - idle prompt, "no results", or the
/// paginated list. See this file's module docstring for the
/// idle/"no results" distinction via [SearchState.hasSearched].
class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.state,
    required this.scrollController,
  });

  final SearchState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (!state.hasSearched) {
      return EmptyStateWidget(
        message: l10n.searchIdlePrompt,
        icon: Icons.search,
      );
    }

    if (state.items.isEmpty) {
      return EmptyStateWidget(
        message: l10n.searchNoResults,
        icon: Icons.search_off,
      );
    }

    final itemCount = state.items.length + (state.isLoadingMore ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const _ResultSkeletonRow();
        }
        return _SearchListItem(result: state.items[index]);
      },
    );
  }
}

/// One row of the results list - dispatches to `context.pushNamed` for
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

/// First-load placeholder: skeleton rows with the same shape as a result row.
class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.searchResultsLoadingLabel,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        itemBuilder: (context, index) => const _ResultSkeletonRow(),
      ),
    );
  }
}

class _ResultSkeletonRow extends StatelessWidget {
  const _ResultSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
      child: Row(
        children: <Widget>[
          AppShimmerBox.circle(size: 52),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppShimmerBox(width: 160, height: 14, borderRadius: 4),
                SizedBox(height: 8),
                AppShimmerBox(width: 110, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
