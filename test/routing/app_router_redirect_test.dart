import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// A [SessionNotifier] whose [build] resolves immediately to a fixed
/// value, bypassing the real `_restoreSession` (and therefore
/// `authRepositoryProvider`/`secureTokenStorageProvider`) entirely. This
/// drives [appRouterProvider]'s redirect guard through both the "signed
/// in" and "signed out" states deterministically, with no real backend or
/// secure-storage plugin involved — this file tests the redirect logic in
/// `app_router.dart`, not `SessionNotifier` itself (already covered by
/// Part P-021a's own `session_provider_test.dart`).
class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._fixedValue);

  final User? _fixedValue;

  @override
  Future<User?> build() async => _fixedValue;
}

const _fakeUser = User(
  id: 1,
  email: 'test@example.com',
  accountType: AccountType.customer,
);

/// Pumps a real [GoRouter] (from [appRouterProvider]) wrapped in
/// [MaterialApp.router], with [sessionProvider] overridden to resolve
/// immediately to [sessionValue]. Returns the [GoRouter] so tests can
/// drive further navigation and inspect the resulting location.
Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  required User? sessionValue,
}) async {
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSessionNotifier(sessionValue)),
    ],
  );
  addTearDown(container.dispose);

  // Let the fake SessionNotifier.build() resolve before the router's
  // first redirect evaluation runs against it.
  await container.read(sessionProvider.future);

  final router = container.read(appRouterProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return router;
}

/// The router's current location as a plain path string, e.g. `/login`.
String _currentPath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  group('appRouterProvider redirect guard (Part P-021b)', () {
    testWidgets(
      'signed out: a direct visit to a protected route bounces to /login',
      (tester) async {
        final router = await _pumpRouter(tester, sessionValue: null);

        router.goNamed(RouteNames.home);
        await tester.pumpAndSettle();

        expect(_currentPath(router), RouteNames.loginPath);
      },
    );

    testWidgets('signed out: another protected route also bounces to /login', (
      tester,
    ) async {
      final router = await _pumpRouter(tester, sessionValue: null);

      router.goNamed(RouteNames.businessConsole);
      await tester.pumpAndSettle();

      expect(_currentPath(router), RouteNames.loginPath);
    });

    testWidgets(
      'signed out: /login and /register both stay directly reachable',
      (tester) async {
        final router = await _pumpRouter(tester, sessionValue: null);

        router.goNamed(RouteNames.register);
        await tester.pumpAndSettle();
        expect(_currentPath(router), RouteNames.registerPath);

        router.goNamed(RouteNames.login);
        await tester.pumpAndSettle();
        expect(_currentPath(router), RouteNames.loginPath);
      },
    );

    testWidgets('signed out: cold-start splash bounces to /login', (
      tester,
    ) async {
      final router = await _pumpRouter(tester, sessionValue: null);

      expect(_currentPath(router), RouteNames.loginPath);
    });

    testWidgets('signed in: visiting /login bounces to /home', (tester) async {
      final router = await _pumpRouter(tester, sessionValue: _fakeUser);

      router.goNamed(RouteNames.login);
      await tester.pumpAndSettle();

      expect(_currentPath(router), RouteNames.homePath);
    });

    testWidgets('signed in: visiting /register bounces to /home', (
      tester,
    ) async {
      final router = await _pumpRouter(tester, sessionValue: _fakeUser);

      router.goNamed(RouteNames.register);
      await tester.pumpAndSettle();

      expect(_currentPath(router), RouteNames.homePath);
    });

    testWidgets('signed in: cold-start splash bounces to /home', (
      tester,
    ) async {
      final router = await _pumpRouter(tester, sessionValue: _fakeUser);

      expect(_currentPath(router), RouteNames.homePath);
    });

    testWidgets(
      'signed in: a protected route is directly reachable, no redirect',
      (tester) async {
        final router = await _pumpRouter(tester, sessionValue: _fakeUser);

        router.goNamed(RouteNames.businessConsole);
        await tester.pumpAndSettle();

        expect(_currentPath(router), RouteNames.businessConsolePath);
      },
    );

    testWidgets(
      'signed in: a parameterized protected route is directly reachable',
      (tester) async {
        final router = await _pumpRouter(tester, sessionValue: _fakeUser);

        router.goNamed(
          RouteNames.businessProfile,
          pathParameters: {RouteNames.idParam: '42'},
        );
        await tester.pumpAndSettle();

        expect(_currentPath(router), '/business/42');
      },
    );
  });
}
