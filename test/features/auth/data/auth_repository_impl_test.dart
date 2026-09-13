import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/core/storage/secure_token_storage.dart';
import 'package:social_commerce_app/features/auth/data/auth_repository_impl.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';

/// Part P-020 scope. These exercise [AuthRepositoryImpl] against a
/// *mocked* Dio adapter shaped exactly like the confirmed real backend
/// contract (see AuthRepository's module docstring for how each field
/// name/shape was confirmed) — not the real running backend.
///
/// This part's spec also calls for an integration test exercising the
/// full register→login→refresh→logout cycle against the real backend
/// (`docker compose up`) — that requires a live Postgres/Django stack
/// this sandbox doesn't have, so it isn't included here. See
/// PROJECT_PROGRESS.md's P-020 entry for the exact command to run it on
/// the real machine (`D:\Cavallo\scd-backend`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio dio;
  late DioAdapter adapter;
  late SecureTokenStorage tokenStorage;
  late AuthRepositoryImpl repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});

    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    // Real ErrorInterceptor attached, exactly like dioClientProvider's
    // chain, so failure-path assertions below see genuine ApiFailure
    // variants rather than raw DioExceptions.
    dio.interceptors.add(ErrorInterceptor());

    tokenStorage = SecureTokenStorage();
    repository = AuthRepositoryImpl(dio: dio, tokenStorage: tokenStorage);
  });

  group('register', () {
    test('maps the response to a User and saves no tokens', () async {
      adapter.onPost(
        '/api/v1/auth/register/',
        (server) => server.reply(201, {
          'id': 3,
          'email': 'trader@example.com',
          'account_type': 'business',
        }),
        data: {
          'email': 'trader@example.com',
          'password': 'S3curePass!',
          'password_confirm': 'S3curePass!',
          'account_type': 'business',
        },
      );

      final user = await repository.register(
        email: 'trader@example.com',
        password: 'S3curePass!',
        passwordConfirm: 'S3curePass!',
        accountType: AccountType.business,
      );

      expect(user, const User(id: 3, email: 'trader@example.com', accountType: AccountType.business));
      // No tokens issued by this endpoint — see AuthRepository's module
      // docstring — so nothing should have been persisted.
      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
    });

    test('a duplicate-email 400 surfaces as ValidationFailure', () async {
      adapter.onPost(
        '/api/v1/auth/register/',
        (server) => server.reply(400, {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Invalid input',
            'fields': {
              'email': ['A user with this email already exists.'],
            },
          },
        }),
        // http_mock_adapter's default matcher checks the request body too
        // when `data` is supplied to a route registration — omitting it
        // here (as the first draft of this test did) makes the matcher
        // fail to find this route at all once a real body is sent,
        // which surfaces as a bodyless DioException the ErrorInterceptor
        // maps to NetworkFailure instead of ever reaching this stub.
        data: {
          'email': 'taken@example.com',
          'password': 'S3curePass!',
          'password_confirm': 'S3curePass!',
          'account_type': 'customer',
        },
      );

      try {
        await repository.register(
          email: 'taken@example.com',
          password: 'S3curePass!',
          passwordConfirm: 'S3curePass!',
          accountType: AccountType.customer,
        );
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ValidationFailure>());
        expect(
          (e.error as ValidationFailure).fields['email'],
          ['A user with this email already exists.'],
        );
      }
    });
  });

  group('login', () {
    test('saves the returned access/refresh pair', () async {
      adapter.onPost(
        '/api/v1/auth/login/',
        (server) => server.reply(200, {
          'access': 'access-token-value',
          'refresh': 'refresh-token-value',
        }),
        data: {'email': 'trader@example.com', 'password': 'S3curePass!'},
      );

      await repository.login(email: 'trader@example.com', password: 'S3curePass!');

      expect(await tokenStorage.getAccessToken(), 'access-token-value');
      expect(await tokenStorage.getRefreshToken(), 'refresh-token-value');
    });

    test('invalid credentials 401 surface as AuthFailure and save nothing', () async {
      adapter.onPost(
        '/api/v1/auth/login/',
        (server) => server.reply(401, {
          'error': {
            'code': 'AUTHENTICATION_FAILED',
            'message': 'Unable to log in with the provided credentials.',
          },
        }),
        // See the matching comment on the register-failure test above —
        // the body matcher must mirror exactly what login() sends.
        data: {'email': 'trader@example.com', 'password': 'wrong'},
      );

      try {
        await repository.login(email: 'trader@example.com', password: 'wrong');
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<AuthFailure>());
      }
      expect(await tokenStorage.getAccessToken(), isNull);
    });
  });

  group('refresh', () {
    test('throws StateError with no network call when nothing is stored', () async {
      expect(() => repository.refresh(), throwsA(isA<StateError>()));
    });

    test('persists the rotated access/refresh pair', () async {
      await tokenStorage.saveTokens(access: 'old-access', refresh: 'old-refresh');

      adapter.onPost(
        '/api/v1/auth/refresh/',
        (server) => server.reply(200, {
          'access': 'new-access-token',
          'refresh': 'new-refresh-token',
        }),
        data: {'refresh': 'old-refresh'},
      );

      await repository.refresh();

      expect(await tokenStorage.getAccessToken(), 'new-access-token');
      expect(await tokenStorage.getRefreshToken(), 'new-refresh-token');
    });
  });

  group('logout', () {
    test('no-ops with no network call when nothing is stored', () async {
      await repository.logout();

      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
    });

    test('clears local tokens on a successful backend call', () async {
      await tokenStorage.saveTokens(access: 'access-token-value', refresh: 'refresh-token-value');

      adapter.onPost(
        '/api/v1/auth/logout/',
        (server) => server.reply(200, {'detail': 'Successfully logged out.'}),
        data: {'refresh': 'refresh-token-value'},
      );

      await repository.logout();

      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
    });

    test(
      'still clears local tokens AND rethrows when the backend call fails '
      '(server-side blacklisting still matters even though local cleanup '
      'always happens)',
      () async {
        await tokenStorage.saveTokens(access: 'access-token-value', refresh: 'refresh-token-value');

        adapter.onPost(
          '/api/v1/auth/logout/',
          (server) => server.reply(500, {
            'error': {'code': 'SERVER_ERROR', 'message': 'Something broke'},
          }),
          // See the matching comment on the register-failure test above —
          // the body matcher must mirror exactly what logout() sends.
          data: {'refresh': 'refresh-token-value'},
        );

        try {
          await repository.logout();
          fail('Expected a DioException to be thrown');
        } on DioException catch (e) {
          expect(e.error, isA<ServerFailure>());
        }

        expect(await tokenStorage.getAccessToken(), isNull);
        expect(await tokenStorage.getRefreshToken(), isNull);
      },
    );
  });
}