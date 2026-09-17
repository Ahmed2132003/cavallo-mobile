import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/login_screen.dart';
import 'package:social_commerce_app/features/auth/presentation/register_screen.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_public_screen.dart';
import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// A [SessionNotifier] whose [build] resolves immediately to a fixed
/// value. Duplicated here (rather than imported) from
/// `app_router_redirect_test.dart` because that class is
/// library-private — see this file's own doc note below for why every
/// test in this file needs one now.
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

/// ## Part P-021b update — why every test here now overrides [sessionProvider]
///
/// Before P-021b, this file's `setUp` built [appRouterProvider] from a
/// plain, un-overridden `ProviderContainer()`. That happened to "work"
/// only because `sessionProvider`'s real [SessionNotifier.build] calls
/// `SecureTokenStorage.getAccessToken()`, which talks to a platform
/// channel (iOS Keychain / Android KeyStore) that never replies under
/// plain `flutter test` — so `session.isLoading` stayed `true` forever,
/// and `app_router.dart`'s redirect guard treats "still loading" as "do
/// nothing" (see that file's own comment on that branch). Every test in
/// this file was therefore silently exercising the router with its auth
/// guard permanently disabled, by accident, via a hung `Future` — not a
/// real "signed in" or "signed out" state at all.
///
/// Now that the guard is real (Part P-021b) and this project has an
/// established, deterministic way to fix a session state for a router
/// test (`_FakeSessionNotifier`, first written for
/// `app_router_redirect_test.dart`), relying on the old hang is worse
/// than just fixing it: it's flaky in spirit (breaks the moment
/// `SecureTokenStorage`'s test behavior ever changes) and every failure
/// it causes is confusing to debug. So every test below now explicitly
/// says whether it means "signed in" or "signed out."
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
  // first redirect evaluation runs against it — same pattern as
  // app_router_redirect_test.dart.
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

void main() {
  // ### Removed: 'splash route resolves at the initial location'
  //
  // Splash is deliberately unreachable as a *resolved* route now that
  // the guard is real — it always immediately redirects onward: to
  // `/login` when signed out, to `/home` when signed in (see
  // app_router.dart's redirect callback and its class-level doc on why
  // splash is included in that logic). There is no session state left
  // under which "splash renders and stays" is correct behavior to
  // assert, so keeping this test would mean asserting stale, pre-guard
  // behavior. Both actual outcomes are already covered by
  // app_router_redirect_test.dart's `cold-start splash bounces to
  // /login` and `cold-start splash bounces to /home`.

  // ### Removed: 'tapping the debug button on every placeholder screen
  // forms a closed cycle through all 12 routes back to splash'
  //
  // This test's premise was a single tap-through cycle across all 12
  // routes, independent of auth state — true in P-007 when nothing
  // gated navigation. Part P-021b breaks that premise structurally, not
  // just cosmetically: 2 of those 12 nodes (`login`, `register`) now
  // resolve to *different* destinations depending on whether the
  // session is signed in or signed out, and `login` no longer even has
  // P-007's placeholder debug button (it's Part P-021b's real
  // `LoginScreen`, a login form). There is no single fixed session
  // state under which a 12-node closed cycle through every route is
  // still true, so there's no direct fix — only a rewrite into
  // something that iterates per-route-list with a matching session
  // state, which is exactly what `every protected placeholder route
  // resolves` below (and app_router_redirect_test.dart) already do.
  // Flagging the removal explicitly rather than leaving a test that can
  // never pass under the new, correct guard behavior.

  group('static route table (Part P-007, extended P-021b)', () {
    testWidgets('every protected placeholder route resolves (signed in)', (
      tester,
    ) async {
      final router = await _pumpRouter(tester, sessionValue: _fakeUser);

      // login/register deliberately excluded here: while signed in,
      // the guard bounces both to /home (see the dedicated login/
      // register tests below and app_router_redirect_test.dart) —
      // asserting their placeholder text under this session state
      // would be asserting an unreachable state.
      const protectedSimpleRoutes = <String>[
        RouteNames.home,
        RouteNames.discover,
        RouteNames.search,
        RouteNames.chatList,
        RouteNames.notifications,
        RouteNames.businessConsole,
      ];

      for (final name in protectedSimpleRoutes) {
        router.goNamed(name);
        await tester.pumpAndSettle();
        expect(
          find.text('Route: $name'),
          findsOneWidget,
          reason: 'route "$name" did not resolve',
        );
      }
    });

    testWidgets('login route resolves to the real LoginScreen (signed out)', (
      tester,
    ) async {
      final router = await _pumpRouter(tester, sessionValue: null);

      router.goNamed(RouteNames.login);
      await tester.pumpAndSettle();

      // Part P-021b replaced P-007's placeholder here — asserting the
      // real screen type, not stale 'Route: login' placeholder text.
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets(
      'register route resolves to the real RegisterScreen (signed out)',
      (tester) async {
        final router = await _pumpRouter(tester, sessionValue: null);

        router.goNamed(RouteNames.register);
        await tester.pumpAndSettle();

        // Updated in Part P-021c. This test previously asserted
        // 'Route: register' — correct only while the route still
        // resolved to P-007's placeholder, which P-021b deliberately
        // left untouched (RegisterScreen was out of its scope). P-021c
        // replaced that placeholder with the real registration form, so
        // the placeholder text no longer exists anywhere; asserting it
        // would be asserting pre-P-021c behavior. Mirrors the
        // LoginScreen assertion above: check the real screen type, plus
        // one visible affordance proving the form actually rendered
        // rather than an empty shell.
        expect(find.byType(RegisterScreen), findsOneWidget);
        expect(
          find.widgetWithText(AppButton, 'Create account'),
          findsOneWidget,
        );
      },
    );

    testWidgets('businessProfile route resolves to the real public screen — '
        'non-numeric id shows not-found (signed in)', (tester) async {
      // Part P-029 replaced P-007's placeholder screen for this
      // route. `_fakeUser` here is a Customer (see `_fakeUser`'s own
      // definition above), so only the base auth gate applies — the
      // P-028C1 business-account gate never engages for this
      // session, exactly like every other test in this file.
      //
      // 'sample-business-1' is not a valid id under the real backend
      // route (`<int:pk>/`, `businesses/urls.py`), and
      // BusinessProfilePublicScreen parses the `:id` string itself
      // (see that screen's own docstring) — a non-numeric id
      // resolves to the not-found state without ever calling the
      // repository. This test therefore needs no repository
      // override, unlike a real numeric-id case (covered in
      // test/features/business_profile/presentation/
      // business_profile_public_screen_test.dart, Part P-029's own
      // widget tests).
      final router = await _pumpRouter(tester, sessionValue: _fakeUser);

      router.goNamed(
        RouteNames.businessProfile,
        pathParameters: {RouteNames.idParam: 'sample-business-1'},
      );
      await tester.pumpAndSettle();

      expect(find.byType(BusinessProfilePublicScreen), findsOneWidget);
      expect(
        find.text('Business not found.\nIt may have been removed.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'productDetail route resolves with its :id path parameter (signed in)',
      (tester) async {
        final router = await _pumpRouter(tester, sessionValue: _fakeUser);

        router.goNamed(
          RouteNames.productDetail,
          pathParameters: {RouteNames.idParam: 'sample-product-1'},
        );
        await tester.pumpAndSettle();

        expect(find.text('Route: productDetail'), findsOneWidget);
        expect(find.text('id param: sample-product-1'), findsOneWidget);
      },
    );

    testWidgets(
      'chatThread route resolves with its :id path parameter (signed in)',
      (tester) async {
        final router = await _pumpRouter(tester, sessionValue: _fakeUser);

        router.goNamed(
          RouteNames.chatThread,
          pathParameters: {RouteNames.idParam: 'sample-thread-1'},
        );
        await tester.pumpAndSettle();

        expect(find.text('Route: chatThread'), findsOneWidget);
        expect(find.text('id param: sample-thread-1'), findsOneWidget);
      },
    );
  });
}
