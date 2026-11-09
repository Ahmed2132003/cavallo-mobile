import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/auth/presentation/forgot_password_provider.dart';
import 'package:social_commerce_app/features/auth/presentation/forgot_password_screens.dart';

import 'golden_helpers.dart';

/// Goldens of the three forgot-password screens in light_en, light_ar,
/// dark_en and dark_ar (the same four combos as every other golden file).
/// Images live in `test/goldens/p116_forgot_password/` and are created with
/// `flutter test --update-goldens` on THIS file only.
///
/// Offline and deterministic: the flow state is seeded (no timer runs, the
/// cooldown is a fixed number) and no field has focus.
const String _dir = 'p116_forgot_password';

class _SeededFlow extends ForgotPasswordNotifier {
  _SeededFlow(this._seed);

  final ForgotPasswordState _seed;

  @override
  ForgotPasswordState build() {
    super.build();
    return _seed;
  }
}

dynamic _seeded(ForgotPasswordState seed) =>
    forgotPasswordProvider.overrideWith(() => _SeededFlow(seed));

void main() {
  group('P-116 forgot-password goldens', () {
    for (final GoldenCombo c in kGoldenCombos) {
      testWidgets('step 1 email (${c.tag})', (tester) async {
        await pumpGoldenApp(
          tester,
          c,
          const ForgotPasswordEmailScreen(),
          overrides: [
            _seeded(const ForgotPasswordState(email: 'user@example.com')),
          ],
        );
        await expectGolden(_dir, 'forgot_email', c);
        await unmountGolden(tester);
      });

      testWidgets('step 2 code (${c.tag})', (tester) async {
        await pumpGoldenApp(
          tester,
          c,
          const ForgotPasswordOtpScreen(),
          overrides: [
            _seeded(
              const ForgotPasswordState(
                step: ForgotPasswordStep.otp,
                email: 'user@example.com',
                resendCooldownSeconds: 42,
              ),
            ),
          ],
        );
        await expectGolden(_dir, 'forgot_otp', c);
        await unmountGolden(tester);
      });

      testWidgets('step 3 new password (${c.tag})', (tester) async {
        await pumpGoldenApp(
          tester,
          c,
          const ForgotPasswordNewPasswordScreen(),
          overrides: [
            _seeded(
              const ForgotPasswordState(
                step: ForgotPasswordStep.newPassword,
                email: 'user@example.com',
              ),
            ),
          ],
        );
        await expectGolden(_dir, 'forgot_new_password', c);
        await unmountGolden(tester);
      });
    }
  });
}
