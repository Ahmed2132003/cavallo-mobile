import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/auth/data/auth_repository_impl.dart';
import 'package:social_commerce_app/features/auth/domain/auth_repository.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/login_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// The "Forgot password?" link of the login screen, and the email handed back
/// to it after a finished reset. Kept apart from `login_screen_test.dart` so
/// that file stays as it was.
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

class _FakeRepo implements AuthRepository {
  _FakeRepo({this.loginBehavior});

  final Future<void> Function()? loginBehavior;

  @override
  Future<void> login({required String email, required String password}) async {
    await loginBehavior?.call();
  }

  @override
  Future<User> fetchMe() async => const User(
    id: 1,
    email: 'user@example.com',
    accountType: AccountType.customer,
    isModerator: false,
    isStaff: false,
  );

  @override
  Future<User> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required AccountType accountType,
  }) => throw UnimplementedError();

  @override
  Future<void> refresh() => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> requestPasswordReset({required String email}) =>
      throw UnimplementedError();

  @override
  Future<String> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) => throw UnimplementedError();

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) => throw UnimplementedError();
}

Widget _wrap(AuthRepository repo, {String? initialEmail}) {
  final router = GoRouter(
    initialLocation: RouteNames.loginPath,
    routes: [
      GoRoute(
        path: RouteNames.loginPath,
        name: RouteNames.login,
        builder: (context, state) => LoginScreen(initialEmail: initialEmail),
      ),
      GoRoute(
        path: RouteNames.registerPath,
        name: RouteNames.register,
        builder:
            (context, state) => const Scaffold(body: Text('REGISTER-STUB')),
      ),
      GoRoute(
        path: RouteNames.forgotPasswordPath,
        name: RouteNames.forgotPassword,
        builder:
            (context, state) =>
                Scaffold(body: Text('FORGOT-STUB:${state.extra ?? 'none'}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('the link sits between the login and register buttons', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    await tester.pumpAndSettle();

    final loginY = tester.getTopLeft(find.byType(AppButton)).dy;
    final linkY = tester.getTopLeft(find.text(_l10n.authForgotPasswordLink)).dy;
    final registerY = tester.getTopLeft(find.text(_l10n.authGoToRegister)).dy;
    expect(loginY, lessThan(linkY));
    expect(linkY, lessThan(registerY));
  });

  testWidgets('tapping it opens the flow without an email when the field is '
      'empty', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_l10n.authForgotPasswordLink));
    await tester.pumpAndSettle();

    expect(find.text('FORGOT-STUB:none'), findsOneWidget);
  });

  testWidgets('tapping it hands the typed (trimmed) email to step 1', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      '  user@example.com  ',
    );
    await tester.tap(find.text(_l10n.authForgotPasswordLink));
    await tester.pumpAndSettle();

    expect(find.text('FORGOT-STUB:user@example.com'), findsOneWidget);
  });

  testWidgets('the link is disabled while the login request is running', (
    tester,
  ) async {
    final completer = Completer<void>();
    await tester.pumpWidget(
      _wrap(_FakeRepo(loginBehavior: () => completer.future)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret-pass-1');
    await tester.tap(find.byType(AppButton));
    await tester.pump();

    final link = tester.widget<TextButton>(
      find.widgetWithText(TextButton, _l10n.authForgotPasswordLink),
    );
    expect(link.onPressed, isNull);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('initialEmail (from a finished reset) fills the email field', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(_FakeRepo(), initialEmail: 'back@example.com'),
    );
    await tester.pumpAndSettle();

    final email = tester.widget<EditableText>(find.byType(EditableText).at(0));
    expect(email.controller.text, 'back@example.com');
  });
}
