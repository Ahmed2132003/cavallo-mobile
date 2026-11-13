import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/edit_my_profile_screen.dart';

import 'golden_helpers.dart';

/// Part P-116B: golden of the Edit my profile screen in light_en, light_ar,
/// dark_en, dark_ar. Images: test/goldens/p116_edit_profile/. Offline.

class _FixedSession extends SessionNotifier {
  @override
  Future<User?> build() async => const User(
    id: 1,
    email: 'ahmed@example.com',
    accountType: AccountType.customer,
    isModerator: false,
    isStaff: false,
    displayName: 'Ahmed Ibrahim',
  );
}

void main() {
  group('P-116B edit profile goldens', () {
    for (final GoldenCombo c in kGoldenCombos) {
      testWidgets('edit my profile (${c.tag})', (tester) async {
        await pumpGoldenApp(
          tester,
          c,
          const EditMyProfileScreen(),
          overrides: [sessionProvider.overrideWith(() => _FixedSession())],
        );
        await expectGolden('p116_edit_profile', 'edit_my_profile', c);
        await unmountGolden(tester);
      });
    }
  });
}
