import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_commerce_app/core/storage/secure_token_storage.dart';
import 'package:social_commerce_app/features/auth/presentation/login_screen.dart';
import 'package:social_commerce_app/main.dart';

/// Test-only [SecureTokenStorage] that never touches the real
/// `flutter_secure_storage` plugin.
///
/// The default [SecureTokenStorage] talks to the platform's Keychain
/// (iOS/macOS) or KeyStore (Android) via a platform channel. Under plain
/// `flutter test` (no real device/simulator attached), that channel never
/// replies — so `getAccessToken()` never completes, `sessionProvider`
/// stays `AsyncLoading` forever, `main.dart`'s bootstrap spinner (Part
/// P-021b) keeps animating forever, and `pumpAndSettle()` times out. This
/// subclass overrides every method so no call ever reaches the real
/// `_storage` field from the base class, letting the cold-start restore
/// resolve immediately to "no token" (i.e. signed out).
class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('App boots signed-out and lands on LoginScreen', (
    WidgetTester tester,
  ) async {
    // Updated in Part P-021b. Before this part, an unauthenticated cold
    // start parked on P-007's placeholder `SplashScreen` (asserted via
    // the text "Route: splash") because the router's redirect guard was
    // still a stub. Now that the guard is wired to the real
    // `sessionProvider`, a signed-out cold start bounces straight to
    // `/login` — see app_router.dart's redirect callback and its
    // class-level doc. Asserting the old splash text here would now be
    // asserting the *wrong* (pre-P-021b) behavior.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureTokenStorageProvider.overrideWithValue(
            _FakeSecureTokenStorage(),
          ),
        ],
        child: const SocialCommerceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
