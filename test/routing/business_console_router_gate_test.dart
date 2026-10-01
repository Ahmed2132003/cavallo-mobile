import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/login_screen.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_console/data/analytics_repository.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_screen.dart';
import 'package:social_commerce_app/features/business_console/presentation/business_console_shell.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_onboarding_screen.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_provider.dart';
import 'package:social_commerce_app/features/feed/presentation/home_feed_screen.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_queue_screen.dart';
import 'package:social_commerce_app/features/products/data/product_repository_impl.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_repository.dart';
import 'package:social_commerce_app/features/products/presentation/product_list_screen.dart';
import 'package:social_commerce_app/main.dart';
import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/route_names.dart';
import '../features/business_console/fake_analytics_repository.dart';

/// Part P-083 scope: router tests for the Business-only gate on
/// `/business-console` (and everything under it), plus the console's
/// landing behaviour (`/business-console` -> branch 0, Products).
///
/// Same conventions as `business_profile_router_gate_test.dart`:
/// [sessionProvider] and [businessProfileProvider] are overridden with
/// hand-rolled fake notifiers (no mockito/mocktail), and the real
/// `SocialCommerceApp` + real `appRouterProvider` are exercised. The
/// product repository is overridden too, so the Products tab (the
/// landing branch) never touches the network.
///
/// Gate order under test (see `app_router.dart`): auth -> P-028C1
/// Business-profile onboarding -> P-083 Business-only console ->
/// P-040 moderator. The moderator gate is only re-checked on its
/// "blocked" side here; its "allowed" side stays covered by
/// `moderation_router_gate_test.dart`.

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

/// A Customer who is also a moderator. The console must still be closed
/// to them (decision D4/D5): the Moderation Queue stays reachable from
/// the Home debug menu, the console does not.
const _customerModerator = User(
  id: 3,
  email: 'mod@example.com',
  accountType: AccountType.customer,
  isModerator: true,
  isStaff: false,
);

const _profile = BusinessProfile(
  id: 1,
  businessName: 'Ahmed Trading Co.',
  businessType: BusinessType.trader,
  country: 'Egypt',
  city: 'Cairo',
  isVerified: false,
);

/// Every location under `/business-console` that exists in the route
/// table: the four branch roots plus the four top-level forms. All of
/// them must be closed to a Customer.
const _consolePaths = <String>[
  RouteNames.businessConsolePath,
  RouteNames.productListPath,
  RouteNames.productFormPath,
  RouteNames.contentListPath,
  RouteNames.postFormPath,
  RouteNames.reelFormPath,
  RouteNames.storyListPath,
  RouteNames.storyFormPath,
  RouteNames.businessAnalyticsPath,
];

class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._initial);

  final User? _initial;

  @override
  Future<User?> build() async => _initial;
}

class _CallCounter {
  int count = 0;
}

class _FakeBusinessProfileNotifier extends BusinessProfileNotifier {
  _FakeBusinessProfileNotifier(this._initial, this._buildCalls);

  final BusinessProfile? _initial;
  final _CallCounter _buildCalls;

  @override
  Future<BusinessProfile?> build() async {
    _buildCalls.count += 1;
    return _initial;
  }
}

/// Immediately-resolving empty product list, so the Products tab renders
/// without the network. Same shape as the fake in `app_router_test.dart`.
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

class _Pumped {
  _Pumped(this.container, this.profileBuilds);

  final ProviderContainer container;

  /// How many times `businessProfileProvider.build()` ran.
  final _CallCounter profileBuilds;

  GoRouter get router => container.read(appRouterProvider);

  String get path => router.routerDelegate.currentConfiguration.uri.toString();
}

Future<_Pumped> _pumpApp(
  WidgetTester tester, {
  required User? user,
  BusinessProfile? profile,
}) async {
  final profileBuilds = _CallCounter();
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSessionNotifier(user)),
      businessProfileProvider.overrideWith(
        () => _FakeBusinessProfileNotifier(profile, profileBuilds),
      ),
      productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
      analyticsRepositoryProvider.overrideWithValue(FakeAnalyticsRepository()),
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

  return _Pumped(container, profileBuilds);
}

void main() {
  group('Business Console gate (Part P-083)', () {
    testWidgets(
      'a Customer navigating to /business-console is sent to /home, and the '
      'Business profile provider is never built for them',
      (tester) async {
        final app = await _pumpApp(tester, user: _customer);

        app.router.go(RouteNames.businessConsolePath);
        await tester.pumpAndSettle();

        expect(app.path, RouteNames.homePath);
        expect(find.byType(HomeFeedScreen), findsOneWidget);
        expect(find.byType(BusinessConsoleShell), findsNothing);
        expect(app.profileBuilds.count, 0);
      },
    );

    testWidgets(
      'a Customer is blocked from EVERY location under /business-console '
      '(branch roots and the create/edit forms alike)',
      (tester) async {
        final app = await _pumpApp(tester, user: _customer);

        for (final target in _consolePaths) {
          app.router.go(target);
          await tester.pumpAndSettle();

          expect(
            app.path,
            RouteNames.homePath,
            reason: 'Customer must not stay on $target',
          );
          expect(
            find.byType(BusinessConsoleShell),
            findsNothing,
            reason: 'the console shell must not build for a Customer ($target)',
          );
        }
      },
    );

    testWidgets(
      'a Business user WITH a profile reaches the console, including a '
      'deep branch root, and sees all four destinations',
      (tester) async {
        final app = await _pumpApp(tester, user: _business, profile: _profile);

        app.router.go(RouteNames.businessConsolePath);
        await tester.pumpAndSettle();

        expect(find.byType(BusinessConsoleShell), findsOneWidget);
        for (final label in const [
          'Products',
          'Posts/Reels',
          'Stories',
          'Analytics',
        ]) {
          expect(find.text(label), findsWidgets, reason: 'missing "$label"');
        }

        app.router.go(RouteNames.businessAnalyticsPath);
        await tester.pumpAndSettle();

        expect(app.path, RouteNames.businessAnalyticsPath);
        expect(find.byType(AnalyticsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'a Business user with NO profile goes to onboarding, never the console '
      '(P-028C1 gate still wins)',
      (tester) async {
        final app = await _pumpApp(tester, user: _business, profile: null);

        expect(find.byType(BusinessOnboardingScreen), findsOneWidget);

        for (final target in [
          RouteNames.businessConsolePath,
          RouteNames.productListPath,
        ]) {
          app.router.go(target);
          await tester.pumpAndSettle();

          expect(
            app.path,
            RouteNames.businessOnboardingPath,
            reason: 'no-profile Business must be held at onboarding ($target)',
          );
          expect(find.byType(BusinessConsoleShell), findsNothing);
          expect(find.byType(BusinessOnboardingScreen), findsOneWidget);
        }
      },
    );

    testWidgets(
      'an unauthenticated user is sent to /login, not /home, from the '
      'console and from a nested form',
      (tester) async {
        final app = await _pumpApp(tester, user: null);

        expect(find.byType(LoginScreen), findsOneWidget);

        for (final target in [
          RouteNames.businessConsolePath,
          RouteNames.storyFormPath,
        ]) {
          app.router.go(target);
          await tester.pumpAndSettle();

          expect(app.path, RouteNames.loginPath, reason: 'for $target');
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(find.byType(BusinessConsoleShell), findsNothing);
        }
      },
    );

    testWidgets(
      '/business-console lands on branch 0 (Products), and the nav bar can '
      'switch to Analytics and back',
      (tester) async {
        final app = await _pumpApp(tester, user: _business, profile: _profile);

        app.router.go(RouteNames.businessConsolePath);
        await tester.pumpAndSettle();

        expect(app.path, RouteNames.productListPath);
        expect(find.byType(ProductListScreen), findsOneWidget);
        expect(
          tester
              .widget<NavigationBar>(
                find.byKey(const Key('business-console-nav-bar')),
              )
              .selectedIndex,
          0,
        );

        await tester.tap(
          find.byKey(const Key('business-console-nav-analytics')),
        );
        await tester.pumpAndSettle();

        expect(app.path, RouteNames.businessAnalyticsPath);
        expect(find.byType(AnalyticsScreen), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('business-console-nav-products')),
        );
        await tester.pumpAndSettle();

        expect(app.path, RouteNames.productListPath);
        expect(find.byType(ProductListScreen), findsOneWidget);
      },
    );

    testWidgets('a Customer who is also a moderator is still blocked from the '
        'console (role flags do not open it)', (tester) async {
      final app = await _pumpApp(tester, user: _customerModerator);

      app.router.go(RouteNames.businessConsolePath);
      await tester.pumpAndSettle();

      expect(app.path, RouteNames.homePath);
      expect(find.byType(BusinessConsoleShell), findsNothing);
    });
  });

  group('moderator gate still intact after the console gate (Part P-040)', () {
    testWidgets('a plain Customer navigating to /moderation is sent to /home', (
      tester,
    ) async {
      final app = await _pumpApp(tester, user: _customer);

      app.router.go(RouteNames.moderationPath);
      await tester.pumpAndSettle();

      expect(app.path, RouteNames.homePath);
      expect(find.byType(ModerationQueueScreen), findsNothing);
    });

    testWidgets(
      'a plain Business user (with profile) navigating to /moderation is '
      'sent to /home',
      (tester) async {
        final app = await _pumpApp(tester, user: _business, profile: _profile);

        app.router.go(RouteNames.moderationPath);
        await tester.pumpAndSettle();

        expect(app.path, RouteNames.homePath);
        expect(find.byType(ModerationQueueScreen), findsNothing);
      },
    );
  });
}
