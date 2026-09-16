import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_repository_impl.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_repository.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_onboarding_screen.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Hand-rolled fake, matching this project's existing test convention (no
/// mockito/mocktail anywhere — Part P-021a's/P-021c's own test files).
/// `fetchMyProfile` always resolves to `null` — this screen never reads
/// `businessProfileProvider`'s own build() result, only its `.notifier`,
/// so this fake's fetch side only needs to satisfy the provider's own
/// `build()` without erroring.
class _FakeBusinessProfileRepository implements BusinessProfileRepository {
  _FakeBusinessProfileRepository({this.createProfileBehavior});

  final Future<BusinessProfile> Function({
    required String businessName,
    required BusinessType businessType,
    required String country,
    required String city,
    String? description,
    int? categoryId,
    String? phoneNumber,
  })?
  createProfileBehavior;

  int createProfileCallCount = 0;
  String? lastBusinessName;
  BusinessType? lastBusinessType;
  String? lastCountry;
  String? lastCity;
  String? lastDescription;
  String? lastPhoneNumber;

  static const _defaultCreatedProfile = BusinessProfile(
    id: 1,
    businessName: 'Created Business',
    businessType: BusinessType.trader,
    country: 'Egypt',
    city: 'Cairo',
    isVerified: false,
  );

  @override
  Future<BusinessProfile?> fetchMyProfile() async => null;

  @override
  Future<BusinessProfile> createProfile({
    required String businessName,
    required BusinessType businessType,
    required String country,
    required String city,
    String? description,
    int? categoryId,
    String? phoneNumber,
  }) {
    createProfileCallCount++;
    lastBusinessName = businessName;
    lastBusinessType = businessType;
    lastCountry = country;
    lastCity = city;
    lastDescription = description;
    lastPhoneNumber = phoneNumber;
    if (createProfileBehavior != null) {
      return createProfileBehavior!(
        businessName: businessName,
        businessType: businessType,
        country: country,
        city: city,
        description: description,
        categoryId: categoryId,
        phoneNumber: phoneNumber,
      );
    }
    return Future.value(_defaultCreatedProfile);
  }

  @override
  Future<BusinessProfile> updateProfile({
    String? businessName,
    BusinessType? businessType,
    String? country,
    String? city,
    Patchable<String> description = const Patchable.unset(),
    Patchable<int> categoryId = const Patchable.unset(),
    Patchable<String> phoneNumber = const Patchable.unset(),
  }) => throw UnimplementedError(
    'Not exercised by business_onboarding_screen_test.dart',
  );
}

/// [GoRouter]-backed harness — needed because the screen itself calls
/// `context.goNamed(RouteNames.home)` on a successful submit (see this
/// screen's own class docstring, point 7 — there is no router redirect
/// guard to rely on yet, unlike LoginScreen/RegisterScreen).
Widget _wrapWithRouter(BusinessProfileRepository fakeRepository) {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'businessOnboarding',
        builder: (context, state) => const BusinessOnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.homePath,
        name: RouteNames.home,
        builder: (context, state) =>
            const Scaffold(body: Text('HOME_SCREEN_PLACEHOLDER')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      businessProfileRepositoryProvider.overrideWithValue(fakeRepository),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Finder _phoneTextField() => find.descendant(
  of: find.byType(IntlPhoneField),
  matching: find.byType(TextFormField),
);

Future<void> _fillRequiredFields(
  WidgetTester tester, {
  String businessName = 'Al Ananka Store',
  String country = 'Egypt',
  String city = 'Cairo',
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), businessName);
  // Index 1 is the SegmentedButton (not a TextFormField) — index 1 and 2
  // among TextFormFields are Country/City, index 3 is the IntlPhoneField's
  // internal TextFormField, index 4 is Description.
  await tester.enterText(find.byType(TextFormField).at(1), country);
  await tester.enterText(find.byType(TextFormField).at(2), city);
}

/// The form is taller than the default 800x600 test surface (business
/// name, business type, country, city, an [IntlPhoneField], and a
/// multiline description all stack inside a [SingleChildScrollView]), so
/// the "Complete profile" button is off-screen until scrolled into view.
/// `tester.tap()` computes the tap point from the widget's *current*
/// render-tree position — if that position is still below the visible
/// viewport, the synthetic pointer event lands outside the root render
/// view's bounds and never reaches the button's gesture detector at all
/// (confirmed on the real machine: `flutter test` reported "Offset(...)
/// is outside the bounds of the root of the render tree" on every one of
/// these taps). `ensureVisible` scrolls the nearest `Scrollable` ancestor
/// until the target is actually on-screen before we tap it — this is a
/// test-harness fix, not a production-code one: the screen's own
/// `SingleChildScrollView` is correct as written.
Future<void> _tapCompleteProfile(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Complete profile'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Complete profile'));
  await tester.pumpAndSettle();
}

void main() {
  group('BusinessOnboardingScreen — required-field validation', () {
    testWidgets(
      'shows an error for each missing required field and never calls '
      'the repository',
      (tester) async {
        final fakeRepo = _FakeBusinessProfileRepository();
        await tester.pumpWidget(_wrapWithRouter(fakeRepo));
        await tester.pumpAndSettle();

        await _tapCompleteProfile(tester);

        expect(find.text('Business name is required.'), findsOneWidget);
        expect(find.text('Country is required.'), findsOneWidget);
        expect(find.text('City is required.'), findsOneWidget);
        expect(fakeRepo.createProfileCallCount, 0);
      },
    );
  });

  group('BusinessOnboardingScreen — phone number validation', () {
    testWidgets(
      'a malformed phone number blocks submission with a validation '
      'error, and the repository is never called',
      (tester) async {
        final fakeRepo = _FakeBusinessProfileRepository();
        await tester.pumpWidget(_wrapWithRouter(fakeRepo));
        await tester.pumpAndSettle();

        await _fillRequiredFields(tester);
        // Egypt ('EG', the field's default initialCountryCode) requires
        // exactly 10 digits (confirmed directly from intl_phone_field's
        // own countries.dart, not assumed) — 5 digits is deliberately
        // too short.
        await tester.enterText(_phoneTextField(), '12345');
        await tester.pumpAndSettle();

        await _tapCompleteProfile(tester);

        expect(
          find.text('Enter a valid phone number for the selected country.'),
          findsOneWidget,
        );
        expect(fakeRepo.createProfileCallCount, 0);
      },
    );

    testWidgets(
      'leaving the optional phone field untouched does not block '
      'submission',
      (tester) async {
        final fakeRepo = _FakeBusinessProfileRepository();
        await tester.pumpWidget(_wrapWithRouter(fakeRepo));
        await tester.pumpAndSettle();

        await _fillRequiredFields(tester);
        await _tapCompleteProfile(tester);

        expect(fakeRepo.createProfileCallCount, 1);
        expect(fakeRepo.lastPhoneNumber, isNull);
      },
    );
  });

  group('BusinessOnboardingScreen — successful submission', () {
    testWidgets(
      'submits every field to the repository (E.164 phone included) and '
      'navigates to /home',
      (tester) async {
        final fakeRepo = _FakeBusinessProfileRepository();
        await tester.pumpWidget(_wrapWithRouter(fakeRepo));
        await tester.pumpAndSettle();

        await _fillRequiredFields(
          tester,
          businessName: 'Al Ananka Store',
          country: 'Egypt',
          city: 'Cairo',
        );
        await tester.enterText(_phoneTextField(), '1001234567');
        await tester.pumpAndSettle();

        await _tapCompleteProfile(tester);

        expect(fakeRepo.createProfileCallCount, 1);
        expect(fakeRepo.lastBusinessName, 'Al Ananka Store');
        expect(fakeRepo.lastBusinessType, BusinessType.trader);
        expect(fakeRepo.lastCountry, 'Egypt');
        expect(fakeRepo.lastCity, 'Cairo');
        // The package's own completeNumber shape, confirmed from its
        // source: '+' + dialCode + region code + number, no spaces —
        // this is the E.164-formattable value P-027's backend requires.
        expect(fakeRepo.lastPhoneNumber, '+201001234567');

        expect(find.text('HOME_SCREEN_PLACEHOLDER'), findsOneWidget);
      },
    );

    testWidgets('selecting Factory sends BusinessType.factory', (
      tester,
    ) async {
      final fakeRepo = _FakeBusinessProfileRepository();
      await tester.pumpWidget(_wrapWithRouter(fakeRepo));
      await tester.pumpAndSettle();

      await _fillRequiredFields(tester);
      await tester.tap(find.text('Factory'));
      await tester.pumpAndSettle();

      await _tapCompleteProfile(tester);

      expect(fakeRepo.createProfileCallCount, 1);
      expect(fakeRepo.lastBusinessType, BusinessType.factory);
    });
  });

  group('BusinessOnboardingScreen — backend-driven errors', () {
    testWidgets(
      'a ValidationFailure on business_name is shown on that field and '
      'does not navigate away',
      (tester) async {
        final fakeRepo = _FakeBusinessProfileRepository(
          createProfileBehavior: (
              {
                required businessName,
                required businessType,
                required country,
                required city,
                description,
                categoryId,
                phoneNumber,
              }) async {
            throw const ValidationFailure(
              message: 'Something about the request was invalid.',
              fields: {
                'business_name': ['This name is already taken.'],
              },
            );
          },
        );
        await tester.pumpWidget(_wrapWithRouter(fakeRepo));
        await tester.pumpAndSettle();

        await _fillRequiredFields(tester);
        await _tapCompleteProfile(tester);

        expect(find.text('This name is already taken.'), findsOneWidget);
        expect(find.text('HOME_SCREEN_PLACEHOLDER'), findsNothing);
      },
    );

    testWidgets(
      'a ServerFailure shows a general error and does not navigate away',
      (tester) async {
        final fakeRepo = _FakeBusinessProfileRepository(
          createProfileBehavior: (
              {
                required businessName,
                required businessType,
                required country,
                required city,
                description,
                categoryId,
                phoneNumber,
              }) async {
            throw const ServerFailure(message: 'Something went wrong.');
          },
        );
        await tester.pumpWidget(_wrapWithRouter(fakeRepo));
        await tester.pumpAndSettle();

        await _fillRequiredFields(tester);
        await _tapCompleteProfile(tester);

        expect(find.text('Something went wrong.'), findsOneWidget);
        expect(find.text('HOME_SCREEN_PLACEHOLDER'), findsNothing);
      },
    );
  });
}