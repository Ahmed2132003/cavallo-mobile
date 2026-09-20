import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/storage/secure_token_storage.dart';
import 'package:social_commerce_app/features/auth/data/auth_repository_impl.dart';
import 'package:social_commerce_app/features/auth/domain/auth_repository.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';

/// Hand-rolled test double for [AuthRepository] — this project doesn't use
/// mockito/mocktail anywhere (confirmed by searching PROJECT_PROGRESS.md);
/// every prior part's tests either hit a real Dio adapter
/// (`http_mock_adapter`) or hand-roll a fake, so this follows the same
/// convention rather than introducing a new mocking dependency.
class FakeAuthRepository implements AuthRepository {
  bool loginShouldThrow = false;
  bool logoutShouldThrow = false;

  String? lastLoginEmail;
  String? lastLoginPassword;
  int logoutCallCount = 0;
  int registerCallCount = 0;
  Map<String, Object?>? lastRegisterArgs;

  /// When non-null, [fetchMe] throws this instead of returning
  /// [fetchMeResult]. Tests use a real [DioException] with `.error` set
  /// to the specific [ApiFailure] subtype they want to exercise, since
  /// that's exactly the shape `SessionNotifier` pattern-matches on.
  Object? fetchMeError;
  int fetchMeCallCount = 0;

  /// The real user [fetchMe] returns on success — deliberately NOT the
  /// old placeholder's `id: -1`/`accountType: customer`, so any test
  /// asserting on this value is asserting on genuine `fetchMe()` data,
  /// not a fabricated one.
  User fetchMeResult = const User(
    id: 7,
    email: 'fetched@example.com',
    accountType: AccountType.business,
    isModerator: false,
    isStaff: false,
  );

  final User registerResult = const User(
    id: 42,
    email: 'registered@example.com',
    accountType: AccountType.business,
    isModerator: false,
    isStaff: false,
  );

  @override
  Future<User> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required AccountType accountType,
  }) async {
    registerCallCount++;
    lastRegisterArgs = {
      'email': email,
      'password': password,
      'passwordConfirm': passwordConfirm,
      'accountType': accountType,
    };
    return registerResult;
  }

  @override
  Future<void> login({required String email, required String password}) async {
    lastLoginEmail = email;
    lastLoginPassword = password;
    if (loginShouldThrow) {
      throw Exception('fake login failure');
    }
  }

  @override
  Future<void> refresh() async {
    // Not exercised by SessionNotifier in this part — P-022's scope.
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
    if (logoutShouldThrow) {
      throw Exception('fake logout failure');
    }
  }

  @override
  Future<User> fetchMe() async {
    fetchMeCallCount++;
    if (fetchMeError != null) {
      throw fetchMeError!;
    }
    return fetchMeResult;
  }
}

/// Builds a [DioException] shaped exactly like what `ErrorInterceptor`
/// (Part P-004) attaches to `.error` — the same shape `SessionNotifier`
/// pattern-matches on in `_restoreSession`.
DioException _dioFailure(ApiFailure failure) {
  return DioException(
    requestOptions: RequestOptions(path: '/api/v1/auth/me/'),
    error: failure,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionNotifier.build (restoreSession)', () {
    test(
      'resolves to null (unauthenticated) when no access token is stored, '
      'and never calls fetchMe',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final fakeAuth = FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
        );
        addTearDown(container.dispose);

        final result = await container.read(sessionProvider.future);

        expect(result, isNull);
        expect(fakeAuth.fetchMeCallCount, 0);
      },
    );

    test(
      'resolves to the real User from fetchMe() when an access token is '
      'already stored',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final tokenStorage = SecureTokenStorage();
        await tokenStorage.saveTokens(
          access: 'seeded-access-token',
          refresh: 'seeded-refresh-token',
        );
        final fakeAuth = FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            secureTokenStorageProvider.overrideWithValue(tokenStorage),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(sessionProvider.future);

        expect(result, fakeAuth.fetchMeResult);
        expect(result!.accountType, AccountType.business);
        expect(fakeAuth.fetchMeCallCount, 1);
      },
    );

    test(
      'resolves to null and clears the stored token when fetchMe fails '
      'with AuthFailure (expired/invalid token)',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final tokenStorage = SecureTokenStorage();
        await tokenStorage.saveTokens(access: 'stale-access', refresh: 'r');
        final fakeAuth = FakeAuthRepository()
          ..fetchMeError = _dioFailure(
            const AuthFailure(message: 'Unauthorized'),
          );
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            secureTokenStorageProvider.overrideWithValue(tokenStorage),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(sessionProvider.future);

        expect(result, isNull);
        expect(await tokenStorage.getAccessToken(), isNull);
      },
    );

    test(
      'surfaces as AsyncError (does not silently sign out) when fetchMe '
      'fails with a non-auth failure',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final tokenStorage = SecureTokenStorage();
        await tokenStorage.saveTokens(access: 'a', refresh: 'r');
        final fakeAuth = FakeAuthRepository()
          ..fetchMeError = _dioFailure(
            const ServerFailure(message: 'boom'),
          );
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            secureTokenStorageProvider.overrideWithValue(tokenStorage),
          ],
          // Riverpod 3.x automatically retries a provider whose build()
          // throws, with a real (non-mocked) exponential backoff of up
          // to 6.4s per attempt — see
          // https://riverpod.dev/docs/concepts2/retry. That retried
          // `_restoreSession()` was the actual cause of this test's 30s
          // timeout, not the assertion style. Disabling retry here
          // matches Riverpod's own documented recommendation for
          // asserting error behavior in unit tests.
          retry: (retryCount, error) => null,
        );

        // `sessionProvider.future` here is the initial-build future (the
        // very first read of this provider on this container). Both the
        // closure form (`() => container.read(...)`) and passing the
        // Future directly to `expectLater(..., throwsA(...))` were
        // observed to leave this specific rejection unobserved by the
        // matcher — the test hung until the 30s timeout and only then
        // surfaced a Riverpod dispose-during-loading StateError instead
        // of the real DioException. A plain `await` inside `try/catch`
        // sidesteps that matcher/AsyncNotifierProvider interaction
        // entirely and matches the directly-awaited pattern the two
        // tests above already use successfully.
        Object? caughtError;
        try {
          await container.read(sessionProvider.future);
          fail('Expected sessionProvider.future to throw a DioException.');
        } catch (error) {
          caughtError = error;
        }

        expect(caughtError, isA<DioException>());
        expect(container.read(sessionProvider).hasError, isTrue);
        // The stored token must NOT have been cleared — this was not a
        // confirmed-invalid-token case, just a transient failure.
        expect(await tokenStorage.getAccessToken(), 'a');
      },
    );
  });

  group('SessionNotifier.login', () {
    test(
      'transitions state to the real User from fetchMe() on success',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final fakeAuth = FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
        );
        addTearDown(container.dispose);
        await container.read(sessionProvider.future); // let build() settle

        await container
            .read(sessionProvider.notifier)
            .login(email: 'user@example.com', password: 'correct-password');

        final state = container.read(sessionProvider);
        expect(state.value, fakeAuth.fetchMeResult);
        expect(fakeAuth.lastLoginEmail, 'user@example.com');
        expect(fakeAuth.lastLoginPassword, 'correct-password');
        expect(fakeAuth.fetchMeCallCount, 1);
      },
    );

    test('transitions state to AsyncError and rethrows when login() itself '
        'fails', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final fakeAuth = FakeAuthRepository()..loginShouldThrow = true;
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
      );
      addTearDown(container.dispose);
      await container.read(sessionProvider.future);

      await expectLater(
        () => container
            .read(sessionProvider.notifier)
            .login(email: 'user@example.com', password: 'wrong-password'),
        throwsA(isA<Exception>()),
      );

      expect(container.read(sessionProvider).hasError, isTrue);
      // login() itself failed, so fetchMe() should never have been called.
      expect(fakeAuth.fetchMeCallCount, 0);
    });

    test('transitions state to AsyncError and rethrows when login() '
        'succeeds but the follow-up fetchMe() call fails', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final fakeAuth = FakeAuthRepository()
        ..fetchMeError = _dioFailure(const ServerFailure(message: 'boom'));
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
      );
      addTearDown(container.dispose);
      await container.read(sessionProvider.future);

      await expectLater(
        () => container
            .read(sessionProvider.notifier)
            .login(email: 'user@example.com', password: 'correct-password'),
        throwsA(isA<DioException>()),
      );

      expect(container.read(sessionProvider).hasError, isTrue);
    });
  });

  group('SessionNotifier.register', () {
    test('returns the AuthRepository-provided User and leaves session state '
        'untouched (register issues no tokens)', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
      );
      addTearDown(container.dispose);
      await container.read(sessionProvider.future); // resolves to null

      final result = await container
          .read(sessionProvider.notifier)
          .register(
            email: 'new@example.com',
            password: 'password123',
            passwordConfirm: 'password123',
            accountType: AccountType.business,
          );

      expect(result, fakeAuth.registerResult);
      expect(fakeAuth.registerCallCount, 1);
      expect(fakeAuth.lastRegisterArgs?['email'], 'new@example.com');
      expect(fakeAuth.lastRegisterArgs?['accountType'], AccountType.business);
      // The whole point being verified: register() must NOT flip the
      // session to authenticated, since no tokens were ever issued.
      expect(container.read(sessionProvider).value, isNull);
      expect(fakeAuth.fetchMeCallCount, 0);
    });
  });

  group('SessionNotifier.logout', () {
    test('transitions state to unauthenticated on success', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final tokenStorage = SecureTokenStorage();
      await tokenStorage.saveTokens(access: 'a', refresh: 'r');
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          secureTokenStorageProvider.overrideWithValue(tokenStorage),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionProvider.future); // resolves authenticated

      await container.read(sessionProvider.notifier).logout();

      expect(container.read(sessionProvider).value, isNull);
      expect(fakeAuth.logoutCallCount, 1);
    });

    test('still transitions state to unauthenticated, and rethrows, on backend '
        'failure', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final fakeAuth = FakeAuthRepository()..logoutShouldThrow = true;
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
      );
      addTearDown(container.dispose);
      await container.read(sessionProvider.future);

      await expectLater(
        () => container.read(sessionProvider.notifier).logout(),
        throwsA(isA<Exception>()),
      );

      expect(container.read(sessionProvider).value, isNull);
    });
  });

  group('SessionNotifier.invalidateSession (Part P-022B)', () {
    test(
      'synchronously resets state to unauthenticated (null), without '
      'calling AuthRepository at all',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final tokenStorage = SecureTokenStorage();
        await tokenStorage.saveTokens(access: 'a', refresh: 'r');
        final fakeAuth = FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            secureTokenStorageProvider.overrideWithValue(tokenStorage),
          ],
        );
        addTearDown(container.dispose);
        // Resolve the cold-start restore first, landing authenticated
        // (a token is stored) — this is the state a real failed-refresh
        // scenario would be invalidating away from.
        await container.read(sessionProvider.future);
        expect(container.read(sessionProvider).value, isNotNull);

        container.read(sessionProvider.notifier).invalidateSession();

        expect(container.read(sessionProvider).value, isNull);
        // Confirms this method is a pure local state reset, not a wrapper
        // around AuthRepository.logout() (which would have incremented
        // this counter).
        expect(fakeAuth.logoutCallCount, 0);
      },
    );
  });
}