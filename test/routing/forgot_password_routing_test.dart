import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/features/auth/data/auth_repository_impl.dart';
import 'package:social_commerce_app/features/auth/domain/auth_repository.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/forgot_password_provider.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Router behaviour of the three forgot-password routes: public for a
/// signed-out user, bounced to /home for a signed-in one, and steps 2 and 3
/// sent back to step 1 when there is no flow state (cold start / deep link).
class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._fixedValue);

  final User? _fixedValue;

  @override
  Future<User?> build() async => _fixedValue;
}

/// Only the three password-reset calls do anything; everything else is not
/// part of what this file exercises.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<String> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async => 'reset-token-1';

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {}

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

const _fakeUser = User(
  id: 1,
  email: 'test@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

class _Pumped {
  _Pumped(this.router, this.container);

  final GoRouter router;
  final ProviderContainer container;

  String get path => router.routerDelegate.currentConfiguration.uri.toString();

  ForgotPasswordNotifier get flow =>
      container.read(forgotPasswordProvider.notifier);
}

Future<_Pumped> _pump(WidgetTester tester, {required User? user}) async {
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSessionNotifier(user)),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(sessionProvider.future);

  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Pumped(router, container);
}

void main() {
  test('the three paths and names are the fixed ones', () {
    expect(RouteNames.forgotPasswordPath, '/forgot-password');
    expect(RouteNames.forgotPasswordVerifyPath, '/forgot-password/verify');
    expect(
      RouteNames.forgotPasswordNewPasswordPath,
      '/forgot-password/new-password',
    );
    expect(RouteNames.forgotPassword, 'forgotPassword');
    expect(RouteNames.forgotPasswordVerify, 'forgotPasswordVerify');
    expect(RouteNames.forgotPasswordNewPassword, 'forgotPasswordNewPassword');
  });

  group('signed out', () {
    testWidgets('step 1 is public (no bounce to /login)', (tester) async {
      final p = await _pump(tester, user: null);

      p.router.goNamed(RouteNames.forgotPassword);
      await tester.pumpAndSettle();

      expect(p.path, RouteNames.forgotPasswordPath);
    });

    testWidgets('step 2 without flow state goes back to step 1', (
      tester,
    ) async {
      final p = await _pump(tester, user: null);

      p.router.go(RouteNames.forgotPasswordVerifyPath);
      await tester.pumpAndSettle();

      expect(p.path, RouteNames.forgotPasswordPath);
    });

    testWidgets('step 3 without flow state goes back to step 1', (
      tester,
    ) async {
      final p = await _pump(tester, user: null);

      p.router.go(RouteNames.forgotPasswordNewPasswordPath);
      await tester.pumpAndSettle();

      expect(p.path, RouteNames.forgotPasswordPath);
    });

    testWidgets(
      'step 3 with the flow only at the code step still goes back to step 1',
      (tester) async {
        final p = await _pump(tester, user: null);
        p.router.goNamed(RouteNames.forgotPassword);
        await tester.pumpAndSettle();
        await p.flow.submitEmail('user@example.com');
        await tester.pumpAndSettle();
        expect(
          p.container.read(forgotPasswordProvider).step,
          ForgotPasswordStep.otp,
        );

        p.router.go(RouteNames.forgotPasswordNewPasswordPath);
        await tester.pumpAndSettle();

        expect(p.path, RouteNames.forgotPasswordPath);
        // Stops the resend-cooldown timer started by submitEmail.
        p.flow.reset();
      },
    );

    testWidgets('with state, step 2 then step 3 are reachable', (tester) async {
      final p = await _pump(tester, user: null);
      p.router.goNamed(RouteNames.forgotPassword);
      await tester.pumpAndSettle();

      await p.flow.submitEmail('user@example.com');
      p.router.goNamed(RouteNames.forgotPasswordVerify);
      await tester.pumpAndSettle();
      expect(p.path, RouteNames.forgotPasswordVerifyPath);

      await p.flow.verifyOtp('123456');
      p.router.goNamed(RouteNames.forgotPasswordNewPassword);
      await tester.pumpAndSettle();
      expect(p.path, RouteNames.forgotPasswordNewPasswordPath);

      // The done state keeps showing on the step-3 route.
      await p.flow.confirmNewPassword('Str0ng!Passw0rd');
      expect(
        p.container.read(forgotPasswordProvider).step,
        ForgotPasswordStep.done,
      );
      p.router.go(RouteNames.forgotPasswordNewPasswordPath);
      await tester.pumpAndSettle();
      expect(p.path, RouteNames.forgotPasswordNewPasswordPath);
    });

    testWidgets('a protected route still bounces to /login', (tester) async {
      final p = await _pump(tester, user: null);

      p.router.goNamed(RouteNames.search);
      await tester.pumpAndSettle();

      expect(p.path, RouteNames.loginPath);
    });
  });

  group('signed in: all three bounce to /home, like login and register', () {
    for (final entry
        in <String, String>{
          'step 1': RouteNames.forgotPasswordPath,
          'step 2': RouteNames.forgotPasswordVerifyPath,
          'step 3': RouteNames.forgotPasswordNewPasswordPath,
        }.entries) {
      testWidgets('${entry.key} (${entry.value})', (tester) async {
        final p = await _pump(tester, user: _fakeUser);

        p.router.go(entry.value);
        await tester.pumpAndSettle();

        expect(p.path, RouteNames.homePath);
      });
    }

    testWidgets('even with flow state present', (tester) async {
      final p = await _pump(tester, user: _fakeUser);
      p.container.listen(forgotPasswordProvider, (previous, next) {});
      await p.flow.submitEmail('user@example.com');
      await p.flow.verifyOtp('123456');

      p.router.go(RouteNames.forgotPasswordNewPasswordPath);
      await tester.pumpAndSettle();

      expect(p.path, RouteNames.homePath);
    });
  });
}
