import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/storage/secure_token_storage.dart';
import 'package:social_commerce_app/features/auth/data/auth_repository_impl.dart';
import 'package:social_commerce_app/features/auth/domain/auth_repository.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/profile_hub/data/my_profile_repository.dart';

const User _user = User(
  id: 5,
  email: 'a@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
  displayName: 'Old',
);

class _FakeAuth implements AuthRepository {
  int fetchMeCalls = 0;
  User fetched = _user.withProfile(displayName: 'Fetched', avatarUrl: null);

  @override
  Future<User> fetchMe() async {
    fetchMeCalls++;
    return fetchMeCalls == 1 ? _user : fetched;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMyProfileRepository extends MyProfileRepository {
  _FakeMyProfileRepository() : super(dio: Dio());

  MyProfileUpdate? result;
  Object? error;
  int calls = 0;

  @override
  Future<MyProfileUpdate?> update({
    String? displayName,
    List<int>? avatarBytes,
    String? avatarFilename,
    bool removeAvatar = false,
  }) async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}

Future<ProviderContainer> _signedIn(
  _FakeAuth auth,
  _FakeMyProfileRepository repo,
) async {
  FlutterSecureStorage.setMockInitialValues(<String, String>{});
  final SecureTokenStorage storage = SecureTokenStorage();
  await storage.saveTokens(access: 'a', refresh: 'r');
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      secureTokenStorageProvider.overrideWithValue(storage),
      myProfileRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  await container.read(sessionProvider.future);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses the response directly, with no extra fetchMe', () async {
    final _FakeAuth auth = _FakeAuth();
    final _FakeMyProfileRepository repo =
        _FakeMyProfileRepository()
          ..result = const MyProfileUpdate(
            displayName: 'New',
            avatarUrl: 'https://cdn.example/n.png',
          );
    final ProviderContainer c = await _signedIn(auth, repo);

    await c.read(sessionProvider.notifier).updateMyProfile(displayName: 'New');

    final User? user = c.read(sessionProvider).value;
    expect(user?.displayName, 'New');
    expect(user?.avatarUrl, 'https://cdn.example/n.png');
    expect(auth.fetchMeCalls, 1);
  });

  test('falls back to one fetchMe when the response has no profile', () async {
    final _FakeAuth auth = _FakeAuth();
    final _FakeMyProfileRepository repo = _FakeMyProfileRepository();
    final ProviderContainer c = await _signedIn(auth, repo);

    await c.read(sessionProvider.notifier).updateMyProfile(displayName: 'New');

    expect(c.read(sessionProvider).value?.displayName, 'Fetched');
    expect(auth.fetchMeCalls, 2);
  });

  test('a failure rethrows and leaves the session untouched', () async {
    final _FakeAuth auth = _FakeAuth();
    final _FakeMyProfileRepository repo =
        _FakeMyProfileRepository()..error = Exception('boom');
    final ProviderContainer c = await _signedIn(auth, repo);

    await expectLater(
      () =>
          c.read(sessionProvider.notifier).updateMyProfile(displayName: 'New'),
      throwsA(isA<Exception>()),
    );

    expect(c.read(sessionProvider).value, _user);
  });
}
