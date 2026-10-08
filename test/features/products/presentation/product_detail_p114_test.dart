import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
import 'package:social_commerce_app/features/products/data/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_variant_entity.dart';
import 'package:social_commerce_app/features/products/presentation/product_detail_screen.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/social/domain/social_interaction_repository.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-114 STEP 4A: product detail restyle. Presentation only: these
/// tests prove the new anatomy (Featured badge, variants, skeleton, Save)
/// in English LTR and Arabic RTL, and that no purchase affordance exists.
class _FakeProductRepository implements ProductPublicRepository {
  _FakeProductRepository({this.result, this.pending});

  final Product? result;
  final Completer<Product?>? pending;

  @override
  Future<Product?> fetchPublicProduct(int id) async {
    if (pending != null) return pending!.future;
    return result;
  }

  @override
  Future<PaginatedResponse<Product>> fetchBusinessProducts(int businessId) {
    throw UnimplementedError('not used by ProductDetailScreen');
  }
}

/// Only the Save endpoints are needed; every other call would be a test bug.
class _FakeSocialRepository implements SocialInteractionRepository {
  final List<String> saved = <String>[];

  @override
  Future<bool> saveContent({
    required String contentType,
    required int objectId,
  }) async {
    saved.add('$contentType:$objectId');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const Product _featured = Product(
  id: 10,
  businessId: 7,
  categoryId: 3,
  name: 'Cotton T-Shirt',
  description: 'Plain white cotton t-shirt.',
  price: '199.99',
  currency: Currency.egp,
  isFeatured: true,
  variants: [ProductVariant(id: 1, name: 'Size', value: 'Large')],
);

const Product _plain = Product(
  id: 11,
  businessId: 7,
  categoryId: 3,
  name: 'Plain Cap',
  description: '',
  price: '50.00',
  currency: Currency.sar,
);

Widget _app(
  _FakeProductRepository products, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  _FakeSocialRepository? social,
}) {
  return ProviderScope(
    overrides: [
      productPublicRepositoryProvider.overrideWithValue(products),
      if (social != null)
        socialInteractionRepositoryProvider.overrideWithValue(social),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.light,
      home: const ProductDetailScreen(productId: '10'),
    ),
  );
}

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

  testWidgets('English LTR: anatomy, Featured badge, variants, no purchase UI', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeProductRepository(result: _featured)));
    await tester.pumpAndSettle();

    expect(find.text('Cotton T-Shirt'), findsOneWidget);
    expect(find.byType(FeaturedBadge), findsOneWidget);
    expect(find.text('Starting from 199.99 EGP'), findsOneWidget);
    expect(find.text('Size: Large'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Message Business'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(find.byTooltip('Save'), findsOneWidget);
    expect(find.byIcon(Icons.shopping_cart_outlined), findsNothing);
    expect(
      find.textContaining(
        RegExp(r'buy now|add to cart|checkout|purchase', caseSensitive: false),
      ),
      findsNothing,
    );
    expect(Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.ltr);
  });

  testWidgets('a product without Featured has no badge', (tester) async {
    await tester.pumpWidget(_app(_FakeProductRepository(result: _plain)));
    await tester.pumpAndSettle();

    expect(find.text('Plain Cap'), findsOneWidget);
    expect(find.byType(FeaturedBadge), findsNothing);
    expect(find.text(en.productNoDescription), findsOneWidget);
  });

  testWidgets('Arabic RTL: localized copy, tooltips and direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _FakeProductRepository(result: _featured),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.rtl);
    expect(find.text(ar.productPriceHeadline('199.99', 'EGP')), findsOneWidget);
    expect(find.text(ar.productPriceNote), findsOneWidget);
    expect(find.text(ar.productMessageBusiness), findsOneWidget);
    expect(find.text(ar.productVariantsTitle), findsOneWidget);
    expect(find.byTooltip(ar.actionShare), findsOneWidget);
    expect(find.byTooltip(ar.actionSave), findsOneWidget);
    // The Arabic copy really differs from the English copy.
    expect(ar.productMessageBusiness, isNot(en.productMessageBusiness));
  });

  testWidgets('dark theme builds without errors', (tester) async {
    await tester.pumpWidget(
      _app(
        _FakeProductRepository(result: _featured),
        theme: AppTheme.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cotton T-Shirt'), findsOneWidget);
  });

  testWidgets('loading shows a skeleton, not a spinner', (tester) async {
    final completer = Completer<Product?>();
    await tester.pumpWidget(
      _app(_FakeProductRepository(pending: completer)),
    );
    await tester.pump();

    expect(find.byType(AppShimmerBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    completer.complete(_featured);
    await tester.pumpAndSettle();
    expect(find.byType(AppShimmerBox), findsNothing);
    expect(find.text('Cotton T-Shirt'), findsOneWidget);
  });

  testWidgets('Save toggles the bookmark and calls the save endpoint', (
    tester,
  ) async {
    final social = _FakeSocialRepository();
    await tester.pumpWidget(
      _app(_FakeProductRepository(result: _featured), social: social),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(social.saved, ['product:10']);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byTooltip(en.savedUnsave), findsOneWidget);
  });
}
