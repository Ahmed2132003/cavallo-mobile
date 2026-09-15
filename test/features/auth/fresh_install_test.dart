import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-023 scope: a genuine "fresh install" simulation.
///
/// Every other router test in this project (`app_router_test.dart`,
/// `app_router_redirect_test.dart`) deliberately overrides
/// [sessionProvider] with a `_FakeSessionNotifier` that never touches
/// [SecureTokenStorage] at all — that's the right call for testing the
/// redirect *logic* in isolation, but it means no existing test actually
/// exercises the real cold-start path: real `SessionNotifier.build()` ->
/// real `SecureTokenStorage.getAccessToken()` -> real router `redirect`.
///
/// This file does exactly that, with nothing faked except the platform
/// channel `flutter_secure_storage` itself needs under `flutter test`
/// (`FlutterSecureStorage.setMockInitialValues({})` — the same call
/// `session_provider_test.dart` already uses, confirmed to be the
/// project's established way to give that plugin a real, empty backing
/// store rather than a hung/never-replying channel — see
/// `app_router_test.dart`'s own doc comment on why an *unmocked* real
/// `SessionNotifier` previously hung forever in a router test).
///
/// Empty mock values == no `auth_access_token` key stored == exactly
/// what a real fresh install looks like before any login has ever
/// happened on-device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fresh install (Part P-023)', () {
    test(
      'sessionProvider resolves to null (unauthenticated) with no stored '
      'tokens at all — not just no access token specifically',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final result = await container.read(sessionProvider.future);

        expect(result, isNull);
        expect(container.read(sessionProvider).hasError, isFalse);
      },
    );

    testWidgets(
      'the real router (real SessionNotifier, real SecureTokenStorage, no '
      'overrides) lands on /login on cold start, not splash and not a '
      'protected route',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Let the real SessionNotifier.build() (-> real
        // SecureTokenStorage.getAccessToken() -> resolves null, since the
        // mock store above is empty) settle before the router's first
        // redirect evaluation runs against it — same pattern every other
        // router test in this project already uses, just without the
        // fake notifier override.
        await container.read(sessionProvider.future);

        final router = container.read(appRouterProvider);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        final currentPath =
            router.routerDelegate.currentConfiguration.uri.toString();
        expect(currentPath, RouteNames.loginPath);
      },
    );
  });
}