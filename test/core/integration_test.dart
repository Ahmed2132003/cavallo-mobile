import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:social_commerce_app/core/config/app_theme.dart';
import 'package:social_commerce_app/core/error_reporting.dart';
import 'package:social_commerce_app/core/network/dio_client.dart';
import 'package:social_commerce_app/core/storage/secure_token_storage.dart';
import 'package:social_commerce_app/routing/app_router.dart';

/// Part P-009 scope: the "do the pieces actually fit together" checkpoint
/// for everything built in P-004 (network) through P-008 (bootstrap).
///
/// Each of P-004–P-008 already has its own isolated test suite (see the
/// sibling files under `test/core/` and `test/routing/`) that passed on
/// its own. This file only adds the three specific cross-cutting checks
/// the part spec calls for — it deliberately does not re-test anything
/// those suites already cover on their own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P-009: DioClient + AuthInterceptor + SecureTokenStorage', () {
    setUp(() {
      // Same reset mechanism P-005's own suite uses — every
      // SecureTokenStorage created after this call is backed by a fresh,
      // empty in-memory secure-storage double.
      FlutterSecureStorage.setMockInitialValues({});
    });

    test(
      'a manually-seeded SecureTokenStorage token round-trips through '
      'dioClientProvider: an outgoing request carries the correct '
      'Authorization header, sourced from real secure storage rather than '
      'a fake getToken function',
      () async {
        final tokenStorage = SecureTokenStorage();
        await tokenStorage.saveTokens(
          access: 'seeded-access-token-p009',
          refresh: 'seeded-refresh-token-p009',
        );

        // This is the exact wiring P-020's real composition root will do —
        // see the "Wiring note for Part P-020" doc comment on
        // SecureTokenStorage. P-009 exercises it early, without waiting
        // for real login to exist, using a manually-seeded token instead.
        final container = ProviderContainer(
          overrides: [
            authTokenGetterProvider.overrideWithValue(
              tokenStorage.getAccessToken,
            ),
          ],
        );
        addTearDown(container.dispose);

        final dio = container.read(dioClientProvider);

        // Swap in a mock HTTP adapter (same package/pattern P-004's own
        // dio_client_test.dart / error_interceptor_test.dart already use)
        // so this test never touches a real network — it only proves the
        // interceptor chain attaches the header correctly.
        final dioAdapter = DioAdapter(dio: dio);
        dio.httpClientAdapter = dioAdapter;

        dioAdapter.onGet(
          '/p009-integration-ping',
          (server) => server.reply(200, {'ok': true}),
        );

        final response = await dio.get('/p009-integration-ping');

        expect(response.statusCode, 200);
        expect(
          response.requestOptions.headers['Authorization'],
          'Bearer seeded-access-token-p009',
          reason:
              'AuthInterceptor should have read the seeded token straight '
              'out of SecureTokenStorage via the overridden '
              'authTokenGetterProvider',
        );
      },
    );

    test(
      'without a seeded token, the same wiring omits the Authorization '
      'header instead of sending "Bearer null"',
      () async {
        final tokenStorage = SecureTokenStorage(); // never saveTokens()

        final container = ProviderContainer(
          overrides: [
            authTokenGetterProvider.overrideWithValue(
              tokenStorage.getAccessToken,
            ),
          ],
        );
        addTearDown(container.dispose);

        final dio = container.read(dioClientProvider);
        final dioAdapter = DioAdapter(dio: dio);
        dio.httpClientAdapter = dioAdapter;

        dioAdapter.onGet(
          '/p009-integration-ping-no-token',
          (server) => server.reply(200, {'ok': true}),
        );

        final response = await dio.get('/p009-integration-ping-no-token');

        expect(
          response.requestOptions.headers.containsKey('Authorization'),
          isFalse,
        );
      },
    );
  });

  group('P-009: AppTheme + AppRouter combined via MaterialApp.router', () {
    testWidgets(
      'renders together without conflict or exception, and the theme '
      'actually reaches the router screens (not just the default '
      'Material look)',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final router = container.read(appRouterProvider);
        expect(router, isA<GoRouter>());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.theme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No exception should have been thrown while building the
        // combined tree.
        expect(tester.takeException(), isNull);

        // Router resolved to its initial route as usual (same assertion
        // P-007's own suite makes) — proves the router half of the tree
        // isn't broken by having a real theme attached this time.
        expect(find.text('Route: splash'), findsOneWidget);

        // Confirm AppTheme's colors actually reached the rendered screen,
        // rather than the tree silently falling back to MaterialApp's own
        // default ThemeData because of some wiring conflict.
        final context = tester.element(find.byType(Scaffold).first);
        final renderedScheme = Theme.of(context).colorScheme;
        expect(renderedScheme.primary, AppTheme.theme.colorScheme.primary);
      },
    );
  });

  group('P-009: error_reporting under a real widget-test error', () {
    testWidgets(
      'reportError does not itself throw when called with a real caught '
      'exception surfaced by a widget build error inside a widget test',
      (tester) async {
        Object? capturedError;
        StackTrace? capturedStack;

        // Temporarily take over FlutterError.onError, the same hook
        // main.dart wires to reportError in P-008 — this lets the test
        // capture a real build-time exception instead of letting the
        // test framework's default handler fail the test outright.
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          capturedError ??= details.exception;
          capturedStack ??= details.stack;
        };
        addTearDown(() => FlutterError.onError = previousOnError);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                throw Exception(
                  'P-009 integration: deliberate widget-build error',
                );
              },
            ),
          ),
        );

        expect(
          capturedError,
          isNotNull,
          reason: 'expected a real build-time error to have been caught',
        );

        expect(
          () => reportError(capturedError!, capturedStack ?? StackTrace.empty),
          returnsNormally,
        );
      },
    );
  });
}