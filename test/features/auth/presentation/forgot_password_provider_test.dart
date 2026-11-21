import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/auth/data/auth_repository_impl.dart';
import 'package:social_commerce_app/features/auth/domain/auth_repository.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/forgot_password_provider.dart';

/// Hand-rolled fake (this project's convention) with a settable behaviour
/// per call, recording what the notifier sent.
class _FakeAuthRepository implements AuthRepository {
  Future<void> Function()? requestBehavior;
  Future<String> Function()? verifyBehavior;
  Future<void> Function()? confirmBehavior;

  final List<String> requestedEmails = [];
  final List<({String email, String otp})> verifyCalls = [];
  final List<({String email, String token, String password})> confirmCalls = [];

  @override
  Future<void> requestPasswordReset({required String email}) async {
    requestedEmails.add(email);
    await requestBehavior?.call();
  }

  @override
  Future<String> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    verifyCalls.add((email: email, otp: otp));
    return verifyBehavior != null ? verifyBehavior!() : 'reset-token-1';
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    confirmCalls.add((email: email, token: resetToken, password: newPassword));
    await confirmBehavior?.call();
  }

  @override
  Future<User> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required AccountType accountType,
  }) => throw UnimplementedError();

  @override
  Future<void> login({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> refresh() => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<User> fetchMe() => throw UnimplementedError();
}

DioException _dioError(ApiFailure failure) =>
    DioException(requestOptions: RequestOptions(path: '/x'), error: failure);

const _unified400 = ValidationFailure(
  message: 'Invalid or expired verification data.',
  fields: {},
  code: 'ERROR',
);

const _weakPassword = ValidationFailure(
  message: 'This password is too common.',
  fields: {
    'new_password': ['This password is too common.'],
  },
  code: 'VALIDATION_ERROR',
);

class _Harness {
  _Harness() : repo = _FakeAuthRepository() {
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    // autoDispose: keep the flow alive, like a mounted screen would.
    container.listen(forgotPasswordProvider, (previous, next) {});
  }

  final _FakeAuthRepository repo;
  late final ProviderContainer container;

  ForgotPasswordNotifier get notifier =>
      container.read(forgotPasswordProvider.notifier);
  ForgotPasswordState get state => container.read(forgotPasswordProvider);

  void dispose() => container.dispose();
}

void main() {
  test('starts on the email step, blank', () {
    final h = _Harness();
    expect(h.state.step, ForgotPasswordStep.email);
    expect(h.state.email, '');
    expect(h.state.failure, isNull);
    expect(h.state.isSubmitting, isFalse);
    expect(h.state.resendCooldownSeconds, 0);
    expect(h.notifier.resetTokenForTesting, isNull);
    h.dispose();
  });

  group('step transitions', () {
    test(
      'submitEmail success: trims, moves to otp, starts the cooldown',
      () async {
        final h = _Harness();

        final ok = await h.notifier.submitEmail('  user@example.com ');

        expect(ok, isTrue);
        expect(h.repo.requestedEmails, ['user@example.com']);
        expect(h.state.step, ForgotPasswordStep.otp);
        expect(h.state.email, 'user@example.com');
        expect(h.state.resendCooldownSeconds, 60);
        expect(h.state.isSubmitting, isFalse);
        expect(h.state.failure, isNull);
        h.dispose();
      },
    );

    test(
      'submitEmail failure: stays on email, failure set, no cooldown',
      () async {
        final h = _Harness();
        h.repo.requestBehavior =
            () async =>
                throw _dioError(
                  const ValidationFailure(
                    message: 'bad',
                    fields: {
                      'email': ['Enter a valid email address.'],
                    },
                    code: 'VALIDATION_ERROR',
                  ),
                );

        final ok = await h.notifier.submitEmail('nope');

        expect(ok, isFalse);
        expect(h.state.step, ForgotPasswordStep.email);
        expect(h.state.failure, isA<ValidationFailure>());
        expect(h.state.resendCooldownSeconds, 0);
        expect(h.state.isSubmitting, isFalse);
        h.dispose();
      },
    );

    test(
      'a non-Dio error becomes an UnknownFailure, never a stuck spinner',
      () async {
        final h = _Harness();
        h.repo.requestBehavior = () async => throw StateError('boom');

        await h.notifier.submitEmail('user@example.com');

        expect(h.state.failure, isA<UnknownFailure>());
        expect(h.state.isSubmitting, isFalse);
        h.dispose();
      },
    );

    test('a second submitEmail while one is in flight is ignored', () async {
      final h = _Harness();
      final gate = Completer<void>();
      h.repo.requestBehavior = () => gate.future;

      final first = h.notifier.submitEmail('user@example.com');
      expect(h.state.isSubmitting, isTrue);
      final second = await h.notifier.submitEmail('user@example.com');
      expect(second, isFalse);

      gate.complete();
      expect(await first, isTrue);
      expect(h.repo.requestedEmails, hasLength(1));
      h.dispose();
    });

    test(
      'verifyOtp success: trims the code, keeps the token, moves to newPassword',
      () async {
        final h = _Harness();
        await h.notifier.submitEmail('user@example.com');

        final ok = await h.notifier.verifyOtp(' 123456 ');

        expect(ok, isTrue);
        expect(h.repo.verifyCalls.single.email, 'user@example.com');
        expect(h.repo.verifyCalls.single.otp, '123456');
        expect(h.state.step, ForgotPasswordStep.newPassword);
        expect(h.state.resendCooldownSeconds, 0);
        expect(h.notifier.resetTokenForTesting, 'reset-token-1');
        h.dispose();
      },
    );

    test('verifyOtp with the unified 400: stays on otp, no token', () async {
      final h = _Harness();
      await h.notifier.submitEmail('user@example.com');
      h.repo.verifyBehavior = () async => throw _dioError(_unified400);

      final ok = await h.notifier.verifyOtp('000000');

      expect(ok, isFalse);
      expect(h.state.step, ForgotPasswordStep.otp);
      expect(h.state.failure, isA<ValidationFailure>());
      expect(h.notifier.resetTokenForTesting, isNull);
      h.dispose();
    });

    test(
      'confirmNewPassword success: done, token cleared, request carried the token',
      () async {
        final h = _Harness();
        await h.notifier.submitEmail('user@example.com');
        await h.notifier.verifyOtp('123456');

        final ok = await h.notifier.confirmNewPassword('Str0ng!Passw0rd');

        expect(ok, isTrue);
        expect(h.repo.confirmCalls.single.email, 'user@example.com');
        expect(h.repo.confirmCalls.single.token, 'reset-token-1');
        expect(h.repo.confirmCalls.single.password, 'Str0ng!Passw0rd');
        expect(h.state.step, ForgotPasswordStep.done);
        expect(h.state.failure, isNull);
        expect(h.notifier.resetTokenForTesting, isNull);
        h.dispose();
      },
    );

    test(
      'weak password: stays on newPassword and KEEPS the token (still valid)',
      () async {
        final h = _Harness();
        await h.notifier.submitEmail('user@example.com');
        await h.notifier.verifyOtp('123456');
        h.repo.confirmBehavior = () async => throw _dioError(_weakPassword);

        final ok = await h.notifier.confirmNewPassword('12345678');

        expect(ok, isFalse);
        expect(h.state.step, ForgotPasswordStep.newPassword);
        final failure = h.state.failure as ValidationFailure;
        expect(failure.fields.containsKey('new_password'), isTrue);
        expect(h.notifier.resetTokenForTesting, 'reset-token-1');

        // The user can try again with the same token.
        h.repo.confirmBehavior = null;
        expect(await h.notifier.confirmNewPassword('Str0ng!Passw0rd'), isTrue);
        expect(h.repo.confirmCalls.last.token, 'reset-token-1');
        h.dispose();
      },
    );

    test(
      'dead token (unified 400 on confirm): token cleared, flow restarts at email',
      () async {
        final h = _Harness();
        await h.notifier.submitEmail('user@example.com');
        await h.notifier.verifyOtp('123456');
        h.repo.confirmBehavior = () async => throw _dioError(_unified400);

        final ok = await h.notifier.confirmNewPassword('Str0ng!Passw0rd');

        expect(ok, isFalse);
        expect(h.state.step, ForgotPasswordStep.email);
        expect(h.state.email, 'user@example.com');
        expect(h.state.failure, isA<ValidationFailure>());
        expect(h.state.isSubmitting, isFalse);
        expect(h.notifier.resetTokenForTesting, isNull);
        h.dispose();
      },
    );

    test(
      'network failure on confirm: stays, token kept, retry possible',
      () async {
        final h = _Harness();
        await h.notifier.submitEmail('user@example.com');
        await h.notifier.verifyOtp('123456');
        h.repo.confirmBehavior =
            () async =>
                throw _dioError(
                  const NetworkFailure(
                    message: 'offline',
                    code: ApiErrorCodes.networkError,
                  ),
                );

        expect(await h.notifier.confirmNewPassword('Str0ng!Passw0rd'), isFalse);

        expect(h.state.step, ForgotPasswordStep.newPassword);
        expect(h.state.failure, isA<NetworkFailure>());
        expect(h.notifier.resetTokenForTesting, 'reset-token-1');
        h.dispose();
      },
    );

    test('out-of-order actions are ignored and make no call', () async {
      final h = _Harness();

      expect(await h.notifier.verifyOtp('123456'), isFalse);
      expect(await h.notifier.confirmNewPassword('Str0ng!Passw0rd'), isFalse);
      expect(await h.notifier.resendOtp(), isFalse);

      expect(h.repo.verifyCalls, isEmpty);
      expect(h.repo.confirmCalls, isEmpty);
      expect(h.repo.requestedEmails, isEmpty);
      expect(h.state.step, ForgotPasswordStep.email);
      h.dispose();
    });

    test(
      'backToEmail drops token and cooldown but keeps the typed email',
      () async {
        final h = _Harness();
        await h.notifier.submitEmail('user@example.com');
        await h.notifier.verifyOtp('123456');

        h.notifier.backToEmail();

        expect(h.state.step, ForgotPasswordStep.email);
        expect(h.state.email, 'user@example.com');
        expect(h.state.resendCooldownSeconds, 0);
        expect(h.notifier.resetTokenForTesting, isNull);
        h.dispose();
      },
    );

    test('reset returns to a blank flow', () async {
      final h = _Harness();
      await h.notifier.submitEmail('user@example.com');
      await h.notifier.verifyOtp('123456');

      h.notifier.reset();

      expect(h.state.step, ForgotPasswordStep.email);
      expect(h.state.email, '');
      expect(h.notifier.resetTokenForTesting, isNull);
      h.dispose();
    });
  });

  group('token and secrets in memory', () {
    test('the reset token is cleared when the notifier is disposed', () async {
      final h = _Harness();
      await h.notifier.submitEmail('user@example.com');
      await h.notifier.verifyOtp('123456');
      final notifier = h.notifier;
      expect(notifier.resetTokenForTesting, 'reset-token-1');

      h.dispose();

      expect(notifier.resetTokenForTesting, isNull);
    });

    test(
      'the state never holds the token, and its toString hides the email',
      () async {
        final h = _Harness();
        await h.notifier.submitEmail('user@example.com');
        await h.notifier.verifyOtp('123456');

        final text = h.state.toString();
        expect(text, isNot(contains('reset-token-1')));
        expect(text, isNot(contains('user@example.com')));
        h.dispose();
      },
    );
  });

  group('resend cooldown (fake clock)', () {
    testWidgets(
      'counts down 60 -> 0 one second at a time, then allows resend',
      (tester) async {
        final h = _Harness();
        await h.notifier.submitEmail('user@example.com');
        expect(h.state.resendCooldownSeconds, 60);
        expect(h.state.canResend, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(h.state.resendCooldownSeconds, 59);

        await tester.pump(const Duration(seconds: 29));
        expect(h.state.resendCooldownSeconds, 30);

        await tester.pump(const Duration(seconds: 29));
        expect(h.state.resendCooldownSeconds, 1);
        expect(h.state.canResend, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(h.state.resendCooldownSeconds, 0);
        expect(h.state.canResend, isTrue);

        // The timer stopped itself: further time changes nothing.
        await tester.pump(const Duration(seconds: 10));
        expect(h.state.resendCooldownSeconds, 0);
        h.dispose();
      },
    );

    testWidgets(
      'resendOtp is ignored during the cooldown, works after it and restarts it',
      (tester) async {
        final h = _Harness();
        await h.notifier.submitEmail('user@example.com');
        expect(h.repo.requestedEmails, hasLength(1));

        expect(await h.notifier.resendOtp(), isFalse);
        expect(h.repo.requestedEmails, hasLength(1));

        await tester.pump(const Duration(seconds: 60));
        expect(h.state.canResend, isTrue);

        expect(await h.notifier.resendOtp(), isTrue);
        expect(h.repo.requestedEmails, [
          'user@example.com',
          'user@example.com',
        ]);
        expect(h.state.resendCooldownSeconds, 60);
        expect(h.state.step, ForgotPasswordStep.otp);
        h.dispose();
      },
    );

    testWidgets(
      'a throttled resend restarts the wait with the server Retry-After',
      (tester) async {
        final h = _Harness();
        await h.notifier.submitEmail('user@example.com');
        await tester.pump(const Duration(seconds: 60));
        h.repo.requestBehavior =
            () async =>
                throw _dioError(
                  const UnknownFailure(
                    message: 'Request was throttled.',
                    code: 'THROTTLED',
                    retryAfter: Duration(seconds: 90),
                  ),
                );

        expect(await h.notifier.resendOtp(), isFalse);

        expect(h.state.failure, isA<UnknownFailure>());
        expect(h.state.failure!.code, 'THROTTLED');
        expect(h.state.resendCooldownSeconds, 90);
        expect(h.state.step, ForgotPasswordStep.otp);
        h.dispose();
      },
    );

    testWidgets('a throttled resend without Retry-After falls back to 60 s', (
      tester,
    ) async {
      final h = _Harness();
      await h.notifier.submitEmail('user@example.com');
      await tester.pump(const Duration(seconds: 60));
      h.repo.requestBehavior =
          () async =>
              throw _dioError(
                const UnknownFailure(
                  message: 'Request was throttled.',
                  code: 'THROTTLED',
                ),
              );

      await h.notifier.resendOtp();

      expect(h.state.resendCooldownSeconds, 60);
      h.dispose();
    });

    testWidgets('moving to the new-password step stops the cooldown', (
      tester,
    ) async {
      final h = _Harness();
      await h.notifier.submitEmail('user@example.com');
      await tester.pump(const Duration(seconds: 5));
      expect(h.state.resendCooldownSeconds, 55);

      await h.notifier.verifyOtp('123456');
      expect(h.state.resendCooldownSeconds, 0);

      await tester.pump(const Duration(seconds: 30));
      expect(h.state.resendCooldownSeconds, 0);
      expect(h.state.step, ForgotPasswordStep.newPassword);
      h.dispose();
    });

    testWidgets('disposing cancels the timer (no pending timer left)', (
      tester,
    ) async {
      final h = _Harness();
      await h.notifier.submitEmail('user@example.com');
      expect(h.state.resendCooldownSeconds, 60);

      h.dispose();
      // If the periodic timer survived dispose, testWidgets would fail at the
      // end of this test with "A Timer is still pending".
    });
  });
}
