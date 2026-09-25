import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/login_screen.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_onboarding_screen.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_edit_screen.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_provider.dart';
import 'package:social_commerce_app/features/feed/presentation/home_feed_screen.dart';
import 'package:social_commerce_app/main.dart';
import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-028C1 scope: router tests for the new, second,
/// Business-account-specific gate added to `app_router.dart`'s
/// `redirect` callback — layered on top of the base P-021b auth gate,
/// which is only smoke-tested here (one regression case), not re-tested
/// in full (that stays `test/routing/app_router_test.dart`'s job).
///
/// Both [sessionProvider] and [businessProfileProvider] are overridden
/// directly at the `AsyncNotifierProvider` level with hand-rolled fake
/// `AsyncNotifier` subclasses (this project's established convention —
/// no mockito/mocktail anywhere, confirmed against
/// `session_provider_test.dart` / `business_profile_provider_test.dart`,
/// Parts P-021a/P-028A) — NOT by faking `AuthRepository`/
/// `BusinessProfileRepository` two layers down, since these tests only
/// need to control the two providers' *state*, not exercise their real
/// `build()` HTTP-calling bodies at all.
///
/// ### Part P-028C2 addition — 2 new cases at the end of the group
///
/// The edit route's own reachability, and confirmation that adding it
/// did not disturb the P-028C1 gate above it. See those two tests'
/// own descriptions for what each proves.
void main() {
  group('app_router.dart — Business-account gate (Part P-028C1)', () {
    testWidgets('regression: an unauthenticated user is still handled by the '
        'existing P-021 auth guard (bounced to /login)', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => _FakeSessionNotifier(null)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SocialCommerceApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('a Customer-type authenticated user is NOT subjected to the '
        'BusinessProfile gate at all — lands on /home, and '
        'businessProfileProvider.build() is never invoked', (tester) async {
      final buildCalls = _CallCounter();
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(
            () => _FakeSessionNotifier(
              const User(
                id: 1,
                email: 'customer@example.com',
                accountType: AccountType.customer,
                isModerator: false,
                isStaff: false,
              ),
            ),
          ),
          businessProfileProvider.overrideWith(
            () => _FakeBusinessProfileNotifier(null, buildCalls: buildCalls),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SocialCommerceApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeFeedScreen), findsOneWidget);
      expect(
        buildCalls.count,
        0,
        reason:
            'businessProfileProvider must never be subscribed to / built '
            'for a Customer-type session — see _SessionRefreshListenable\'s '
            'docstring in app_router.dart for why.',
      );
    });

    testWidgets('an authenticated Business-type user with NO BusinessProfile '
        '(businessProfileProvider resolves to null) is redirected to '
        'onboarding on cold start, and stays there even when it '
        'explicitly attempts to reach /home', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(
            () => _FakeSessionNotifier(
              const User(
                id: 2,
                email: 'trader@example.com',
                accountType: AccountType.business,
                isModerator: false,
                isStaff: false,
              ),
            ),
          ),
          businessProfileProvider.overrideWith(
            () => _FakeBusinessProfileNotifier(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SocialCommerceApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(BusinessOnboardingScreen),
        findsOneWidget,
        reason: 'cold start should land straight on onboarding, not /home',
      );

      // Acceptance criterion, literal wording: "cannot reach /home ...
      // and is redirected to onboarding" — explicit navigation attempt,
      // not just the cold-start redirect above.
      container.read(appRouterProvider).goNamed(RouteNames.home);
      await tester.pumpAndSettle();

      expect(
        find.byType(HomeScreen),
        findsNothing,
        reason: 'a Business user with no profile must never reach /home',
      );
      expect(find.byType(BusinessOnboardingScreen), findsOneWidget);
    });

    testWidgets(
      'a Business-type user WITH a BusinessProfile is NOT redirected to '
      'onboarding — reaches /home normally',
      (tester) async {
        const profile = BusinessProfile(
          id: 1,
          businessName: 'Ahmed Trading Co.',
          businessType: BusinessType.trader,
          country: 'Egypt',
          city: 'Cairo',
          isVerified: false,
        );
        final container = ProviderContainer(
          overrides: [
            sessionProvider.overrideWith(
              () => _FakeSessionNotifier(
                const User(
                  id: 3,
                  email: 'onboarded@example.com',
                  accountType: AccountType.business,
                  isModerator: false,
                  isStaff: false,
                ),
              ),
            ),
            businessProfileProvider.overrideWith(
              () => _FakeBusinessProfileNotifier(profile),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const SocialCommerceApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(BusinessOnboardingScreen), findsNothing);
      },
    );

    testWidgets('the onboarding route does not redirect back to itself (or '
        'anywhere else) when the BusinessProfile is missing — no '
        'redirect loop', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(
            () => _FakeSessionNotifier(
              const User(
                id: 4,
                email: 'trader2@example.com',
                accountType: AccountType.business,
                isModerator: false,
                isStaff: false,
              ),
            ),
          ),
          businessProfileProvider.overrideWith(
            () => _FakeBusinessProfileNotifier(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SocialCommerceApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Already on onboarding from the cold-start redirect (previous
      // test covers that path explicitly) — navigate to it directly
      // too, to prove the gate's `location != businessOnboardingPath`
      // check actually holds and doesn't loop.
      container.read(appRouterProvider).goNamed(RouteNames.businessOnboarding);
      await tester.pumpAndSettle();

      expect(find.byType(BusinessOnboardingScreen), findsOneWidget);
    });

    // --- Part P-028C2 additions below — see this file's module ---
    // --- docstring for what each proves.                        ---

    testWidgets(
      'the business profile edit route is directly reachable for a '
      'Business-type user WITH a BusinessProfile (Part P-028C2)',
      (tester) async {
        const profile = BusinessProfile(
          id: 5,
          businessName: 'Reachable Co.',
          businessType: BusinessType.trader,
          country: 'Egypt',
          city: 'Cairo',
          isVerified: true,
        );
        final container = ProviderContainer(
          overrides: [
            sessionProvider.overrideWith(
              () => _FakeSessionNotifier(
                const User(
                  id: 5,
                  email: 'edit@example.com',
                  accountType: AccountType.business,
                  isModerator: false,
                  isStaff: false,
                ),
              ),
            ),
            businessProfileProvider.overrideWith(
              () => _FakeBusinessProfileNotifier(profile),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const SocialCommerceApp(),
          ),
        );
        await tester.pumpAndSettle();

        container
            .read(appRouterProvider)
            .goNamed(RouteNames.businessProfileEdit);
        await tester.pumpAndSettle();

        expect(find.byType(BusinessProfileEditScreen), findsOneWidget);
      },
    );

    testWidgets(
      'a Business-type user with NO profile who navigates directly to '
      'the edit route is redirected to onboarding instead — the '
      'P-028C1 gate stays intact after the edit route was added '
      '(Part P-028C2)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            sessionProvider.overrideWith(
              () => _FakeSessionNotifier(
                const User(
                  id: 6,
                  email: 'noprofile2@example.com',
                  accountType: AccountType.business,
                  isModerator: false,
                  isStaff: false,
                ),
              ),
            ),
            businessProfileProvider.overrideWith(
              () => _FakeBusinessProfileNotifier(null),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const SocialCommerceApp(),
          ),
        );
        await tester.pumpAndSettle();

        container
            .read(appRouterProvider)
            .goNamed(RouteNames.businessProfileEdit);
        await tester.pumpAndSettle();

        expect(find.byType(BusinessOnboardingScreen), findsOneWidget);
        expect(find.byType(BusinessProfileEditScreen), findsNothing);
      },
    );
  });
}

/// Hand-rolled fake — overrides only `build()`, per this project's
/// established convention (Part P-021a's `session_provider_test.dart`
/// uses the equivalent pattern against a `FakeAuthRepository` instead;
/// here it's simpler to fake the notifier itself directly, since these
/// tests only need to control [sessionProvider]'s *state*, not exercise
/// `SessionNotifier.login`/`register`/`logout` at all).
class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._initial);

  final User? _initial;

  @override
  Future<User?> build() async => _initial;
}

/// Same pattern as [_FakeSessionNotifier], for [businessProfileProvider].
/// [buildCalls], when supplied, is incremented every time `build()` runs
/// — used by the Customer-gate test above to assert this provider is
/// never even subscribed to for a Customer-type session (see
/// `app_router.dart`'s `_SessionRefreshListenable` docstring for why
/// that matters beyond just "the redirect `if` never fires").
class _FakeBusinessProfileNotifier extends BusinessProfileNotifier {
  _FakeBusinessProfileNotifier(this._initial, {_CallCounter? buildCalls})
    : _buildCalls = buildCalls;

  final BusinessProfile? _initial;
  final _CallCounter? _buildCalls;

  @override
  Future<BusinessProfile?> build() async {
    _buildCalls?.count += 1;
    return _initial;
  }
}

class _CallCounter {
  int count = 0;
}