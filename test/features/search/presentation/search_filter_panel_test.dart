import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/categories/data/category_repository_impl.dart';
import 'package:social_commerce_app/features/categories/domain/category_entity.dart';
import 'package:social_commerce_app/features/categories/domain/category_repository.dart';
import 'package:social_commerce_app/features/search/domain/search_filters.dart';
import 'package:social_commerce_app/features/search/presentation/search_filter_panel.dart';

/// Same hand-written-fake convention as `product_form_screen_test.dart`'s
/// own `_FakeCategoryRepository`.
class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository({required this.tree});
  final List<CategoryNode> tree;

  @override
  Future<List<CategoryNode>> fetchCategoryTree({bool forceRefresh = false}) async =>
      tree;
}

const _categories = [CategoryNode(id: 1, name: 'Fashion', slug: 'fashion')];

Widget _host(Widget sheetChild, {List<CategoryNode> categories = _categories}) {
  return ProviderScope(
    overrides: [
      categoryRepositoryProvider.overrideWith(
        (ref) async => _FakeCategoryRepository(tree: categories),
      ),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<SearchFilters>(
                context: context,
                isScrollControlled: true,
                builder: (context) => sheetChild,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'Apply pops a SearchFilters built from every field the user set',
    (tester) async {
      SearchFilters? captured;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoryRepositoryProvider.overrideWith(
              (ref) async => _FakeCategoryRepository(tree: _categories),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      captured = await showModalBottomSheet<SearchFilters>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => const SearchFilterPanel(
                          initialFilters: SearchFilters(),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('searchFilterPanel_categoryDropdown')));
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

      await tester.tap(find.byKey(const Key('searchFilterPanel_minRatingDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 stars & up').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('searchFilterPanel_featuredSwitch')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(
        captured,
        const SearchFilters(
          categoryId: 1,
          country: 'Egypt',
          city: 'Cairo',
          businessType: 'factory',
          minRating: '4',
          featuredOnly: true,
        ),
      );
    },
  );

  testWidgets('Clear pops the default, empty SearchFilters', (tester) async {
    SearchFilters? captured;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWith(
            (ref) async => _FakeCategoryRepository(tree: _categories),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    captured = await showModalBottomSheet<SearchFilters>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => const SearchFilterPanel(
                        initialFilters: SearchFilters(
                          country: 'Egypt',
                          featuredOnly: true,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(captured, const SearchFilters());
  });
}