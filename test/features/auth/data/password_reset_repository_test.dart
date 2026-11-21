import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/core/storage/secure_token_storage.dart';
import 'package:social_commerce_app/features/auth/data/auth_repository_impl.dart';

/// The three password-reset methods of [AuthRepositoryImpl], against a mocked
/// Dio adapter shaped like the real backend (`accounts/views.py`,
/// `accounts/serializers.py`, `core/exceptions.py` on `develop`):
///
/// * request -> `202 {"detail": ...}` (not 200)
/// * verify  -> `200 {"reset_token": ...}`
/// * confirm -> `200 {"detail": "Password has been reset."}`
/// * every unified failure -> `400` with code `ERROR` and empty `fields`
///   (`PasswordResetInvalid` has no entry in the backend's code map)
/// * weak password -> `400 VALIDATION_ERROR` with `fields.new_password`
/// * throttled -> `429 THROTTLED` (+ `Retry-After` header)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const requestPath = '/api/v1/auth/password-reset/request/';
  const verifyPath = '/api/v1/auth/password-reset/verify/';
  const confirmPath = '/api/v1/auth/password-reset/confirm/';

  late Dio dio;
  late DioAdapter adapter;
  late SecureTokenStorage tokenStorage;
  late AuthRepositoryImpl repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());
    tokenStorage = SecureTokenStorage();
    repository = AuthRepositoryImpl(dio: dio, tokenStorage: tokenStorage);
  });

  const unified400 = <String, dynamic>{
    'error': {
      'code': 'ERROR',
      'message': 'Invalid or expired verification data.',
      'fields': <String, dynamic>{},
    },
  };

  Future<ApiFailure> failureOf(Future<Object?> Function() call) async {
    try {
      await call();
    } on DioException catch (e) {
      return e.error as ApiFailure;
    }
    fail('Expected a DioException to be thrown');
  }

  group('requestPasswordReset', () {
    test('posts only the email and accepts the 202 answer', () async {
      adapter.onPost(
        requestPath,
        (server) => server.reply(202, {'detail': 'If the account exists...'}),
        data: {'email': 'user@example.com'},
      );

      await repository.requestPasswordReset(email: 'user@example.com');
    });

    test('a malformed email is a ValidationFailure with its field', () async {
      adapter.onPost(
        requestPath,
        (server) => server.reply(400, {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Enter a valid email address.',
            'fields': {
              'email': ['Enter a valid email address.'],
            },
          },
        }),
        data: {'email': 'nope'},
      );

      final f = await failureOf(
        () => repository.requestPasswordReset(email: 'nope'),
      );

      expect(f, isA<ValidationFailure>());
      expect(f.code, 'VALIDATION_ERROR');
      expect((f as ValidationFailure).fields['email'], [
        'Enter a valid email address.',
      ]);
    });

    test('429 is a throttled UnknownFailure carrying Retry-After', () async {
      adapter.onPost(
        requestPath,
        (server) => server.reply(
          429,
          {
            'error': {
              'code': 'THROTTLED',
              'message': 'Request was throttled.',
              'fields': <String, dynamic>{},
            },
          },
          headers: {
            'content-type': ['application/json'],
            'retry-after': ['30'],
          },
        ),
        data: {'email': 'user@example.com'},
      );

      final f = await failureOf(
        () => repository.requestPasswordReset(email: 'user@example.com'),
      );

      expect(f, isA<UnknownFailure>());
      expect(f.code, 'THROTTLED');
      expect((f as UnknownFailure).retryAfter, const Duration(seconds: 30));
    });

    test('a network failure is a NetworkFailure', () async {
      adapter.onPost(
        requestPath,
        (server) => server.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: requestPath),
            reason: 'offline',
          ),
        ),
        data: {'email': 'user@example.com'},
      );

      final f = await failureOf(
        () => repository.requestPasswordReset(email: 'user@example.com'),
      );

      expect(f, isA<NetworkFailure>());
      expect(f.code, ApiErrorCodes.networkError);
    });
  });

  group('verifyPasswordResetOtp', () {
    test('returns the reset token string', () async {
      adapter.onPost(
        verifyPath,
        (server) => server.reply(200, {'reset_token': 'opaque-reset-token'}),
        data: {'email': 'user@example.com', 'otp': '123456'},
      );

      final token = await repository.verifyPasswordResetOtp(
        email: 'user@example.com',
        otp: '123456',
      );

      expect(token, 'opaque-reset-token');
    });

    test('the unified 400 is a ValidationFailure with no fields', () async {
      adapter.onPost(
        verifyPath,
        (server) => server.reply(400, unified400),
        data: {'email': 'user@example.com', 'otp': '000000'},
      );

      final f = await failureOf(
        () => repository.verifyPasswordResetOtp(
          email: 'user@example.com',
          otp: '000000',
        ),
      );

      expect(f, isA<ValidationFailure>());
      expect(f.code, 'ERROR');
      expect((f as ValidationFailure).fields, isEmpty);
    });

    test('429 is the throttled UnknownFailure', () async {
      adapter.onPost(
        verifyPath,
        (server) => server.reply(429, {
          'error': {'code': 'THROTTLED', 'message': 'Request was throttled.'},
        }),
        data: {'email': 'user@example.com', 'otp': '123456'},
      );

      final f = await failureOf(
        () => repository.verifyPasswordResetOtp(
          email: 'user@example.com',
          otp: '123456',
        ),
      );

      expect(f, isA<UnknownFailure>());
      expect(f.code, 'THROTTLED');
      expect((f as UnknownFailure).retryAfter, isNull);
    });

    test('a network failure is a NetworkFailure', () async {
      adapter.onPost(
        verifyPath,
        (server) => server.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: verifyPath),
            reason: 'offline',
          ),
        ),
        data: {'email': 'user@example.com', 'otp': '123456'},
      );

      final f = await failureOf(
        () => repository.verifyPasswordResetOtp(
          email: 'user@example.com',
          otp: '123456',
        ),
      );

      expect(f, isA<NetworkFailure>());
    });
  });

  group('confirmPasswordReset', () {
    test(
      'posts email, reset_token and new_password and accepts the 200',
      () async {
        adapter.onPost(
          confirmPath,
          (server) => server.reply(200, {'detail': 'Password has been reset.'}),
          data: {
            'email': 'user@example.com',
            'reset_token': 'opaque-reset-token',
            'new_password': 'Str0ng!Passw0rd',
          },
        );

        await repository.confirmPasswordReset(
          email: 'user@example.com',
          resetToken: 'opaque-reset-token',
          newPassword: 'Str0ng!Passw0rd',
        );
      },
    );

    test(
      'a weak password is a ValidationFailure with fields.new_password',
      () async {
        adapter.onPost(
          confirmPath,
          (server) => server.reply(400, {
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'This password is too common.',
              'fields': {
                'new_password': ['This password is too common.'],
              },
            },
          }),
          data: {
            'email': 'user@example.com',
            'reset_token': 'opaque-reset-token',
            'new_password': '12345678',
          },
        );

        final f = await failureOf(
          () => repository.confirmPasswordReset(
            email: 'user@example.com',
            resetToken: 'opaque-reset-token',
            newPassword: '12345678',
          ),
        );

        expect(f, isA<ValidationFailure>());
        expect(f.code, 'VALIDATION_ERROR');
        expect((f as ValidationFailure).fields['new_password'], [
          'This password is too common.',
        ]);
      },
    );

    test('a wrong or expired token is the unified 400 (no fields)', () async {
      adapter.onPost(
        confirmPath,
        (server) => server.reply(400, unified400),
        data: {
          'email': 'user@example.com',
          'reset_token': 'stale',
          'new_password': 'Str0ng!Passw0rd',
        },
      );

      final f = await failureOf(
        () => repository.confirmPasswordReset(
          email: 'user@example.com',
          resetToken: 'stale',
          newPassword: 'Str0ng!Passw0rd',
        ),
      );

      expect(f, isA<ValidationFailure>());
      expect((f as ValidationFailure).fields, isEmpty);
    });

    test('429 is the throttled UnknownFailure', () async {
      adapter.onPost(
        confirmPath,
        (server) => server.reply(
          429,
          {
            'error': {'code': 'THROTTLED', 'message': 'Request was throttled.'},
          },
          headers: {
            'content-type': ['application/json'],
            'retry-after': ['120'],
          },
        ),
        data: {
          'email': 'user@example.com',
          'reset_token': 'opaque-reset-token',
          'new_password': 'Str0ng!Passw0rd',
        },
      );

      final f = await failureOf(
        () => repository.confirmPasswordReset(
          email: 'user@example.com',
          resetToken: 'opaque-reset-token',
          newPassword: 'Str0ng!Passw0rd',
        ),
      );

      expect(f, isA<UnknownFailure>());
      expect(f.code, 'THROTTLED');
      expect((f as UnknownFailure).retryAfter, const Duration(seconds: 120));
    });

    test('a network failure is a NetworkFailure', () async {
      adapter.onPost(
        confirmPath,
        (server) => server.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: confirmPath),
            reason: 'offline',
          ),
        ),
        data: {
          'email': 'user@example.com',
          'reset_token': 'opaque-reset-token',
          'new_password': 'Str0ng!Passw0rd',
        },
      );

      final f = await failureOf(
        () => repository.confirmPasswordReset(
          email: 'user@example.com',
          resetToken: 'opaque-reset-token',
          newPassword: 'Str0ng!Passw0rd',
        ),
      );

      expect(f, isA<NetworkFailure>());
    });
  });

  test('none of the three calls touches SecureTokenStorage', () async {
    await tokenStorage.saveTokens(access: 'access-1', refresh: 'refresh-1');
    adapter
      ..onPost(
        requestPath,
        (server) => server.reply(202, {'detail': 'ok'}),
        data: {'email': 'user@example.com'},
      )
      ..onPost(
        verifyPath,
        (server) => server.reply(200, {'reset_token': 'opaque-reset-token'}),
        data: {'email': 'user@example.com', 'otp': '123456'},
      )
      ..onPost(
        confirmPath,
        (server) => server.reply(200, {'detail': 'Password has been reset.'}),
        data: {
          'email': 'user@example.com',
          'reset_token': 'opaque-reset-token',
          'new_password': 'Str0ng!Passw0rd',
        },
      );

    await repository.requestPasswordReset(email: 'user@example.com');
    final token = await repository.verifyPasswordResetOtp(
      email: 'user@example.com',
      otp: '123456',
    );
    await repository.confirmPasswordReset(
      email: 'user@example.com',
      resetToken: token,
      newPassword: 'Str0ng!Passw0rd',
    );

    // The pair that was there before is untouched, and the reset token
    // never became a login token.
    expect(await tokenStorage.getAccessToken(), 'access-1');
    expect(await tokenStorage.getRefreshToken(), 'refresh-1');
  });
}
