import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/dio_client.dart' show AuthTokenGetter;
import 'package:social_commerce_app/core/storage/secure_token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Resets FlutterSecureStorage onto its in-memory test platform, empty,
    // before every test — this is the mock mechanism the part spec calls
    // for, and it backs every FlutterSecureStorage instance created after
    // this call (no manual MethodChannel wiring needed).
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('SecureTokenStorage', () {
    test(
      'saveTokens then getAccessToken/getRefreshToken return exactly '
      'what was saved',
      () async {
        final storage = SecureTokenStorage();

        await storage.saveTokens(access: 'access-123', refresh: 'refresh-456');

        expect(await storage.getAccessToken(), 'access-123');
        expect(await storage.getRefreshToken(), 'refresh-456');
      },
    );

    test(
      'getAccessToken/getRefreshToken return null before anything is saved',
      () async {
        final storage = SecureTokenStorage();

        expect(await storage.getAccessToken(), isNull);
        expect(await storage.getRefreshToken(), isNull);
      },
    );

    test('clear wipes both tokens', () async {
      final storage = SecureTokenStorage();
      await storage.saveTokens(access: 'a', refresh: 'r');

      await storage.clear();

      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test('clear is a no-op (does not throw) when nothing was ever saved', () async {
      final storage = SecureTokenStorage();

      await expectLater(storage.clear(), completes);
    });

    test('saveTokens overwrites a previously saved pair', () async {
      final storage = SecureTokenStorage();
      await storage.saveTokens(access: 'old-access', refresh: 'old-refresh');

      await storage.saveTokens(access: 'new-access', refresh: 'new-refresh');

      expect(await storage.getAccessToken(), 'new-access');
      expect(await storage.getRefreshToken(), 'new-refresh');
    });

    test(
      'getAccessToken is directly assignable to AuthTokenGetter '
      '(P-004/P-020 signature match, no adapter needed)',
      () {
        final storage = SecureTokenStorage();

        final AuthTokenGetter getToken = storage.getAccessToken;

        expect(getToken, isA<Future<String?> Function()>());
      },
    );
  });

  group('secureTokenStorageProvider', () {
    test('provides a SecureTokenStorage', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(secureTokenStorageProvider),
        isA<SecureTokenStorage>(),
      );
    });

    test('is overridable in a throwaway test container', () async {
      final fakeStorage = SecureTokenStorage();
      await fakeStorage.saveTokens(access: 'fake-a', refresh: 'fake-r');

      final container = ProviderContainer(
        overrides: [secureTokenStorageProvider.overrideWithValue(fakeStorage)],
      );
      addTearDown(container.dispose);

      final storage = container.read(secureTokenStorageProvider);

      expect(identical(storage, fakeStorage), isTrue);
      expect(await storage.getAccessToken(), 'fake-a');
    });
  });
}