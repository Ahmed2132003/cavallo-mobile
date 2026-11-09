import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/auth/data/auth_repository_impl.dart';
import 'package:social_commerce_app/features/auth/domain/auth_repository.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/forgot_password_provider.dart';
import 'package:social_commerce_app/features/auth/presentation/forgot_password_screens.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Widget tests of the three forgot-password screens, with a hand-rolled fake
/// repository (this project's convention) and a tiny GoRouter that holds the
/// real screens plus a stub login page. Texts come from the English
/// localizations, so a copy change does not break the tests.
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

class _FakeRepo implements AuthRepository {
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

const _network = NetworkFailure(message: 'x', code: ApiErrorCodes.networkError);
const _throttled = UnknownFailure(message: 'x', code: ApiErrorCodes.throttled);
const _throttled90 = UnknownFailure(
  message: 'x',
  code: ApiErrorCodes.throttled,
  retryAfter: Duration(seconds: 90),
);
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

class _LoginStub extends StatelessWidget {
  const _LoginStub(this.email);

  final String? email;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text('LOGIN-STUB:${email ?? ''}'));
}

String? _extraEmail(GoRouterState state) =>
    state.extra is String ? state.extra as String : null;

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _FakeRepo repo, {
  String? initialEmail,
}) async {
  final router = GoRouter(
    initialLocation: RouteNames.forgotPasswordPath,
    initialExtra: initialEmail,
    routes: [
      GoRoute(
        path: RouteNames.forgotPasswordPath,
        name: RouteNames.forgotPassword,
        builder:
            (context, state) =>
                ForgotPasswordEmailScreen(initialEmail: _extraEmail(state)),
      ),
      GoRoute(
        path: RouteNames.forgotPasswordVerifyPath,
        name: RouteNames.forgotPasswordVerify,
        builder: (context, state) => const ForgotPasswordOtpScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPasswordNewPasswordPath,
        name: RouteNames.forgotPasswordNewPassword,
        builder: (context, state) => const ForgotPasswordNewPasswordScreen(),
      ),
      GoRoute(
        path: RouteNames.loginPath,
        name: RouteNames.login,
        builder: (context, state) => _LoginStub(_extraEmail(state)),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  // Keep the autoDispose flow alive so the test can inspect it after the
  // screens are gone.
  container.listen(forgotPasswordProvider, (previous, next) {});
  return container;
}

/// Runs [body], then unmounts the app so the cooldown timer is cancelled
/// before the test ends.
void _flowTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _sendCode(
  WidgetTester tester, {
  String email = 'user@example.com',
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.tap(find.widgetWithText(AppButton, _l10n.authResetEmailSubmit));
  await tester.pumpAndSettle();
}

Future<void> _verifyCode(WidgetTester tester, {String code = '123456'}) async {
  await tester.enterText(find.byType(TextFormField).first, code);
  await tester.tap(find.widgetWithText(AppButton, _l10n.authResetOtpSubmit));
  await tester.pumpAndSettle();
}

Future<void> _submitPasswords(
  WidgetTester tester, {
  String password = 'Str0ng!Passw0rd',
  String confirm = 'Str0ng!Passw0rd',
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), password);
  await tester.enterText(find.byType(TextFormField).at(1), confirm);
  await tester.tap(
    find.widgetWithText(AppButton, _l10n.authResetNewPasswordSubmit),
  );
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, int index) =>
    tester
        .widget<EditableText>(find.byType(EditableText).at(index))
        .controller
        .text;

void main() {
  group('Step 1 - email', () {
    _flowTest('validators: empty and malformed email, no request sent', (
      tester,
    ) async {
      final repo = _FakeRepo();
      await _pump(tester, repo);

      await tester.tap(
        find.widgetWithText(AppButton, _l10n.authResetEmailSubmit),
      );
      await tester.pumpAndSettle();
      expect(find.text(_l10n.authEmailRequired), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(
        find.widgetWithText(AppButton, _l10n.authResetEmailSubmit),
      );
      await tester.pumpAndSettle();
      expect(find.text(_l10n.authEmailInvalid), findsOneWidget);
      expect(repo.requestedEmails, isEmpty);
    });

    _flowTest('the email typed on the login screen is prefilled', (
      tester,
    ) async {
      await _pump(tester, _FakeRepo(), initialEmail: 'typed@example.com');
      expect(_fieldText(tester, 0), 'typed@example.com');
    });

    _flowTest('loading state: spinner and a disabled back-to-login button', (
      tester,
    ) async {
      final completer = Completer<void>();
      final repo = _FakeRepo()..requestBehavior = () => completer.future;
      await _pump(tester, repo);

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(
        find.widgetWithText(AppButton, _l10n.authResetEmailSubmit),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final back = tester.widget<TextButton>(
        find.widgetWithText(TextButton, _l10n.authResetBackToLogin),
      );
      expect(back.onPressed, isNull);

      completer.complete();
      await tester.pumpAndSettle();
    });

    _flowTest('success moves to the code screen with the trimmed email', (
      tester,
    ) async {
      final repo = _FakeRepo();
      await _pump(tester, repo);

      await _sendCode(tester, email: '  user@example.com  ');

      expect(repo.requestedEmails, ['user@example.com']);
      expect(find.text(_l10n.authResetOtpTitle), findsOneWidget);
      // Neutral text: it never claims that a code was sent.
      expect(
        find.text(_l10n.authResetOtpNeutralHint('user@example.com')),
        findsOneWidget,
      );
    });

    _flowTest('429 shows the throttled message and stays on step 1', (
      tester,
    ) async {
      final repo =
          _FakeRepo()
            ..requestBehavior = () async => throw _dioError(_throttled);
      await _pump(tester, repo);

      await _sendCode(tester);

      expect(find.text(_l10n.authResetThrottled), findsOneWidget);
      expect(find.text(_l10n.authResetEmailTitle), findsOneWidget);
    });

    _flowTest('network failure shows a message and the retry works', (
      tester,
    ) async {
      final repo =
          _FakeRepo()..requestBehavior = () async => throw _dioError(_network);
      await _pump(tester, repo);

      await _sendCode(tester);
      expect(find.text(_l10n.errorNetwork), findsOneWidget);
      expect(find.text(_l10n.authResetEmailTitle), findsOneWidget);

      repo.requestBehavior = null;
      await tester.tap(
        find.widgetWithText(AppButton, _l10n.authResetEmailSubmit),
      );
      await tester.pumpAndSettle();

      expect(repo.requestedEmails.length, 2);
      expect(find.text(_l10n.authResetOtpTitle), findsOneWidget);
    });
  });

  group('Step 2 - code', () {
    _flowTest('shows the expiry note and a disabled resend with a countdown', (
      tester,
    ) async {
      await _pump(tester, _FakeRepo());
      await _sendCode(tester);

      expect(find.text(_l10n.authResetOtpExpiry), findsOneWidget);
      final resend = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, _l10n.authResetResendCooldown(60)),
      );
      expect(resend.onPressed, isNull);
    });

    _flowTest('the code field takes digits only, at most 6', (tester) async {
      await _pump(tester, _FakeRepo());
      await _sendCode(tester);

      await tester.enterText(find.byType(TextFormField).first, 'ab12 3456789');
      await tester.pump();

      expect(_fieldText(tester, 0), '123456');
    });

    _flowTest('validators: empty and too-short code, no request sent', (
      tester,
    ) async {
      final repo = _FakeRepo();
      await _pump(tester, repo);
      await _sendCode(tester);

      await tester.tap(
        find.widgetWithText(AppButton, _l10n.authResetOtpSubmit),
      );
      await tester.pumpAndSettle();
      expect(find.text(_l10n.authResetOtpRequired), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '123');
      await tester.tap(
        find.widgetWithText(AppButton, _l10n.authResetOtpSubmit),
      );
      await tester.pumpAndSettle();
      expect(find.text(_l10n.authResetOtpInvalid), findsOneWidget);
      expect(repo.verifyCalls, isEmpty);
    });

    _flowTest('the unified 400 shows "invalid or expired" and stays', (
      tester,
    ) async {
      final repo =
          _FakeRepo()
            ..verifyBehavior = () async => throw _dioError(_unified400);
      await _pump(tester, repo);
      await _sendCode(tester);

      await _verifyCode(tester);

      expect(find.text(_l10n.authResetOtpInvalid), findsOneWidget);
      expect(find.text(_l10n.authResetOtpTitle), findsOneWidget);
    });

    _flowTest('429 on verify shows the throttled message', (tester) async {
      final repo =
          _FakeRepo()..verifyBehavior = () async => throw _dioError(_throttled);
      await _pump(tester, repo);
      await _sendCode(tester);

      await _verifyCode(tester);

      expect(find.text(_l10n.authResetThrottled), findsOneWidget);
    });

    _flowTest('a correct code moves to the new-password screen', (
      tester,
    ) async {
      final repo = _FakeRepo();
      await _pump(tester, repo);
      await _sendCode(tester);

      await _verifyCode(tester);

      expect(repo.verifyCalls.single.otp, '123456');
      expect(repo.verifyCalls.single.email, 'user@example.com');
      expect(find.text(_l10n.authResetNewPasswordTitle), findsOneWidget);
    });

    _flowTest('resend: locked for 60 s, then allowed, then locked again', (
      tester,
    ) async {
      final repo = _FakeRepo();
      await _pump(tester, repo);
      await _sendCode(tester);
      expect(repo.requestedEmails.length, 1);

      await tester.pump(const Duration(seconds: 59));
      expect(
        find.widgetWithText(OutlinedButton, _l10n.authResetResendCooldown(1)),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 2));
      final resendFinder = find.widgetWithText(
        OutlinedButton,
        _l10n.authResetResendButton,
      );
      expect(tester.widget<OutlinedButton>(resendFinder).onPressed, isNotNull);

      await tester.tap(resendFinder);
      await tester.pump();
      await tester.pump();

      expect(repo.requestedEmails.length, 2);
      expect(find.text(_l10n.authResetResendSent), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, _l10n.authResetResendCooldown(60)),
        findsOneWidget,
      );
    });

    _flowTest('resend answered with 429 restarts the wait from Retry-After', (
      tester,
    ) async {
      final repo = _FakeRepo();
      await _pump(tester, repo);
      await _sendCode(tester);
      await tester.pump(const Duration(seconds: 61));

      repo.requestBehavior = () async => throw _dioError(_throttled90);
      await tester.tap(
        find.widgetWithText(OutlinedButton, _l10n.authResetResendButton),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(_l10n.authResetThrottled), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, _l10n.authResetResendCooldown(90)),
        findsOneWidget,
      );
    });

    _flowTest('"use a different email" goes back to step 1 with the address', (
      tester,
    ) async {
      final container = await _pump(tester, _FakeRepo());
      await _sendCode(tester);

      await tester.tap(find.text(_l10n.authResetChangeEmail));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.authResetEmailTitle), findsOneWidget);
      expect(_fieldText(tester, 0), 'user@example.com');
      expect(
        container.read(forgotPasswordProvider).step,
        ForgotPasswordStep.email,
      );
    });
  });

  group('Step 3 - new password', () {
    Future<_FakeRepo> toStep3(WidgetTester tester, {_FakeRepo? repo}) async {
      final r = repo ?? _FakeRepo();
      await _pump(tester, r);
      await _sendCode(tester);
      await _verifyCode(tester);
      expect(find.text(_l10n.authResetNewPasswordTitle), findsOneWidget);
      return r;
    }

    _flowTest('validators: empty fields and a mismatch, no request sent', (
      tester,
    ) async {
      final repo = await toStep3(tester);

      await tester.tap(
        find.widgetWithText(AppButton, _l10n.authResetNewPasswordSubmit),
      );
      await tester.pumpAndSettle();
      expect(find.text(_l10n.authResetPasswordRequired), findsNWidgets(2));

      await _submitPasswords(tester, password: 'abc', confirm: 'abd');
      expect(find.text(_l10n.authResetPasswordsDoNotMatch), findsOneWidget);
      expect(repo.confirmCalls, isEmpty);
    });

    _flowTest('the show/hide button toggles both fields', (tester) async {
      await toStep3(tester);

      bool obscured(int i) =>
          tester
              .widget<EditableText>(find.byType(EditableText).at(i))
              .obscureText;
      expect(obscured(0), isTrue);
      expect(obscured(1), isTrue);

      await tester.tap(find.byTooltip(_l10n.authResetShowPassword).first);
      await tester.pump();

      expect(obscured(0), isFalse);
      expect(obscured(1), isFalse);
      expect(find.byTooltip(_l10n.authResetHidePassword), findsNWidgets(2));
    });

    _flowTest('weak password: error under the field, token kept, retry ok', (
      tester,
    ) async {
      final repo = _FakeRepo();
      await toStep3(tester, repo: repo);
      repo.confirmBehavior = () async => throw _dioError(_weakPassword);

      await _submitPasswords(
        tester,
        password: 'password1',
        confirm: 'password1',
      );

      expect(find.text(_l10n.authResetPasswordWeak), findsOneWidget);
      expect(find.text(_l10n.authResetNewPasswordTitle), findsOneWidget);

      repo.confirmBehavior = null;
      await _submitPasswords(tester);

      expect(repo.confirmCalls.length, 2);
      expect(repo.confirmCalls[0].token, repo.confirmCalls[1].token);
      expect(find.textContaining('LOGIN-STUB'), findsOneWidget);
    });

    _flowTest('success: state wiped, message shown, back to login with email', (
      tester,
    ) async {
      final repo = _FakeRepo();
      final container = await _pump(tester, repo);
      await _sendCode(tester);
      await _verifyCode(tester);

      await _submitPasswords(tester);

      expect(repo.confirmCalls.single.password, 'Str0ng!Passw0rd');
      expect(repo.confirmCalls.single.email, 'user@example.com');
      // Back on the login page with the address (no automatic login).
      expect(find.text('LOGIN-STUB:user@example.com'), findsOneWidget);
      expect(find.text(_l10n.authResetSuccessBody), findsOneWidget);
      // The whole flow state is gone.
      final state = container.read(forgotPasswordProvider);
      expect(state.step, ForgotPasswordStep.email);
      expect(state.email, isEmpty);
      expect(state.resendCooldownSeconds, 0);
      expect(state.failure, isNull);
      expect(
        container.read(forgotPasswordProvider.notifier).resetTokenForTesting,
        isNull,
      );
    });

    _flowTest('a dead reset token (unified 400) restarts at step 1', (
      tester,
    ) async {
      final repo = _FakeRepo();
      final container = await _pump(tester, repo);
      await _sendCode(tester);
      await _verifyCode(tester);
      repo.confirmBehavior = () async => throw _dioError(_unified400);

      await _submitPasswords(tester);

      expect(find.text(_l10n.authResetEmailTitle), findsOneWidget);
      expect(find.text(_l10n.authResetSessionExpired), findsOneWidget);
      expect(
        container.read(forgotPasswordProvider.notifier).resetTokenForTesting,
        isNull,
      );
    });

    _flowTest('network failure keeps the user here and the retry works', (
      tester,
    ) async {
      final repo = _FakeRepo();
      await toStep3(tester, repo: repo);
      repo.confirmBehavior = () async => throw _dioError(_network);

      await _submitPasswords(tester);
      expect(find.text(_l10n.errorNetwork), findsOneWidget);
      expect(find.text(_l10n.authResetNewPasswordTitle), findsOneWidget);

      repo.confirmBehavior = null;
      await _submitPasswords(tester);
      expect(find.textContaining('LOGIN-STUB'), findsOneWidget);
    });

    _flowTest('429 on confirm shows the throttled message', (tester) async {
      final repo = _FakeRepo();
      await toStep3(tester, repo: repo);
      repo.confirmBehavior = () async => throw _dioError(_throttled);

      await _submitPasswords(tester);

      expect(find.text(_l10n.authResetThrottled), findsOneWidget);
    });
  });
}
