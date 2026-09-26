import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/search/data/search_repository_impl.dart';
import 'package:social_commerce_app/features/search/domain/search_filters.dart';
import 'package:social_commerce_app/features/search/domain/search_page_entity.dart';
import 'package:social_commerce_app/features/search/domain/search_repository.dart';
import 'package:social_commerce_app/features/search/domain/search_result_entity.dart';
import 'package:social_commerce_app/features/search/presentation/search_provider.dart';

/// Same composite-string-key convention as other hand-written fakes in
/// this project when a fake needs to distinguish calls by more than
/// one argument — `SearchFilters.toString()` (STEP 1) is already
/// value-based, so it's safe to use directly inside the key.
String _pageKey(String? q, SearchFilters filters, String? cursor) =>
    '$q|$filters|$cursor';

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository(this.pages);

  final Map<String, SearchPage> pages;
  int callCount = 0;
  final List<({String? q, SearchFilters filters, String? cursor})>
  callsRecorded = [];

  /// Set to an open [Completer] to hold a call in flight for a
  /// concurrency test; `null` (the default) resolves immediately.
  Completer<void>? gate;

  /// Set to make the NEXT call throw this instead of returning a page
  /// (auto-clears after throwing once).
  Object? throwOnNextCall;

  @override
  Future<SearchPage> search({
    String? q,
    SearchFilters filters = const SearchFilters(),
    String? cursor,
  }) async {
    callCount++;
    callsRecorded.add((q: q, filters: filters, cursor: cursor));

    if (gate != null) await gate!.future;

    if (throwOnNextCall != null) {
      final err = throwOnNextCall!;
      throwOnNextCall = null;
      throw err;
    }

    final key = _pageKey(q, filters, cursor);
    final page = pages[key];
    if (page == null) {
      throw StateError(
        'Unexpected call: q=$q filters=$filters cursor=$cursor',
      );
    }
    return page;
  }
}

BusinessSearchResult _biz(int id) => BusinessSearchResult(
  BusinessProfile(
    id: id,
    businessName: 'Business $id',
    businessType: BusinessType.trader,
    country: 'Egypt',
    city: 'Cairo',
    isVerified: false,
  ),
);

ProductSearchResult _prod(int id) => ProductSearchResult(
  Product(
    id: id,
    businessId: 1,
    categoryId: 1,
    name: 'Product $id',
    description: '',
    price: '10.00',
    currency: Currency.egp,
  ),
);

void main() {
  test('build() starts idle: no items, no repository call', () async {
    final fake = _FakeSearchRepository({});
    final container = ProviderContainer(
      overrides: [searchRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final state = await container.read(searchProvider.future);

    expect(state.items, isEmpty);
    expect(state.hasSearched, isFalse);
    expect(state.nextCursor, isNull);
    expect(fake.callCount, 0);
  });

  test('search() loads results for the given query and filters', () async {
    const filters = SearchFilters(country: 'Egypt', featuredOnly: true);
    final fake = _FakeSearchRepository({
      _pageKey('shoes', filters, null): SearchPage(
        items: [_biz(1), _prod(2)],
        nextCursor: 'cursor-a',
      ),
    });
    final container = ProviderContainer(
      overrides: [searchRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(searchProvider.future);

    await container.read(searchProvider.notifier).search(
      q: 'shoes',
      filters: filters,
    );

    final state = container.read(searchProvider).value!;
    expect(state.items.map((r) => r.id), [1, 2]);
    expect(state.hasSearched, isTrue);
    expect(state.nextCursor, 'cursor-a');
    expect(fake.callsRecorded.single.cursor, isNull);
  });

  test(
    'search() called again with different filters REPLACES the '
    'previous results rather than appending to them',
    () async {
      const filtersA = SearchFilters(country: 'Egypt');
      const filtersB = SearchFilters(country: 'UAE');
      final fake = _FakeSearchRepository({
        _pageKey('bags', filtersA, null): SearchPage(
          items: [_prod(1)],
          nextCursor: 'cursor-a',
        ),
        _pageKey('bags', filtersB, null): SearchPage(
          items: [_prod(2), _prod(3)],
          nextCursor: null,
        ),
      });
      final container = ProviderContainer(
        overrides: [searchRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      await container.read(searchProvider.future);
      await container
          .read(searchProvider.notifier)
          .search(q: 'bags', filters: filtersA);

      await container
          .read(searchProvider.notifier)
          .search(q: 'bags', filters: filtersB);

      final state = container.read(searchProvider).value!;
      expect(state.items.map((r) => r.id), [2, 3]);
      expect(state.nextCursor, isNull);
    },
  );

  test(
    'loadMore() appends items using the query/filters from the most '
    'recent search(), advancing the exact cursor returned',
    () async {
      const filters = SearchFilters(featuredOnly: true);
      final fake = _FakeSearchRepository({
        _pageKey('shoes', filters, null): SearchPage(
          items: [_prod(1)],
          nextCursor: 'cursor-a',
        ),
        _pageKey('shoes', filters, 'cursor-a'): SearchPage(
          items: [_biz(2)],
          nextCursor: 'cursor-b',
        ),
      });
      final container = ProviderContainer(
        overrides: [searchRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      await container.read(searchProvider.future);
      await container
          .read(searchProvider.notifier)
          .search(q: 'shoes', filters: filters);

      await container.read(searchProvider.notifier).loadMore();

      final state = container.read(searchProvider).value!;
      expect(state.items.map((r) => r.id), [1, 2]);
      expect(state.nextCursor, 'cursor-b');
      expect(state.isLoadingMore, isFalse);
      expect(fake.callsRecorded.map((c) => c.cursor), [null, 'cursor-a']);
    },
  );

  test('loadMore() is a no-op once nextCursor is null', () async {
    final fake = _FakeSearchRepository({
      _pageKey('x', const SearchFilters(), null): SearchPage(
        items: [_prod(1)],
        nextCursor: null,
      ),
    });
    final container = ProviderContainer(
      overrides: [searchRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(searchProvider.future);
    await container.read(searchProvider.notifier).search(q: 'x');

    await container.read(searchProvider.notifier).loadMore();

    expect(fake.callCount, 1); // only the search() call
  });

  test(
    'loadMore() is a no-op while a previous loadMore() is still in '
    'flight',
    () async {
      final fake = _FakeSearchRepository({
        _pageKey('x', const SearchFilters(), null): SearchPage(
          items: [_prod(1)],
          nextCursor: 'cursor-a',
        ),
        _pageKey('x', const SearchFilters(), 'cursor-a'): SearchPage(
          items: [_prod(2)],
          nextCursor: null,
        ),
      });
      final container = ProviderContainer(
        overrides: [searchRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      await container.read(searchProvider.future);
      await container.read(searchProvider.notifier).search(q: 'x');

      fake.gate = Completer<void>();
      final firstCall = container.read(searchProvider.notifier).loadMore();
      // Second call arrives while the first is still gated open.
      await container.read(searchProvider.notifier).loadMore();
      fake.gate!.complete();
      await firstCall;

      // Exactly one loadMore() call actually reached the repository.
      expect(fake.callCount, 2); // initial search() + ONE loadMore()
      final state = container.read(searchProvider).value!;
      expect(state.items.map((r) => r.id), [1, 2]);
    },
  );

  test(
    "loadMore()'s failure keeps the already-loaded items, resets "
    'isLoadingMore, and rethrows to the caller',
    () async {
      final fake = _FakeSearchRepository({
        _pageKey('x', const SearchFilters(), null): SearchPage(
          items: [_prod(1)],
          nextCursor: 'cursor-a',
        ),
      });
      final container = ProviderContainer(
        overrides: [searchRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      await container.read(searchProvider.future);
      await container.read(searchProvider.notifier).search(q: 'x');

      fake.throwOnNextCall = Exception('network down');

      await expectLater(
        container.read(searchProvider.notifier).loadMore(),
        throwsA(isA<Exception>()),
      );

      final state = container.read(searchProvider).value!;
      expect(state.items.map((r) => r.id), [1]); // still there
      expect(state.isLoadingMore, isFalse);
    },
  );
}