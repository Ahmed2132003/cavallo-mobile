import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/categories/data/category_repository_impl.dart';
import 'package:social_commerce_app/features/categories/domain/category_entity.dart';
import 'package:social_commerce_app/features/categories/domain/category_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/presentation/product_price_framing.dart';
import 'package:social_commerce_app/features/search/data/search_repository_impl.dart';
import 'package:social_commerce_app/features/search/domain/search_filters.dart';
import 'package:social_commerce_app/features/search/domain/search_page_entity.dart';
import 'package:social_commerce_app/features/search/domain/search_repository.dart';
import 'package:social_commerce_app/features/search/domain/search_result_entity.dart';
import 'package:social_commerce_app/features/search/presentation/search_screen.dart';

/// Own copy of the composite-key fake — same convention as
/// `search_provider_test.dart`'s `_FakeSearchRepository` (each test
/// file keeps its own, per this project's established convention —
/// see `home_feed_screen_test.dart`'s own separate `_FakeFeedRepository`
/// alongside `home_feed_provider_test.dart`'s).
String _pageKey(String? q, SearchFilters filters, String? cursor) =>
    '$q|$filters|$cursor';

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository(this.pages);

  final Map<String, SearchPage> pages;
  int callCount = 0;
  final List<({String? q, SearchFilters filters, String? cursor})>
  callsRecorded = [];

  @override
  Future<SearchPage> search({
    String? q,
    SearchFilters filters = const SearchFilters(),
    String? cursor,
  }) async {
    callCount++;
    callsRecorded.add((q: q, filters: filters, cursor: cursor));
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

class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository({required this.tree});
  final List<CategoryNode> tree;

  @override
  Future<List<CategoryNode>> fetchCategoryTree({bool forceRefresh = false}) async =>
      tree;
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

ProductSearchResult _prod(int id, {String price = '10.00'}) =>
    ProductSearchResult(
      Product(
        id: id,
        businessId: 1,
        categoryId: 1,
        name: 'Product $id',
        description: '',
        price: price,
        currency: Currency.egp,
      ),
    );

Widget _host(
  _FakeSearchRepository fake, {
  List<CategoryNode> categories = const [],
}) {
  return ProviderScope(
    overrides: [
      searchRepositoryProvider.overrideWithValue(fake),
      categoryRepositoryProvider.overrideWith(
        (ref) async => _FakeCategoryRepository(tree: categories),
      ),
    ],
    child: const MaterialApp(home: SearchScreen()),
  );
}

void main() {
  testWidgets(
    'shows a "start searching" prompt before any search, not "no results"',
    (tester) async {
      await tester.pumpWidget(_host(_FakeSearchRepository({})));
      await tester.pump();

      expect(
        find.textContaining('Search for traders, factories, and products'),
        findsOneWidget,
      );
      expect(find.textContaining('No results found'), findsNothing);
    },
  );

  testWidgets(
    'typing rapidly triggers exactly ONE search call, after the debounce '
    'window, with the final query text',
    (tester) async {
      final fake = _FakeSearchRepository({
        _pageKey('shoes', const SearchFilters(), null): SearchPage(
          items: [_prod(1)],
          nextCursor: null,
        ),
      });
      await tester.pumpWidget(_host(fake));
      await tester.pump();

      final field = find.byKey(const Key('searchScreen_queryField'));
      for (final partial in ['s', 'sh', 'sho', 'shoe', 'shoes']) {
        await tester.enterText(field, partial);
        // Well under the 400ms debounce window — each keystroke should
        // cancel and restart the timer rather than let it fire.
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Now let the debounce window actually elapse with no more typing.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(fake.callCount, 1);
      expect(fake.callsRecorded.single.q, 'shoes');
    },
  );

  testWidgets(
    'applying multiple filters together sends all of them to the '
    'repository, combined with the current query',
    (tester) async {
      const expectedFilters = SearchFilters(
        categoryId: 1,
        country: 'Egypt',
        city: 'Cairo',
        businessType: 'factory',
        minRating: '4',
        featuredOnly: true,
      );
      final fake = _FakeSearchRepository({
        _pageKey('bags', expectedFilters, null): SearchPage(
          items: [_biz(1)],
          nextCursor: null,
        ),
      });
      final categories = [
        const CategoryNode(id: 1, name: 'Fashion', slug: 'fashion'),
      ];
      await tester.pumpWidget(_host(fake, categories: categories));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('searchScreen_queryField')),
        'bags',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      // First call: query alone, no filters yet.
      expect(fake.callCount, 1);

      await tester.tap(find.byKey(const Key('searchScreen_filterButton')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('searchFilterPanel_categoryDropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fashion').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('searchFilterPanel_countryField')),
        'Egypt',
      );
      await tester.enterText(
        find.byKey(const Key('searchFilterPanel_cityField')),
        'Cairo',
      );

      await tester.tap(find.text('Factory'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('searchFilterPanel_minRatingDropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 stars & up').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('searchFilterPanel_featuredSwitch')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Second call: query + every filter, applied immediately (no
      // debounce for an explicit Apply tap).
      expect(fake.callCount, 2);
      final recorded = fake.callsRecorded.last;
      expect(recorded.q, 'bags');
      expect(recorded.filters, expectedFilters);
    },
  );

  testWidgets(
    'a product search result renders the mandatory price-framing note '
    '(P-034) — asserted on the actual text',
    (tester) async {
      final fake = _FakeSearchRepository({
        _pageKey('bag', const SearchFilters(), null): SearchPage(
          items: [_prod(5, price: '250.00')],
          nextCursor: null,
        ),
      });
      await tester.pumpWidget(_host(fake));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('searchScreen_queryField')),
        'bag',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text(ProductPriceCopy.note), findsOneWidget);
      expect(
        find.text(ProductPriceCopy.headline('250.00', Currency.egp)),
        findsOneWidget,
      );
    },
  );
}