import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/auth/data/auth_repository_impl.dart';
import 'package:social_commerce_app/features/auth/domain/auth_repository.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/login_screen.dart';
import 'package:social_commerce_app/features/auth/presentation/register_screen.dart';
import 'package:social_commerce_app/features/auth/presentation/splash_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-112 STEP 6: login, register and splash in BOTH languages and BOTH
/// directions, and the rule that a raw backend sentence is never shown.
///
/// ASCII only on purpose: Arabic text is a \uXXXX escape.
const String _backendSentence = 'Backend English sentence.';

/// A repository whose every call fails with [failure].
class _FailingRepository implements AuthRepository {
  _FailingRepository(this.failure);

  final ApiFailure failure;

  @override
  Future<void> login({required String email, required String password}) async =>
      throw failure;

  @override
  Future<User> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required AccountType accountType,
  }) async => throw failure;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<User> fetchMe() async => throw failure;
}

Widget _app(Widget home, Locale locale, {ApiFailure? failure}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        _FailingRepository(
          failure ?? const UnknownFailure(message: _backendSentence),
        ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

TextDirection _direction(WidgetTester tester, Type screen) =>
    Directionality.of(tester.element(find.byType(screen)));

Future<void> _fillLogin(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'user@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'secret-password');
}

Future<void> _fillRegister(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'new@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'secret-password');
  await tester.enterText(find.byType(TextFormField).at(2), 'secret-password');
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('LoginScreen', () {
    testWidgets('English: texts and left-to-right', (tester) async {
      await tester.pumpWidget(_app(const LoginScreen(), const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
      expect(find.text('Don\'t have an account? Register'), findsOneWidget);
      expect(_direction(tester, LoginScreen), TextDirection.ltr);
    });

    testWidgets('Arabic: texts and right-to-left', (tester) async {
      await tester.pumpWidget(_app(const LoginScreen(), const Locale('ar')));
      await tester.pumpAndSettle();

      // The app bar title and the submit button read the same in Arabic.
      expect(find.text('\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644'), findsNWidgets(2));
      expect(find.text('\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a'), findsOneWidget);
      expect(find.text('\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631'), findsOneWidget);
      expect(find.text('\u0644\u064a\u0633 \u0644\u062f\u064a\u0643 \u062d\u0633\u0627\u0628\u061f \u0623\u0646\u0634\u0626 \u062d\u0633\u0627\u0628\u064b\u0627'), findsOneWidget);
      expect(_direction(tester, LoginScreen), TextDirection.rtl);
    });

    testWidgets('Arabic: local validation messages', (tester) async {
      await tester.pumpWidget(_app(const LoginScreen(), const Locale('ar')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a \u0645\u0637\u0644\u0648\u0628.'), findsOneWidget);
      expect(find.text('\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631 \u0645\u0637\u0644\u0648\u0628\u0629.'), findsOneWidget);
    });

    for (final (Locale locale, String expected) in <(Locale, String)>[
      (const Locale('en'), 'This email address cannot be used. Please check it or try another one.'),
      (const Locale('ar'), '\u0644\u0627 \u064a\u0645\u0643\u0646 \u0627\u0633\u062a\u062e\u062f\u0627\u0645 \u0647\u0630\u0627 \u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a. \u062a\u062d\u0642\u0642 \u0645\u0646\u0647 \u0623\u0648 \u062c\u0631\u0651\u0628 \u0628\u0631\u064a\u062f\u064b\u0627 \u0622\u062e\u0631.'),
    ]) {
      testWidgets(
        '${locale.languageCode}: a backend field sentence is replaced by the '
        'localized field message',
        (tester) async {
          await tester.pumpWidget(
            _app(
              const LoginScreen(),
              locale,
              failure: const ValidationFailure(
                message: _backendSentence,
                fields: {
                  'email': [_backendSentence],
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          await _fillLogin(tester);
          await tester.tap(find.byType(AppButton));
          await tester.pumpAndSettle();

          expect(find.text(expected), findsOneWidget);
          expect(find.text(_backendSentence), findsNothing);
        },
      );
    }

    for (final (Locale locale, String expected) in <(Locale, String)>[
      (const Locale('en'), 'Invalid email or password.'),
      (const Locale('ar'), '\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a \u0623\u0648 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631 \u063a\u064a\u0631 \u0635\u062d\u064a\u062d\u0629.'),
    ]) {
      testWidgets(
        '${locale.languageCode}: refused credentials show the localized '
        'message, not the backend text',
        (tester) async {
          await tester.pumpWidget(
            _app(
              const LoginScreen(),
              locale,
              failure: const AuthFailure(message: _backendSentence),
            ),
          );
          await tester.pumpAndSettle();

          await _fillLogin(tester);
          await tester.tap(find.byType(AppButton));
          await tester.pumpAndSettle();

          expect(find.text(expected), findsOneWidget);
          expect(find.text(_backendSentence), findsNothing);
        },
      );
    }
  });

  group('RegisterScreen', () {
    testWidgets('English: texts and left-to-right', (tester) async {
      await tester.pumpWidget(
        _app(const RegisterScreen(), const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.text('Account type'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(_direction(tester, RegisterScreen), TextDirection.ltr);
    });

    testWidgets('Arabic: texts and right-to-left', (tester) async {
      await tester.pumpWidget(
        _app(const RegisterScreen(), const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('\u0625\u0646\u0634\u0627\u0621 \u062d\u0633\u0627\u0628'), findsOneWidget);
      expect(find.text('\u062a\u0623\u0643\u064a\u062f \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631'), findsOneWidget);
      expect(find.text('\u0646\u0648\u0639 \u0627\u0644\u062d\u0633\u0627\u0628'), findsOneWidget);
      expect(find.text('\u0639\u0645\u064a\u0644'), findsOneWidget);
      expect(find.text('\u0646\u0634\u0627\u0637 \u062a\u062c\u0627\u0631\u064a'), findsOneWidget);
      expect(find.text('\u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u062d\u0633\u0627\u0628'), findsOneWidget);
      expect(find.text('\u0644\u062f\u064a\u0643 \u062d\u0633\u0627\u0628 \u0628\u0627\u0644\u0641\u0639\u0644\u061f \u0633\u062c\u0651\u0644 \u0627\u0644\u062f\u062e\u0648\u0644'), findsOneWidget);
      expect(_direction(tester, RegisterScreen), TextDirection.rtl);
    });

    testWidgets('Arabic: the passwords-do-not-match message', (tester) async {
      await tester.pumpWidget(
        _app(const RegisterScreen(), const Locale('ar')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'new@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'one-password');
      await tester.enterText(find.byType(TextFormField).at(2), 'two-password');
      await tester.tap(find.widgetWithText(AppButton, '\u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u062d\u0633\u0627\u0628'));
      await tester.pumpAndSettle();

      expect(find.text('\u0643\u0644\u0645\u062a\u0627 \u0627\u0644\u0645\u0631\u0648\u0631 \u063a\u064a\u0631 \u0645\u062a\u0637\u0627\u0628\u0642\u062a\u064a\u0646.'), findsOneWidget);
    });

    for (final (Locale locale, String expected) in <(Locale, String)>[
      (const Locale('en'), 'Something went wrong on our end. Please try again later.'),
      (const Locale('ar'), '\u062d\u062f\u062b \u062e\u0637\u0623 \u0645\u0646 \u062c\u0627\u0646\u0628\u0646\u0627. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649 \u0644\u0627\u062d\u0642\u064b\u0627.'),
    ]) {
      testWidgets(
        '${locale.languageCode}: a server failure shows the localized '
        'message, not the backend text',
        (tester) async {
          await tester.pumpWidget(
            _app(
              const RegisterScreen(),
              locale,
              failure: const ServerFailure(message: _backendSentence),
            ),
          );
          await tester.pumpAndSettle();

          await _fillRegister(tester);
          await tester.tap(find.byType(AppButton));
          await tester.pumpAndSettle();

          expect(find.text(expected), findsOneWidget);
          expect(find.text(_backendSentence), findsNothing);
        },
      );
    }

    testWidgets('Arabic: a rejected account type shows the localized message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const RegisterScreen(),
          const Locale('ar'),
          failure: const ValidationFailure(
            message: _backendSentence,
            fields: {
              'account_type': [_backendSentence],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillRegister(tester);
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('\u064a\u0631\u062c\u0649 \u0627\u062e\u062a\u064a\u0627\u0631 \u0646\u0648\u0639 \u062d\u0633\u0627\u0628 \u0635\u0627\u0644\u062d.'), findsOneWidget);
      expect(find.text(_backendSentence), findsNothing);
    });
  });

  group('SplashScreen', () {
    testWidgets('Arabic: texts and right-to-left', (tester) async {
      await tester.pumpWidget(_app(const SplashScreen(), const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('\u0645\u0646\u0635\u0629 \u0627\u0643\u062a\u0634\u0627\u0641 \u0627\u0644\u062a\u062c\u0627\u0631 \u0648\u0627\u0644\u0645\u0635\u0627\u0646\u0639'), findsOneWidget);
      expect(find.text('\u062c\u0627\u0631\u064d \u0627\u0644\u062a\u062d\u0645\u064a\u0644...'), findsOneWidget);
      expect(find.text('\u0627\u0644\u0627\u0646\u062a\u0642\u0627\u0644 \u0625\u0644\u0649 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644'), findsOneWidget);
      expect(_direction(tester, SplashScreen), TextDirection.rtl);
    });
  });
}
