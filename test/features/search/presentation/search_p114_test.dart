import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_avatar.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
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
import 'package:social_commerce_app/features/search/presentation/search_result_card.dart';
import 'package:social_commerce_app/features/search/presentation/search_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-114 STEP 3B: the Instagram-style Explore search - result card (with
/// and without Featured), the chip row, the skeleton, English LTR / Arabic
/// RTL, light / dark. Data flow and debounce stay covered by
/// `search_screen_test.dart`, `search_provider_test.dart` and
/// `search_filter_panel_test.dart`.
///
/// This file is ASCII only: Arabic text is read from the generated
/// localizations of the `ar` locale, never typed here.

BusinessSearchResult _biz(
  int id, {
  bool featured = false,
  bool verified = false,
  int followers = 12,
}) => BusinessSearchResult(
  BusinessProfile(
    id: id,
    businessName: 'Business $id',
    businessType: BusinessType.trader,
    country: 'Egypt',
    city: 'Cairo',
    isVerified: verified,
    isFeatured: featured,
    followerCount: followers,
  ),
);

ProductSearchResult _prod(int id, {bool featured = false}) =>
    ProductSearchResult(
      Product(
        id: id,
        businessId: 1,
        categoryId: 1,
        name: 'Product $id',
        description: '',
        price: '250.00',
        currency: Currency.egp,
        isFeatured: featured,
      ),
    );

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository({this.page, this.gate});

  final SearchPage? page;
  final Completer<void>? gate;
  int callCount = 0;

  @override
  Future<SearchPage> search({
    String? q,
    SearchFilters filters = const SearchFilters(),
    String? cursor,
  }) async {
    callCount++;
    if (gate != null) {
      await gate!.future;
    }
    return page ?? const SearchPage(items: [], nextCursor: null);
  }
}

class _FakeCategoryRepository implements CategoryRepository {
  @override
  Future<List<CategoryNode>> fetchCategoryTree({
    bool forceRefresh = false,
  }) async => const [];
}

Widget _cards(
  List<SearchResult> results, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  void Function(SearchResult result)? onTap,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme ?? AppTheme.light,
    home: Scaffold(
      body: ListView(
        children: [
          for (final SearchResult r in results)
            SearchResultCard(result: r, onTap: () => onTap?.call(r)),
        ],
      ),
    ),
  );
}

Widget _screen(
  _FakeSearchRepository fake, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      searchRepositoryProvider.overrideWithValue(fake),
      categoryRepositoryProvider.overrideWith(
        (ref) async => _FakeCategoryRepository(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.light,
      home: const SearchScreen(),
    ),
  );
}

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

  group('SearchResultCard', () {
    testWidgets('an organic business row has no Featured badge', (
      tester,
    ) async {
      await tester.pumpWidget(_cards([_biz(1)]));

      expect(find.text('Business 1'), findsOneWidget);
      expect(find.byType(FeaturedBadge), findsNothing);
      expect(find.text('Trader \u2022 Cairo, Egypt'), findsOneWidget);
      expect(find.textContaining('12'), findsWidgets);
      expect(find.byType(AppAvatar), findsOneWidget);
    });

    testWidgets('a Featured business row carries the amber badge and the '
        'word Featured, and organic rows stay fully visible next to it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _cards([_biz(1, featured: true), _biz(2), _biz(3)]),
      );

      expect(find.byType(FeaturedBadge), findsOneWidget);
      expect(find.text('Featured'), findsOneWidget);
      expect(find.text('Business 1'), findsOneWidget);
      expect(find.text('Business 2'), findsOneWidget);
      expect(find.text('Business 3'), findsOneWidget);
    });

    testWidgets('the Verified mark shows only for a verified business', (
      tester,
    ) async {
      await tester.pumpWidget(_cards([_biz(1, verified: true), _biz(2)]));

      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('a Featured product row shows the badge and still frames '
        'the price (P-034)', (tester) async {
      await tester.pumpWidget(_cards([_prod(7, featured: true), _prod(8)]));

      expect(find.byType(FeaturedBadge), findsOneWidget);
      expect(find.text(ProductPriceCopy.note), findsNWidgets(2));
      expect(
        find.text(ProductPriceCopy.headline('250.00', Currency.egp)),
        findsNWidgets(2),
      );
    });

    testWidgets('tapping a row calls onTap with that result', (tester) async {
      final List<int> tapped = <int>[];
      await tester.pumpWidget(
        _cards([_biz(1), _prod(2)], onTap: (r) => tapped.add(r.id)),
      );

      await tester.tap(find.text('Business 1'));
      await tester.tap(find.text('Product 2'));

      expect(tapped, <int>[1, 2]);
    });

    testWidgets('a row is at least 72 logical pixels tall', (tester) async {
      await tester.pumpWidget(_cards([_biz(1)]));

      expect(
        tester.getSize(find.byType(SearchResultCard)).height,
        greaterThanOrEqualTo(72),
      );
    });

    testWidgets('Arabic RTL: avatar at the start (right), chevron at the end '
        '(left), badge text in Arabic', (tester) async {
      await tester.pumpWidget(
        _cards([_biz(1, featured: true)], locale: const Locale('ar')),
      );

      final BuildContext context = tester.element(
        find.byType(SearchResultCard),
      );
      expect(Directionality.of(context), TextDirection.rtl);
      expect(find.text(ar.featuredBadgeLabel), findsOneWidget);
      expect(find.text('Featured'), findsNothing);
      expect(
        tester.getCenter(find.byType(AppAvatar)).dx,
        greaterThan(tester.getCenter(find.byIcon(Icons.chevron_right)).dx),
      );
    });

    testWidgets('dark theme renders both kinds of row without errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _cards([_biz(1, featured: true), _prod(2)], theme: AppTheme.dark),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FeaturedBadge), findsOneWidget);
    });
  });

  group('SearchScreen (P-114 STEP 3B)', () {
    testWidgets('idle: sticky field, one Filters chip, localized prompt', (
      tester,
    ) async {
      await tester.pumpWidget(_screen(_FakeSearchRepository()));
      await tester.pump();

      expect(find.byKey(const Key('searchScreen_queryField')), findsOneWidget);
      expect(find.byKey(const Key('searchScreen_filterButton')), findsOneWidget);
      expect(find.text(en.searchFiltersChip), findsOneWidget);
      expect(find.text(en.searchIdlePrompt), findsOneWidget);
    });

    testWidgets('applying a filter turns it into a chip and shows the count, '
        'and the Filters chip opens the existing panel', (tester) async {
      final fake = _FakeSearchRepository(
        page: SearchPage(items: [_biz(1)], nextCursor: null),
      );
      await tester.pumpWidget(_screen(fake));
      await tester.pump();

      await tester.tap(find.byKey(const Key('searchScreen_filterButton')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('searchFilterPanel_featuredSwitch')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('searchFilterPanel_featuredSwitch')),
      );
      await tester.tap(
        find.byKey(const Key('searchFilterPanel_featuredSwitch')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(en.searchFilterApply));
      await tester.tap(find.text(en.searchFilterApply));
      await tester.pumpAndSettle();

      expect(fake.callCount, 1);
      expect(find.text(en.searchFiltersChipActive(1)), findsOneWidget);
      expect(find.text(en.searchFilterFeaturedOnly), findsOneWidget);
      expect(find.text('Business 1'), findsOneWidget);
    });

    testWidgets('while a search is in flight the list shows skeleton rows, '
        'not a spinner', (tester) async {
      final Completer<void> gate = Completer<void>();
      final fake = _FakeSearchRepository(
        page: SearchPage(items: [_biz(1)], nextCursor: null),
        gate: gate,
      );
      await tester.pumpWidget(_screen(fake));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('searchScreen_queryField')),
        'bag',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(AppShimmerBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Business 1'), findsOneWidget);
      expect(find.byType(AppShimmerBox), findsNothing);
    });

    testWidgets('Featured and organic results both stay in the list, in the '
        'order the server sent them', (tester) async {
      final fake = _FakeSearchRepository(
        page: SearchPage(
          items: [_biz(1, featured: true), _biz(2), _prod(3)],
          nextCursor: null,
        ),
      );
      await tester.pumpWidget(_screen(fake));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('searchScreen_queryField')),
        'x',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byType(FeaturedBadge), findsOneWidget);
      expect(find.text('Business 2'), findsOneWidget);
      expect(find.text('Product 3'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Business 1')).dy,
        lessThan(tester.getTopLeft(find.text('Business 2')).dy),
      );
    });

    testWidgets('Arabic RTL: localized hint and prompt, Filters chip at the '
        'start (right)', (tester) async {
      await tester.pumpWidget(
        _screen(_FakeSearchRepository(), locale: const Locale('ar')),
      );
      await tester.pump();

      final BuildContext context = tester.element(find.byType(SearchScreen));
      expect(Directionality.of(context), TextDirection.rtl);
      expect(find.text(ar.searchFieldHint), findsOneWidget);
      expect(find.text(ar.searchIdlePrompt), findsOneWidget);
      expect(find.text(ar.searchFiltersChip), findsOneWidget);
      expect(
        tester
            .getCenter(find.byKey(const Key('searchScreen_filterButton')))
            .dx,
        greaterThan(400),
      );
    });

    testWidgets('dark theme renders the screen without errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(_FakeSearchRepository(), theme: AppTheme.dark),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(en.searchIdlePrompt), findsOneWidget);
    });
  });
}
