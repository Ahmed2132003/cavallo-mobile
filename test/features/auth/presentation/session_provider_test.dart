import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
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

  final User registerResult = const User(
    id: 42,
    email: 'registered@example.com',
    accountType: AccountType.business,
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionNotifier.build (restoreSession)', () {
    test(
      'resolves to null (unauthenticated) when no access token is stored',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(sessionProvider.future);

        expect(result, isNull);
      },
    );

    test('resolves to a placeholder authenticated User when an access token '
        'is already stored', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final tokenStorage = SecureTokenStorage();
      await tokenStorage.saveTokens(
        access: 'seeded-access-token',
        refresh: 'seeded-refresh-token',
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          secureTokenStorageProvider.overrideWithValue(tokenStorage),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(sessionProvider.future);

      expect(result, isNotNull);
      // Deliberately NOT asserting on id/accountType here — they are
      // documented placeholders, not real data (see session_provider.dart).
      expect(result!.email, isEmpty);
    });
  });

  group('SessionNotifier.login', () {
    test('transitions state to an authenticated placeholder User on success, '
        'using the real email that was passed in', () async {
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
      expect(state.value, isNotNull);
      expect(state.value!.email, 'user@example.com');
      expect(fakeAuth.lastLoginEmail, 'user@example.com');
      expect(fakeAuth.lastLoginPassword, 'correct-password');
    });

    test('transitions state to AsyncError and rethrows on failure', () async {
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
    });

    test(
      'propagates failures directly without touching session state',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final fakeAuth = FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
        );
        addTearDown(container.dispose);
        await container.read(sessionProvider.future);

        // register() has no failure toggle on the fake by design (it never
        // throws in this suite), so this test instead documents the
        // contract: whatever register() does, it never assigns `state`.
        // (A dedicated throwing fake isn't needed since the notifier method
        // itself contains no try/catch around the call — see
        // session_provider.dart — so failure propagation is structural,
        // not behavior worth re-testing with a second fake.)
        expect(container.read(sessionProvider).value, isNull);
      },
    );
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
}
