import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/auth/data/auth_repository_impl.dart';
import 'package:social_commerce_app/features/auth/domain/auth_repository.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Hand-rolled fake, matching this project's existing test convention
/// (no mockito/mocktail anywhere — confirmed by Part P-021a's own test
/// file). Only [login] is exercised by this screen; the other three
/// methods are never called here.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.loginBehavior});

  /// Invoked by [login]. Return normally for a successful login, or
  /// `throw` an [ApiFailure] to simulate a backend failure. `null` (the
  /// default) completes successfully with no extra behavior.
  final Future<void> Function()? loginBehavior;

  int loginCallCount = 0;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<void> login({required String email, required String password}) async {
    loginCallCount++;
    lastEmail = email;
    lastPassword = password;
    if (loginBehavior != null) {
      await loginBehavior!();
    }
  }

  @override
  Future<User> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required AccountType accountType,
  }) => throw UnimplementedError('Not exercised by login_screen_test.dart');

  @override
  Future<void> refresh() =>
      throw UnimplementedError('Not exercised by login_screen_test.dart');

  @override
  Future<void> logout() =>
      throw UnimplementedError('Not exercised by login_screen_test.dart');
}

Widget _wrap(AuthRepository fakeRepository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
    child: const MaterialApp(home: LoginScreen()),
  );
}

Future<void> _enterCredentials(
  WidgetTester tester, {
  String email = 'user@example.com',
  String password = 'correct-horse-battery-staple',
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
}

void main() {
  setUp(() {
    // SessionNotifier.build() (Part P-021a) reads SecureTokenStorage on
    // provider initialization — mock the underlying plugin channel so
    // that resolves to "no token" (unauthenticated) with no real device
    // storage involved, per P-020/P-021a's own established test
    // convention. secureTokenStorageProvider itself is deliberately NOT
    // overridden — the real provider naturally returns null against this
    // mocked-empty backing store.
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('LoginScreen — local validation', () {
    testWidgets(
      'shows a required-field error for both fields on an empty submit, '
      'without calling the repository',
      (tester) async {
        final fakeRepo = _FakeAuthRepository();
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(AppButton));
        await tester.pumpAndSettle();

        expect(find.text('Email is required.'), findsOneWidget);
        expect(find.text('Password is required.'), findsOneWidget);
        expect(fakeRepo.loginCallCount, 0);
      },
    );

    testWidgets(
      'shows a format error for an invalid email, without calling the '
      'repository',
      (tester) async {
        final fakeRepo = _FakeAuthRepository();
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterCredentials(tester, email: 'not-an-email');
        await tester.tap(find.byType(AppButton));
        await tester.pumpAndSettle();

        expect(find.text('Enter a valid email address.'), findsOneWidget);
        expect(fakeRepo.loginCallCount, 0);
      },
    );
  });

  group('LoginScreen — submitting', () {
    testWidgets(
      'a valid submit calls AuthRepository.login with the trimmed email '
      'and shows a loading indicator while the request is in flight',
      (tester) async {
        final completer = Completer<void>();
        final fakeRepo = _FakeAuthRepository(
          loginBehavior: () => completer.future,
        );
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterCredentials(
          tester,
          email: '  user@example.com  ',
          password: 'correct-horse-battery-staple',
        );
        await tester.tap(find.byType(AppButton));
        await tester.pump(); // one frame — do NOT settle, request is stuck

        expect(fakeRepo.loginCallCount, 1);
        expect(fakeRepo.lastEmail, 'user@example.com'); // trimmed
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        completer.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'a ValidationFailure with an email field error is shown under the '
      'email field',
      (tester) async {
        final fakeRepo = _FakeAuthRepository(
          loginBehavior:
              () =>
                  throw const ValidationFailure(
                    message: 'Invalid data.',
                    fields: {
                      'email': ['No account found with this email.'],
                    },
                  ),
        );
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterCredentials(tester);
        await tester.tap(find.byType(AppButton));
        await tester.pumpAndSettle();

        expect(find.text('No account found with this email.'), findsOneWidget);
      },
    );

    testWidgets(
      'an AuthFailure (bad credentials) is shown as a general error, not '
      'attached to a specific field',
      (tester) async {
        final fakeRepo = _FakeAuthRepository(
          loginBehavior:
              () =>
                  throw const AuthFailure(
                    message: 'Invalid email or password.',
                  ),
        );
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterCredentials(tester);
        await tester.tap(find.byType(AppButton));
        await tester.pumpAndSettle();

        expect(find.text('Invalid email or password.'), findsOneWidget);
      },
    );

    testWidgets(
      're-submitting after fixing a field clears the previous backend '
      'error for that field',
      (tester) async {
        var shouldFail = true;
        final fakeRepo = _FakeAuthRepository(
          loginBehavior: () {
            if (shouldFail) {
              throw const ValidationFailure(
                message: 'Invalid data.',
                fields: {
                  'email': ['No account found with this email.'],
                },
              );
            }
            return Future<void>.value();
          },
        );
        await tester.pumpWidget(_wrap(fakeRepo));
        await tester.pumpAndSettle();

        await _enterCredentials(tester);
        await tester.tap(find.byType(AppButton));
        await tester.pumpAndSettle();
        expect(find.text('No account found with this email.'), findsOneWidget);

        shouldFail = false;
        await tester.tap(find.byType(AppButton));
        await tester.pumpAndSettle();

        expect(find.text('No account found with this email.'), findsNothing);
      },
    );
  });
}
