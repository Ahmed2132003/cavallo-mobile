import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/auth/data/auth_repository_impl.dart';
import 'package:social_commerce_app/features/auth/domain/auth_repository.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/register_screen.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Hand-rolled fake, matching this project's existing test convention (no
/// mockito/mocktail anywhere — Part P-021a's/P-021b's own test files).
/// Exercises both [register] and [login], since RegisterScreen (Part
/// P-021c) chains the two.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.registerBehavior,
    this.loginBehavior,
    this.fetchMeBehavior,
  });

  /// Invoked by [register]. Return the [User] to "create," or `throw` an
  /// [ApiFailure] to simulate a backend rejection. `null` (the default)
  /// returns a fixed successful [User].
  final Future<User> Function()? registerBehavior;

  /// Invoked by [login], only ever reached after a successful [register]
  /// (RegisterScreen's confirmed chained-login behavior). `null` (the
  /// default) completes successfully with no extra behavior.
  final Future<void> Function()? loginBehavior;

  /// Invoked by [fetchMe]. `SessionNotifier.login` (session_provider.dart)
  /// calls [fetchMe] immediately after the chained [login] succeeds, to
  /// resolve the real authenticated user — genuinely exercised by every
  /// test here where both register and the chained login succeed. `null`
  /// (the default) returns a fixed successful [User].
  final Future<User> Function()? fetchMeBehavior;

  int registerCallCount = 0;
  int loginCallCount = 0;
  int fetchMeCallCount = 0;
  String? lastEmail;
  String? lastPassword;
  String? lastPasswordConfirm;
  AccountType? lastAccountType;

  static const _defaultUser = User(
    id: 1,
    email: 'new@example.com',
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
  }) async {
    registerCallCount++;
    lastEmail = email;
    lastPassword = password;
    lastPasswordConfirm = passwordConfirm;
    lastAccountType = accountType;
    if (registerBehavior != null) {
      return registerBehavior!();
    }
    return _defaultUser;
  }

  @override
  Future<void> login({required String email, required String password}) async {
    loginCallCount++;
    if (loginBehavior != null) {
      await loginBehavior!();
    }
  }

  @override
  Future<void> refresh() =>
      throw UnimplementedError('Not exercised by register_screen_test.dart');

  @override
  Future<void> logout() =>
      throw UnimplementedError('Not exercised by register_screen_test.dart');

  @override
  Future<User> fetchMe() async {
    fetchMeCallCount++;
    if (fetchMeBehavior != null) {
      return fetchMeBehavior!();
    }
    return _defaultUser;
  }
}

/// Plain [MaterialApp] harness — enough for every test that never expects
/// RegisterScreen to actually navigate anywhere (the happy path relies on
/// the router's own redirect guard, tested separately in
/// `app_router_redirect_test.dart`, Part P-021b).
Widget _wrap(AuthRepository fakeRepository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
    child: const MaterialApp(home: RegisterScreen()),
  );
}

/// [GoRouter]-backed harness, needed only for the one scenario where
/// RegisterScreen itself calls `context.goNamed` (chained-login failure
/// after a successful register) — a bare `MaterialApp` has no `GoRouter`
/// ancestor for that call to find.
Widget _wrapWithRouter(AuthRepository fakeRepository) {
  final router = GoRouter(
    initialLocation: RouteNames.registerPath,
    routes: [
      GoRoute(
        path: RouteNames.registerPath,
        name: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.loginPath,
        name: RouteNames.login,
        builder: (context, state) =>
            const Scaffold(body: Text('LOGIN_SCREEN_PLACEHOLDER')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _enterValidForm(
  WidgetTester tester, {
  String email = 'new@example.com',
  String password = 'correct-horse-battery-staple',
  String? passwordConfirm,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.enterText(
    find.byType(TextFormField).at(2),
    passwordConfirm ?? password,
  );
}

void main() {
  setUp(() {
    // SessionNotifier.build() (Part P-021a) reads SecureTokenStorage on
    // provider initialization — mock the underlying plugin channel so
    // that resolves to "no token" (unauthenticated), with no real device
    // storage involved, per P-020/P-021a/P-021b's own established test
    // convention. secureTokenStorageProvider itself is deliberately NOT
    // overridden — the real provider naturally returns null against this
    // mocked-empty backing store.
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('RegisterScreen — local validation', () {
    testWidgets(
      'shows a required-field error for all three fields on an empty '
      'submit, without calling the repository',
      (tester) async {
        final fakeRepo = _FakeAuthRepository();
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(AppButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(find.text('Email is required.'), findsOneWidget);
        expect(find.text('Password is required.'), findsOneWidget);
        expect(find.text('Please confirm your password.'), findsOneWidget);
        expect(fakeRepo.registerCallCount, 0);
      },
    );

    testWidgets(
      'shows a format error for an invalid email, without calling the '
      'repository',
      (tester) async {
        final fakeRepo = _FakeAuthRepository();
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterValidForm(tester, email: 'not-an-email');
        await tester.tap(find.widgetWithText(AppButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(find.text('Enter a valid email address.'), findsOneWidget);
        expect(fakeRepo.registerCallCount, 0);
      },
    );

    testWidgets(
      'a mismatched password/confirm shows a client-side error, without '
      'calling the repository',
      (tester) async {
        final fakeRepo = _FakeAuthRepository();
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterValidForm(
          tester,
          password: 'correct-horse-battery-staple',
          passwordConfirm: 'something-else',
        );
        await tester.tap(find.widgetWithText(AppButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(find.text('Passwords do not match.'), findsOneWidget);
        expect(fakeRepo.registerCallCount, 0);
      },
    );
  });

  group('RegisterScreen — submitting (confirmed auto-login-after-register)', () {
    testWidgets(
      'a valid submit calls AuthRepository.register with the trimmed '
      'email, the selected account type, and shows a loading indicator '
      'while the register call is in flight',
      (tester) async {
        final registerCompleter = Completer<User>();
        final fakeRepo = _FakeAuthRepository(
          registerBehavior: () => registerCompleter.future,
        );
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterValidForm(tester, email: '  new@example.com  ');
        await tester.tap(find.widgetWithText(AppButton, 'Create account'));
        await tester.pump(); // one frame — do NOT settle, request is stuck

        expect(fakeRepo.registerCallCount, 1);
        expect(fakeRepo.lastEmail, 'new@example.com'); // trimmed
        expect(fakeRepo.lastAccountType, AccountType.customer); // default
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        registerCompleter.complete(
          const User(
            id: 2,
            email: 'new@example.com',
            accountType: AccountType.customer,
            isModerator: false,
            isStaff: false,
          ),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'selecting "Business" before submitting passes AccountType.business '
      'to the repository',
      (tester) async {
        final fakeRepo = _FakeAuthRepository();
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Business'));
        await tester.pumpAndSettle();
        await _enterValidForm(tester);
        await tester.tap(find.widgetWithText(AppButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(fakeRepo.lastAccountType, AccountType.business);
      },
    );

    testWidgets(
      'a successful register chains straight into AuthRepository.login '
      'with the same credentials — the confirmed auto-login decision',
      (tester) async {
        final fakeRepo = _FakeAuthRepository();
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterValidForm(
          tester,
          email: 'new@example.com',
          password: 'correct-horse-battery-staple',
        );
        await tester.tap(find.widgetWithText(AppButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(fakeRepo.registerCallCount, 1);
        expect(fakeRepo.loginCallCount, 1);
      },
    );

    testWidgets(
      'a ValidationFailure from register with an email field error is '
      'shown under the email field, and login is never called',
      (tester) async {
        final fakeRepo = _FakeAuthRepository(
          registerBehavior: () => throw const ValidationFailure(
            message: 'Invalid data.',
            fields: {
              'email': ['A user with this email already exists.'],
            },
          ),
        );
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterValidForm(tester);
        await tester.tap(find.widgetWithText(AppButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(
          find.text('A user with this email already exists.'),
          findsOneWidget,
        );
        expect(fakeRepo.loginCallCount, 0);
      },
    );

    testWidgets(
      'a ValidationFailure from register with a password_confirm field '
      'error is shown under the confirm-password field',
      (tester) async {
        final fakeRepo = _FakeAuthRepository(
          registerBehavior: () => throw const ValidationFailure(
            message: 'Invalid data.',
            fields: {
              'password_confirm': ["Passwords didn't match."],
            },
          ),
        );
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterValidForm(tester);
        await tester.tap(find.widgetWithText(AppButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(find.text("Passwords didn't match."), findsOneWidget);
      },
    );

    testWidgets(
      'a ValidationFailure from register with an account_type field '
      'error is shown beneath the account-type selector',
      (tester) async {
        final fakeRepo = _FakeAuthRepository(
          registerBehavior: () => throw const ValidationFailure(
            message: 'Invalid data.',
            fields: {
              'account_type': ['Not a valid choice.'],
            },
          ),
        );
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterValidForm(tester);
        await tester.tap(find.widgetWithText(AppButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(find.text('Not a valid choice.'), findsOneWidget);
      },
    );

    testWidgets(
      'a non-field ValidationFailure from register is shown as a general '
      'error',
      (tester) async {
        final fakeRepo = _FakeAuthRepository(
          registerBehavior: () => throw const ValidationFailure(
            message: 'Something about the request was invalid.',
            fields: {},
          ),
        );
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterValidForm(tester);
        await tester.tap(find.widgetWithText(AppButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(
          find.text('Something about the request was invalid.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a ServerFailure from register is shown as a general error',
      (tester) async {
        final fakeRepo = _FakeAuthRepository(
          registerBehavior: () =>
              throw const ServerFailure(message: 'Something went wrong.'),
        );
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterValidForm(tester);
        await tester.tap(find.widgetWithText(AppButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(find.text('Something went wrong.'), findsOneWidget);
      },
    );
  });

  group('RegisterScreen — chained-login failure after a successful register', () {
    testWidgets(
      'shows a degraded-landing message and navigates to /login, since '
      'the account already exists at that point',
      (tester) async {
        final fakeRepo = _FakeAuthRepository(
          loginBehavior: () =>
              throw const NetworkFailure(message: 'No connection.'),
        );
        await tester.pumpWidget(_wrapWithRouter(fakeRepo));
        await tester.pumpAndSettle();

        await _enterValidForm(tester);
        await tester.tap(find.widgetWithText(AppButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(fakeRepo.registerCallCount, 1);
        expect(fakeRepo.loginCallCount, 1);
        expect(find.text('LOGIN_SCREEN_PLACEHOLDER'), findsOneWidget);
      },
    );
  });
}