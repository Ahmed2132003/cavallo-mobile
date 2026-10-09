import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_status_chip.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_provider.dart';
import 'package:social_commerce_app/features/business_console/presentation/console_dashboard.dart';
import 'package:social_commerce_app/features/content/domain/content_item_entity.dart';
import 'package:social_commerce_app/features/content/presentation/own_content_provider.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/presentation/own_products_provider.dart';
import 'package:social_commerce_app/features/products/presentation/product_list_screen.dart';
import 'package:social_commerce_app/features/stories/domain/own_story_entity.dart';
import 'package:social_commerce_app/features/stories/presentation/own_stories_provider.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-115 (STEP 5A): restyle checks for the Business Console dashboard,
/// the shared status chip and the product list header.
///
/// The behaviour tests (create, edit, delete, retry) stay in the P-033 test
/// files, which are unchanged. This file is ASCII only: Arabic text is read
/// from the generated localizations, never typed here.

class _FakeProducts extends OwnProductsNotifier {
  @override
  Future<List<Product>> build() async => const <Product>[];
}

class _FakeContent extends OwnContentNotifier {
  @override
  Future<List<ContentItem>> build() async => const <ContentItem>[];
}

class _FakeStories extends OwnStoriesNotifier {
  @override
  Future<List<OwnStory>> build() async => const <OwnStory>[];
}

class _FailingStories extends OwnStoriesNotifier {
  @override
  Future<List<OwnStory>> build() async => throw StateError('boom');
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  bool failingStories = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ownProductsProvider.overrideWith(_FakeProducts.new),
        ownContentProvider.overrideWith(_FakeContent.new),
        ownStoriesProvider.overrideWith(
          failingStories ? _FailingStories.new : _FakeStories.new,
        ),
        analyticsStatsProvider.overrideWith((ref) async => <DailyStats>[]),
      ],
      child: MaterialApp(
        locale: locale,
        theme: theme ?? AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AppStatusChip', () {
    testWidgets('always shows an icon and a text label (not colour alone)', (
      tester,
    ) async {
      for (final tone in AppStatusTone.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: AppStatusChip(
                label: 'label-${tone.name}',
                icon: Icons.info_outline,
                tone: tone,
              ),
            ),
          ),
        );
        expect(find.text('label-${tone.name}'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      }
    });

    testWidgets('a long reason wraps instead of being cut off', (tester) async {
      const reason =
          'Rejected: the picture is blurry and the price is missing from '
          'the caption, please fix both and send it again';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SizedBox(
              width: 200,
              child: AppStatusChip(
                label: reason,
                icon: Icons.cancel_outlined,
                tone: AppStatusTone.danger,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(reason));
      expect(text.overflow, isNull);
      expect(tester.getSize(find.text(reason)).height, greaterThan(30));
    });
  });

  group('ConsoleDashboardCards', () {
    testWidgets('shows the four areas with their counts (English, light)', (
      tester,
    ) async {
      await _pump(tester, const Scaffold(body: ConsoleDashboardCards()));
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(find.byKey(const Key('console-dash-products')), findsOneWidget);
      expect(find.byKey(const Key('console-dash-content')), findsOneWidget);
      expect(find.byKey(const Key('console-dash-stories')), findsOneWidget);
      expect(find.byKey(const Key('console-dash-analytics')), findsOneWidget);
      expect(find.text(l10n.consoleNavProducts), findsOneWidget);
      expect(find.text(l10n.consoleDashFollowers), findsOneWidget);
      expect(find.text('0'), findsNWidgets(4));
    });

    testWidgets('localized in Arabic and dark theme', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: ConsoleDashboardCards()),
        locale: const Locale('ar'),
        theme: AppTheme.dark,
      );
      final l10n = lookupAppLocalizations(const Locale('ar'));

      expect(find.text(l10n.consoleNavProducts), findsOneWidget);
      expect(find.text(l10n.consoleDashStories), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one failing area shows a dash and the others still show', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(body: ConsoleDashboardCards()),
        failingStories: true,
      );
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(find.text(l10n.consoleDashValueUnavailable), findsOneWidget);
      expect(find.text('0'), findsNWidgets(3));
    });
  });

  group('ProductListScreen header', () {
    testWidgets('renders the optional header above the empty state', (
      tester,
    ) async {
      await _pump(
        tester,
        ProductListScreen(
          onCreateNew: () {},
          onEditProduct: (_) {},
          header: const Text('header-probe'),
        ),
      );
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(find.text('header-probe'), findsOneWidget);
      expect(find.text(l10n.consoleProductsEmpty), findsOneWidget);
    });

    testWidgets('Arabic title and create label', (tester) async {
      await _pump(
        tester,
        ProductListScreen(onCreateNew: () {}, onEditProduct: (_) {}),
        locale: const Locale('ar'),
      );
      final l10n = lookupAppLocalizations(const Locale('ar'));

      expect(find.text(l10n.consoleProductsTitle), findsOneWidget);
      expect(find.text(l10n.consoleProductsCreate), findsOneWidget);
    });
  });
}
