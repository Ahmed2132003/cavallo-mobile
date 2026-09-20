import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_public_repository.dart';
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

/// Part P-029 addition: a hand-rolled fake for
/// [BusinessProfilePublicRepository], matching this project's established
/// convention of hand-rolled fakes over mockito/mocktail (see e.g.
/// `business_profile_provider_test.dart`'s `FakeBusinessProfileRepository`).
///
/// ### Why this file needs one now
///
/// Before Part P-029, `RouteNames.businessProfile` (`/business/:id`)
/// resolved to P-007's placeholder screen — a bare `Scaffold` with no
/// network calls. This file's "a parameterized protected route is
/// directly reachable" test only ever asserted the resolved *path*
/// (`_currentPath(router)`), never the screen's content, so it never
/// needed to know or care what the screen rendered.
///
/// Part P-029 replaced that placeholder with the real
/// `BusinessProfilePublicScreen`, which watches
/// `businessProfilePublicProvider(id)` the moment it builds — and that
/// provider calls through `businessProfilePublicRepositoryProvider` to
/// the real [Dio] client by default. Without overriding it, this test
/// silently started firing a real `GET /api/v1/businesses/42/` against
/// whatever backend happens to be reachable at `localhost:8095` during
/// `flutter test` — non-deterministic (depends on that server being up,
/// reachable, and returning something), and not something this test's
/// own assertion (the router *path*, not the screen's content) has any
/// business depending on. Overriding the repository with this fake
/// removes the network dependency entirely; Part P-029's own widget
/// tests (`business_profile_public_screen_test.dart`) are the ones that
/// actually exercise real found/not-found/error content states.
///
/// Always resolves to `null` ("business not found") rather than throwing
/// or hanging — the simplest fixed outcome that lets
/// `BusinessProfilePublicScreen` settle into a definite state
/// (`AsyncData(null)`) without any external dependency, which is all
/// this file's path-only assertion needs.
class _FakeBusinessProfilePublicRepository
    implements BusinessProfilePublicRepository {
  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async => null;
}

const _fakeUser = User(
  id: 1,
  email: 'test@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

/// Pumps a real [GoRouter] (from [appRouterProvider]) wrapped in
/// [MaterialApp.router], with [sessionProvider] overridden to resolve
/// immediately to [sessionValue]. Returns the [GoRouter] so tests can
/// drive further navigation and inspect the resulting location.
///
/// [businessProfilePublicRepositoryProvider] is overridden unconditionally
/// here — not only for the one test that visits `/business/:id` — since
/// doing so has no effect on any other test in this file (nothing else
/// ever builds `businessProfilePublicProvider`) and keeps this function's
/// signature and every call site unchanged, matching the "add the
/// override where the risk is, don't special-case individual tests"
/// approach already used for `sessionProvider` itself.
Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  required User? sessionValue,
}) async {
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSessionNotifier(sessionValue)),
      businessProfilePublicRepositoryProvider.overrideWithValue(
        _FakeBusinessProfilePublicRepository(),
      ),
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