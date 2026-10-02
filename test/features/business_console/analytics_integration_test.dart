import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_console/data/analytics_repository.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_screen.dart';
import 'package:social_commerce_app/features/business_console/presentation/business_console_shell.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_provider.dart';
import 'package:social_commerce_app/features/feed/presentation/home_feed_screen.dart';
import 'package:social_commerce_app/features/products/data/product_repository_impl.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_repository.dart';
import 'package:social_commerce_app/features/products/presentation/product_list_screen.dart';
import 'package:social_commerce_app/main.dart';
import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/route_names.dart';

import 'fake_analytics_repository.dart';

/// Part P-085 (Chat 3): router-level integration test for the Analytics
/// screen.
///
/// Runs the REAL `SocialCommerceApp` + REAL `appRouterProvider` + the REAL
/// `AnalyticsScreen`, `analyticsStatsProvider` and `businessProfileProvider`
/// wiring. Only the network edge is faked (`analyticsRepositoryProvider`,
/// `productRepositoryProvider`) and the session/profile notifiers.
///
/// What this file proves (and what it deliberately leaves to other files):
///  * a Business account reaches the real screen directly and through the
///    console's Analytics tab (the P-083 placeholder is gone);
///  * a Customer is still blocked by the P-083 gate and the repository is
///    never called for them;
///  * the repository is asked for the OWN business id and for the selected
///    date range (7 days by default, 14 after tapping the 14 chip);
///  * the screen shows only the four tracked metrics, with no
///    product/placeholder wording or keys inside the screen's own subtree
///    (the shell's "Products" tab label is outside it and is expected);
///  * empty (zero rows from the API) is not rendered as zeros, and the
///    error state recovers through Retry.
///
/// Chart geometry and summation are covered by the Chat 2 widget tests.

const _customer = User(
  id: 1,
  email: 'customer@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

const _business = User(
  id: 2,
  email: 'business@example.com',
  accountType: AccountType.business,
  isModerator: false,
  isStaff: false,
);

const _profile = BusinessProfile(
  id: 7,
  businessName: 'Ahmed Trading Co.',
  businessType: BusinessType.trader,
  country: 'Egypt',
  city: 'Cairo',
  isVerified: false,
);

const _trackedLabels = <String>[
  'New followers',
  'Likes received',
  'Comments received',
  'Story views',
  'New ratings',
  'Average rating',
  'Active products',
  'Published posts',
  'Published reels',
];

/// Metrics that exist in the product deck but are NOT tracked by P-084.
const _untrackedLabels = <String>[
  'Product views',
  'Profile views',
  'Shares',
  'Saves',
  'Messages',
];

class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._initial);

  final User? _initial;

  @override
  Future<User?> build() async => _initial;
}

class _FakeBusinessProfileNotifier extends BusinessProfileNotifier {
  _FakeBusinessProfileNotifier(this._initial);

  final BusinessProfile? _initial;

  @override
  Future<BusinessProfile?> build() async => _initial;
}

/// Immediately-resolving empty product list so the Products tab (branch
/// 0) never touches the network when the console is entered normally.
class _FakeProductRepository implements ProductRepository {
  @override
  Future<PaginatedResponse<Product>> fetchOwnProducts() async =>
      const PaginatedResponse<Product>(results: [], next: null, previous: null);

  @override
  Future<Product> createProduct({
    required int categoryId,
    required String name,
    required String description,
    required String price,
    required Currency currency,
    File? imageFile,
    bool isActive = true,
  }) => throw UnimplementedError('Not exercised by this test');

  @override
  Future<Product> updateProduct({
    required int productId,
    int? categoryId,
    String? name,
    String? description,
    String? price,
    Currency? currency,
    File? imageFile,
    bool? isActive,
  }) => throw UnimplementedError('Not exercised by this test');

  @override
  Future<void> deleteProduct(int productId) async {}
}

class _App {
  _App(this.container, this.analytics);

  final ProviderContainer container;
  final FakeAnalyticsRepository analytics;

  GoRouter get router => container.read(appRouterProvider);

  String get path => router.routerDelegate.currentConfiguration.uri.toString();
}

Future<_App> _pumpApp(
  WidgetTester tester, {
  required User user,
  BusinessProfile? profile = _profile,
  FakeAnalyticsRepository? analytics,
}) async {
  // The Analytics screen is a scrollable column (totals, then two charts).
  // On the default 800x600 test surface the second chart lies below the
  // fold and a lazy list never builds it, so give the test a tall surface.
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fake = analytics ?? FakeAnalyticsRepository(stats: knownTrendStats());
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSessionNotifier(user)),
      businessProfileProvider.overrideWith(
        () => _FakeBusinessProfileNotifier(profile),
      ),
      productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
      analyticsRepositoryProvider.overrideWithValue(fake),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SocialCommerceApp(),
    ),
  );
  await tester.pumpAndSettle();

  return _App(container, fake);
}

Future<void> _goToAnalytics(WidgetTester tester, _App app) async {
  app.router.go(RouteNames.businessAnalyticsPath);
  await tester.pumpAndSettle();
}

Finder _inScreen(Finder matching) =>
    find.descendant(of: find.byType(AnalyticsScreen), matching: matching);

void main() {
  group('Analytics integration (Part P-085) — Business account', () {
    testWidgets(
      'a Business account opens /business-console/analytics and sees the '
      'real AnalyticsScreen inside the console shell',
      (tester) async {
        final app = await _pumpApp(tester, user: _business);
        await _goToAnalytics(tester, app);

        expect(app.path, RouteNames.businessAnalyticsPath);
        expect(find.byType(BusinessConsoleShell), findsOneWidget);
        expect(find.byType(AnalyticsScreen), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Analytics'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('business-analytics-placeholder')),
          findsNothing,
        );
        expect(find.text('Analytics coming soon'), findsNothing);
      },
    );

    testWidgets('the console Analytics tab leads to the same screen and the '
        'repository is asked for the OWN business id', (tester) async {
      final app = await _pumpApp(tester, user: _business);

      app.router.go(RouteNames.businessConsolePath);
      await tester.pumpAndSettle();
      expect(find.byType(ProductListScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('business-console-nav-analytics')));
      await tester.pumpAndSettle();

      expect(app.path, RouteNames.businessAnalyticsPath);
      expect(find.byType(AnalyticsScreen), findsOneWidget);
      expect(app.analytics.calls, hasLength(1));
      expect(app.analytics.calls.single.businessId, _profile.id);
    });

    testWidgets(
      'the screen renders real rows: the four tracked totals (sum of the '
      'rows), both charts, and the days-with-data line',
      (tester) async {
        final app = await _pumpApp(tester, user: _business);
        await _goToAnalytics(tester, app);

        // knownTrendStats(): followers 1+2+3, likes 2+4+6, comments 0+1+2,
        // story views 1+3+5.
        const expectedTotals = <String, String>{
          'analytics-total-new-followers': '6',
          'analytics-total-likes-received': '12',
          'analytics-total-comments-received': '3',
          'analytics-total-story-views': '9',
        };
        for (final entry in expectedTotals.entries) {
          expect(
            find.descendant(
              of: find.byKey(Key(entry.key)),
              matching: find.text(entry.value),
              matchRoot: true,
            ),
            findsOneWidget,
            reason: '${entry.key} should show ${entry.value}',
          );
        }

        expect(
          find.byKey(const Key('analytics-chart-new-followers')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('analytics-chart-total-likes')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('analytics-days-with-data')),
          findsOneWidget,
        );

        // P-093 (knownTrendStats): new ratings 1+0+2 = 3, latest rating
        // snapshot 4.5, and the LATEST row's catalog snapshot (4 active
        // products, 3 posts, 2 reels).
        expect(
          find.byKey(const Key('analytics-chart-rating-trend')),
          findsOneWidget,
        );
        const expectedP093 = <String, String>{
          'analytics-total-new-ratings': '3',
          'analytics-rating-latest': '4.50',
          'analytics-catalog-active-products': '4',
          'analytics-catalog-published-posts': '3',
          'analytics-catalog-published-reels': '2',
        };
        for (final entry in expectedP093.entries) {
          expect(
            find.descendant(
              of: find.byKey(Key(entry.key)),
              matching: find.text(entry.value),
              matchRoot: true,
            ),
            findsOneWidget,
            reason: '${entry.key} should show ${entry.value}',
          );
        }
        expect(find.byKey(const Key('analytics-loading')), findsNothing);
        expect(find.byKey(const Key('analytics-error')), findsNothing);
        expect(find.byKey(const Key('analytics-empty')), findsNothing);
      },
    );

    testWidgets('only tracked metrics are labelled, and no product-views or '
        'placeholder content exists inside the screen', (tester) async {
      final app = await _pumpApp(tester, user: _business);
      await _goToAnalytics(tester, app);

      for (final label in _trackedLabels) {
        expect(
          _inScreen(find.text(label)),
          findsWidgets,
          reason: 'missing tracked label "$label"',
        );
      }
      for (final label in _untrackedLabels) {
        expect(
          _inScreen(find.text(label)),
          findsNothing,
          reason: 'untracked metric "$label" must not be shown',
        );
      }

      final texts =
          tester
              .widgetList<Text>(_inScreen(find.byType(Text)))
              .map(
                (t) =>
                    (t.data ?? t.textSpan?.toPlainText() ?? '').toLowerCase(),
              )
              .toList();
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(
          text.contains('product view'),
          isFalse,
          reason: 'text: "$text"',
        );
        expect(text.contains('productview'), isFalse, reason: 'text: "$text"');
        expect(text.contains('placeholder'), isFalse, reason: 'text: "$text"');
        expect(text.contains('coming soon'), isFalse, reason: 'text: "$text"');
      }

      final offendingKeys =
          tester
              .widgetList<Widget>(
                _inScreen(
                  find.byWidgetPredicate((w) {
                    final key = w.key;
                    if (key == null) return false;
                    final text = key.toString().toLowerCase();
                    return text.contains('productview') ||
                        text.contains('product-view') ||
                        text.contains('placeholder');
                  }),
                ),
              )
              .toList();
      expect(offendingKeys, isEmpty);
    });

    testWidgets(
      'the default range is 7 days and tapping the 14 chip re-requests '
      'a 14-day range for the same business',
      (tester) async {
        final app = await _pumpApp(tester, user: _business);
        await _goToAnalytics(tester, app);

        expect(app.analytics.calls, hasLength(1));
        final first = app.analytics.calls.single;
        expect(first.to.difference(first.from).inDays, 6);

        await tester.tap(find.byKey(const Key('analytics-range-14')));
        await tester.pumpAndSettle();

        expect(app.analytics.calls, hasLength(2));
        final second = app.analytics.calls.last;
        expect(second.businessId, _profile.id);
        expect(second.to.difference(second.from).inDays, 13);
      },
    );

    testWidgets(
      'zero rows from the API shows the empty state, NOT zero totals',
      (tester) async {
        final app = await _pumpApp(
          tester,
          user: _business,
          analytics: FakeAnalyticsRepository(),
        );
        await _goToAnalytics(tester, app);

        expect(find.byKey(const Key('analytics-empty')), findsOneWidget);
        expect(
          find.byKey(const Key('analytics-total-new-followers')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('analytics-chart-new-followers')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a repository failure shows the error state and Retry asks again',
      (tester) async {
        final app = await _pumpApp(
          tester,
          user: _business,
          analytics: FakeAnalyticsRepository(error: Exception('boom')),
        );
        await _goToAnalytics(tester, app);

        expect(find.byKey(const Key('analytics-error')), findsOneWidget);
        expect(find.byKey(const Key('analytics-retry-button')), findsOneWidget);
        expect(app.analytics.calls, hasLength(1));

        await tester.tap(find.byKey(const Key('analytics-retry-button')));
        await tester.pumpAndSettle();

        expect(app.analytics.calls, hasLength(2));
        expect(find.byKey(const Key('analytics-error')), findsOneWidget);
      },
    );
  });

  group('Analytics integration (Part P-085) — Customer account', () {
    testWidgets(
      'a Customer is still blocked by the P-083 gate: sent to /home, the '
      'screen never builds and the repository is never called',
      (tester) async {
        final app = await _pumpApp(tester, user: _customer);

        app.router.go(RouteNames.businessAnalyticsPath);
        await tester.pumpAndSettle();

        expect(app.path, RouteNames.homePath);
        expect(find.byType(HomeFeedScreen), findsOneWidget);
        expect(find.byType(AnalyticsScreen), findsNothing);
        expect(find.byType(BusinessConsoleShell), findsNothing);
        expect(app.analytics.calls, isEmpty);
      },
    );
  });
}
