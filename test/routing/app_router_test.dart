import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/login_screen.dart';
import 'package:social_commerce_app/features/auth/presentation/register_screen.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_public_screen.dart';
import 'package:social_commerce_app/features/categories/data/category_repository_impl.dart';
import 'package:social_commerce_app/features/discover/presentation/discover_screen.dart';
import 'package:social_commerce_app/features/feed/presentation/home_feed_screen.dart';
import 'package:social_commerce_app/features/categories/domain/category_entity.dart';
import 'package:social_commerce_app/features/categories/domain/category_repository.dart';
import 'package:social_commerce_app/features/products/data/product_repository_impl.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_repository.dart';
import 'package:social_commerce_app/features/products/presentation/product_detail_screen.dart';
import 'package:social_commerce_app/features/products/presentation/product_form_screen.dart';
import 'package:social_commerce_app/features/products/presentation/product_list_screen.dart';
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
  isModerator: false,
  isStaff: false,
);

/// Hand-rolled test double for [ProductRepository] — Part P-033's
/// `productList`/`productForm` routes both watch `ownProductsProvider`
/// on build, which would otherwise hit the real network the instant
/// either route resolves in a test (no `flutter test` environment ever
/// has real backend connectivity). Scoped to exactly what rendering
/// (not submitting) needs: an immediately-resolving, empty
/// `fetchOwnProducts()`.
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
  }) => throw UnimplementedError('Not exercised by app_router_test.dart');

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
  }) => throw UnimplementedError('Not exercised by app_router_test.dart');

  @override
  Future<void> deleteProduct(int productId) async {}
}

/// Hand-rolled test double for [CategoryRepository] — `ProductFormScreen`
/// watches `categoryTreeProvider` on build for the same reason above.
class _FakeCategoryRepository implements CategoryRepository {
  @override
  Future<List<CategoryNode>> fetchCategoryTree({
    bool forceRefresh = false,
  }) async => const [];
}

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
///
/// ### Part P-033 addition — [extraOverrides]
///
/// Purely additive: every pre-existing call site (none of which passes
/// this parameter) behaves exactly as before, since it defaults to an
/// empty list. Added only so the two new `productList`/`productForm`
/// tests below can override `productRepositoryProvider`/
/// `categoryRepositoryProvider` without duplicating this entire helper.
/// Typed `List<dynamic>`, not `List<Override>` — see this parameter's
/// own inline comment for why.
Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  required User? sessionValue,
  // `dynamic`, not `Override`: `Override` isn't a name either
  // `flutter_riverpod` or `riverpod` re-exports publicly under this
  // project's pinned version (confirmed on the real machine — both
  // attempts failed with "doesn't export a member with the shown
  // name"). Spreading a `List<dynamic>` into the `overrides:` list
  // literal below still type-checks fine: the literal's element type
  // is inferred as `Override` from `ProviderContainer`'s own parameter
  // type, and a `dynamic`-typed spread is allowed into it (an implicit,
  // runtime-checked cast) — this avoids needing the type's name at all,
  // rather than hunting for whichever internal path actually exports it.
  List<dynamic> extraOverrides = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSessionNotifier(sessionValue)),
      ...extraOverrides,
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
      //
      // home deliberately excluded here too: Part P-061 replaced
      // P-007's placeholder for this route with the real
      // `HomeFeedScreen`, so the old 'Route: home' assertion no
      // longer exists anywhere — see the dedicated P-061 test below,
      // same pattern as the businessProfile (P-029) and productDetail
      // (P-034) placeholder replacements further down this file.
      //
      // discover deliberately excluded here too: Part P-062 replaced
      // P-007's placeholder for this route with the real
      // `DiscoverScreen`, so the old 'Route: discover' assertion no
      // longer exists anywhere — see the dedicated P-062 test below,
      // same pattern as home (P-061) above.
      const protectedSimpleRoutes = <String>[
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

    testWidgets(
      'Part P-061: home route resolves to the real HomeFeedScreen '
      '(signed in)',
      (tester) async {
        // Part P-061 replaced P-007's placeholder for this route, so
        // the old 'Route: home' assertion (still used for the other
        // routes in `protectedSimpleRoutes` above) no longer exists
        // anywhere for `home`. No `feedRepositoryProvider` override is
        // used here — same approach as `moderation_router_gate_test
        // .dart`/`business_profile_router_gate_test.dart`'s own
        // `find.byType(HomeFeedScreen)` assertions: the screen resolves
        // (loading → real or failed network fetch → error state) either
        // way, and this test only cares that the correct widget type is
        // what /home now builds, not that its data call succeeds.
        final router = await _pumpRouter(tester, sessionValue: _fakeUser);

        router.goNamed(RouteNames.home);
        await tester.pumpAndSettle();

        expect(find.byType(HomeFeedScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Part P-062: discover route resolves to the real DiscoverScreen '
      '(signed in)',
      (tester) async {
        // Part P-062 replaced P-007's placeholder for this route, so
        // the old 'Route: discover' assertion (still used for the
        // other routes in `protectedSimpleRoutes` above) no longer
        // exists anywhere for `discover`. No repository override is
        // used here — same approach as the P-061 `HomeFeedScreen`
        // test immediately above: the screen resolves (loading →
        // real or failed network fetch → error state) either way,
        // and this test only cares that the correct widget type is
        // what /discover now builds, not that its data calls succeed.
        final router = await _pumpRouter(tester, sessionValue: _fakeUser);

        router.goNamed(RouteNames.discover);
        await tester.pumpAndSettle();

        expect(find.byType(DiscoverScreen), findsOneWidget);
      },
    );

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

    testWidgets('Part P-034: productDetail route resolves to the real '
        'ProductDetailScreen — non-numeric id shows not-found (signed in)', (
      tester,
    ) async {
      // Part P-034 replaced P-007's placeholder for this route, so the
      // old 'Route: productDetail' assertion no longer exists anywhere.
      // Same approach as the businessProfile test above (Part P-029):
      // ProductDetailScreen parses the `:id` string itself, and a
      // non-numeric id resolves to not-found without ever calling the
      // repository — so no repository override is needed here. Numeric
      // ids, loading/error states and the price-framing copy are covered
      // by this part's own screen widget tests.
      final router = await _pumpRouter(tester, sessionValue: _fakeUser);

      router.goNamed(
        RouteNames.productDetail,
        pathParameters: {RouteNames.idParam: 'sample-product-1'},
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductDetailScreen), findsOneWidget);
      expect(
        find.text('Product not found.\nIt may have been removed.'),
        findsOneWidget,
      );
    });
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

    testWidgets(
      'Part P-033: productList route resolves to the real ProductListScreen '
      '(signed in)',
      (tester) async {
        final router = await _pumpRouter(
          tester,
          sessionValue: _fakeUser,
          extraOverrides: [
            productRepositoryProvider.overrideWithValue(
              _FakeProductRepository(),
            ),
          ],
        );

        router.goNamed(RouteNames.productList);
        await tester.pumpAndSettle();

        expect(find.byType(ProductListScreen), findsOneWidget);
        expect(find.text('My Products'), findsOneWidget);
      },
    );

    testWidgets(
      'Part P-033: productForm route resolves to ProductFormScreen in '
      'create mode when no extra is passed (signed in)',
      (tester) async {
        final router = await _pumpRouter(
          tester,
          sessionValue: _fakeUser,
          extraOverrides: [
            productRepositoryProvider.overrideWithValue(
              _FakeProductRepository(),
            ),
            categoryRepositoryProvider.overrideWith(
              (ref) async => _FakeCategoryRepository(),
            ),
          ],
        );

        router.goNamed(RouteNames.productForm);
        await tester.pumpAndSettle();

        expect(find.byType(ProductFormScreen), findsOneWidget);
        // 'Create product' appears twice on screen by design in create
        // mode — once as the AppBar title, once as the submit button's
        // own label (see ProductFormScreen, STEP 9: the AppBar title is
        // `widget.isEditing ? 'Edit product' : 'Create product'`, and
        // the submit AppButton's label is the same ternary). A bare
        // `find.text('Create product')` is therefore ambiguous between
        // the two and always finds 2 widgets, not 1 — this is a router
        // test taking a dependency on the screen's own wording, not a
        // bug in ProductFormScreen itself. Scoped to the AppBar's own
        // title specifically so this assertion is unambiguous.
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Create product'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Part P-033: the business console "My Products" button pushes the '
      'productList route (signed in)',
      (tester) async {
        final router = await _pumpRouter(
          tester,
          sessionValue: _fakeUser,
          extraOverrides: [
            productRepositoryProvider.overrideWithValue(
              _FakeProductRepository(),
            ),
          ],
        );
        router.goNamed(RouteNames.businessConsole);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(AppButton, 'My Products'));
        await tester.pumpAndSettle();

        expect(find.byType(ProductListScreen), findsOneWidget);
      },
    );
  });
}