import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/login_screen.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_console/presentation/business_console_shell.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_onboarding_screen.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_provider.dart';
import 'package:social_commerce_app/features/chat/presentation/chat_list_screen.dart';
import 'package:social_commerce_app/features/chat/presentation/chat_unread_provider.dart';
import 'package:social_commerce_app/features/discover/domain/active_story_group_entity.dart';
import 'package:social_commerce_app/features/discover/presentation/discover_provider.dart';
import 'package:social_commerce_app/features/feed/presentation/home_feed_screen.dart';
import 'package:social_commerce_app/features/orders/data/orders_repository.dart';
import 'package:social_commerce_app/features/orders/presentation/order_details_screen.dart';
import 'package:social_commerce_app/features/orders/presentation/orders_list_screen.dart';
import 'package:social_commerce_app/main.dart';
import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/route_names.dart';

import '../features/orders/orders_test_helpers.dart';

/// Part BI-03: the Orders routes. Same conventions as
/// `business_console_router_gate_test.dart` (real app + real router, fake
/// session and profile notifiers).

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
  id: 1,
  businessName: 'Ahmed Trading Co.',
  businessType: BusinessType.trader,
  country: 'Egypt',
  city: 'Cairo',
  isVerified: false,
);

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

class _Pumped {
  _Pumped(this.container, this.repo);

  final ProviderContainer container;
  final FakeOrdersRepository repo;

  GoRouter get router => container.read(appRouterProvider);

  String get path => router.routerDelegate.currentConfiguration.uri.toString();
}

Future<_Pumped> _pumpApp(
  WidgetTester tester, {
  required User? user,
  BusinessProfile? profile,
}) async {
  final repo =
      FakeOrdersRepository()
        ..orders = [testOrder(id: 5)]
        ..order = testOrder(id: 5);
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSessionNotifier(user)),
      businessProfileProvider.overrideWith(
        () => _FakeBusinessProfileNotifier(profile),
      ),
      ordersRepositoryProvider.overrideWithValue(repo),
      chatUnreadCountProvider.overrideWith((ref) async => 0),
      activeStoryGroupsProvider.overrideWith(
        (ref) async => const <ActiveStoryGroup>[],
      ),
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
  return _Pumped(container, repo);
}

void main() {
  group('Orders routes', () {
    testWidgets('a Business user reaches the Orders tab (branch 4) of the '
        'console shell', (tester) async {
      final app = await _pumpApp(tester, user: _business, profile: _profile);

      app.router.go(RouteNames.ordersListPath);
      await tester.pumpAndSettle();

      expect(app.path, RouteNames.ordersListPath);
      expect(find.byType(BusinessConsoleShell), findsOneWidget);
      expect(find.byType(OrdersListScreen), findsOneWidget);
      expect(byKeyName('orderTile_5'), findsOneWidget);
      expect(
        find.byKey(const Key('business-console-nav-orders')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<NavigationBar>(
              find.byKey(const Key('business-console-nav-bar')),
            )
            .selectedIndex,
        4,
      );
    });

    testWidgets('the order details route builds from the path id alone', (
      tester,
    ) async {
      final app = await _pumpApp(tester, user: _business, profile: _profile);

      app.router.goNamed(
        RouteNames.orderDetail,
        pathParameters: {RouteNames.idParam: '5'},
      );
      await tester.pumpAndSettle();

      expect(app.path, '${RouteNames.ordersListPath}/5');
      expect(find.byType(OrderDetailsScreen), findsOneWidget);
      expect(byKeyName('orderDetailsTotal'), findsOneWidget);
    });

    testWidgets('a non-numeric order id shows not-found', (tester) async {
      final app = await _pumpApp(tester, user: _business, profile: _profile);

      app.router.go('${RouteNames.ordersListPath}/abc');
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailsScreen), findsOneWidget);
      expect(byKeyName('orderNotFound'), findsOneWidget);
    });

    testWidgets('a Customer is sent to /home from both Orders routes', (
      tester,
    ) async {
      final app = await _pumpApp(tester, user: _customer);

      for (final target in <String>[
        RouteNames.ordersListPath,
        '${RouteNames.ordersListPath}/5',
      ]) {
        app.router.go(target);
        await tester.pumpAndSettle();

        expect(app.path, RouteNames.homePath, reason: 'for $target');
        expect(find.byType(HomeFeedScreen), findsOneWidget);
        expect(find.byType(OrdersListScreen), findsNothing);
        expect(find.byType(OrderDetailsScreen), findsNothing);
      }
    });

    testWidgets('a signed-out user is sent to /login', (tester) async {
      final app = await _pumpApp(tester, user: null);

      app.router.go(RouteNames.ordersListPath);
      await tester.pumpAndSettle();

      expect(app.path, RouteNames.loginPath);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('a Business user with no profile is held at onboarding', (
      tester,
    ) async {
      final app = await _pumpApp(tester, user: _business, profile: null);

      app.router.go(RouteNames.ordersListPath);
      await tester.pumpAndSettle();

      expect(app.path, RouteNames.businessOnboardingPath);
      expect(find.byType(BusinessOnboardingScreen), findsOneWidget);
    });

    testWidgets('chat thread without its Conversation extra still redirects '
        'to the chat list for a Business user (restart-safe)', (tester) async {
      final app = await _pumpApp(tester, user: _business, profile: _profile);

      app.router.goNamed(
        RouteNames.chatThread,
        pathParameters: {RouteNames.idParam: '42'},
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChatListScreen), findsOneWidget);
    });
  });
}
