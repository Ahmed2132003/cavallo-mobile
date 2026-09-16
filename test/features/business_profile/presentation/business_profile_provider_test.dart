import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_repository_impl.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_repository.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_provider.dart';

/// Hand-rolled test double for [BusinessProfileRepository] — this
/// project doesn't use mockito/mocktail anywhere (confirmed against
/// PROJECT_PROGRESS.md's own P-021a note before writing this file); every
/// prior part's provider test either hits a real Dio adapter or
/// hand-rolls a fake, mirroring `FakeAuthRepository`
/// (session_provider_test.dart) exactly.
///
/// Part P-028B addition: [createProfile] is now genuinely exercised
/// (`BusinessProfileNotifier.createProfile`, this part's own addition to
/// `business_profile_provider.dart`), so this fake gained the same
/// injectable-behavior shape `FakeAuthRepository` already uses for
/// `register`/`login` — it no longer just throws `UnimplementedError`.
/// [updateProfile] still throws: Part P-028C's job, per P-028A's own
/// handoff note, unchanged here.
class FakeBusinessProfileRepository implements BusinessProfileRepository {
  FakeBusinessProfileRepository({
    this.fetchResult,
    this.fetchError,
    this.createProfileBehavior,
  });

  /// What [fetchMyProfile] resolves to when [fetchError] is null —
  /// `null` here means "no profile yet" (a valid result, not the
  /// "don't throw" default), matching the real repository's own
  /// 404-to-`null` contract.
  final BusinessProfile? fetchResult;

  /// When non-null, [fetchMyProfile] throws this instead of resolving.
  final Object? fetchError;

  /// Invoked by [createProfile]. Return the [BusinessProfile] to
  /// "create," or `throw` an [ApiFailure]-shaped object to simulate a
  /// backend rejection. `null` (the default) returns a fixed successful
  /// [BusinessProfile].
  final Future<BusinessProfile> Function()? createProfileBehavior;

  int createProfileCallCount = 0;
  String? lastBusinessName;
  BusinessType? lastBusinessType;
  String? lastCountry;
  String? lastCity;
  String? lastDescription;
  int? lastCategoryId;
  String? lastPhoneNumber;

  static const _defaultCreatedProfile = BusinessProfile(
    id: 42,
    businessName: 'Created Business',
    businessType: BusinessType.trader,
    country: 'Egypt',
    city: 'Cairo',
    isVerified: false,
  );

  @override
  Future<BusinessProfile?> fetchMyProfile() async {
    if (fetchError != null) {
      throw fetchError!;
    }
    return fetchResult;
  }

  @override
  Future<BusinessProfile> createProfile({
    required String businessName,
    required BusinessType businessType,
    required String country,
    required String city,
    String? description,
    int? categoryId,
    String? phoneNumber,
  }) async {
    createProfileCallCount++;
    lastBusinessName = businessName;
    lastBusinessType = businessType;
    lastCountry = country;
    lastCity = city;
    lastDescription = description;
    lastCategoryId = categoryId;
    lastPhoneNumber = phoneNumber;
    if (createProfileBehavior != null) {
      return createProfileBehavior!();
    }
    return _defaultCreatedProfile;
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
  }) {
    throw UnimplementedError(
      'Not exercised by BusinessProfileNotifier in this part — see this '
      "file's/business_profile_provider.dart's own scope note (P-028C's "
      'job).',
    );
  }
}

const _profile = BusinessProfile(
  id: 7,
  businessName: 'Al Ananka Store',
  businessType: BusinessType.trader,
  country: 'Egypt',
  city: 'Cairo',
  isVerified: true,
);

void main() {
  group('BusinessProfileNotifier.build', () {
    test('resolves to the fetched BusinessProfile when one exists', () async {
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(
            FakeBusinessProfileRepository(fetchResult: _profile),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(businessProfileProvider.future);

      expect(result, _profile);
      expect(
        container.read(businessProfileProvider),
        const AsyncData<BusinessProfile?>(_profile),
      );
    });

    test('resolves to AsyncData(null) — not AsyncError — when the '
        'repository reports no profile yet', () async {
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(
            FakeBusinessProfileRepository(fetchResult: null),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(businessProfileProvider.future);

      expect(result, isNull);
      final state = container.read(businessProfileProvider);
      expect(state, const AsyncData<BusinessProfile?>(null));
      expect(state.hasError, isFalse);
    });

    test('a genuine repository failure becomes AsyncError, distinct from '
        'the "no profile yet" null state', () async {
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(
            FakeBusinessProfileRepository(
              fetchError: Exception('network down'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Listen so the provider actually builds and settles into an
      // AsyncError, mirroring how a real widget would react to it.
      container.listen(
        businessProfileProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(businessProfileProvider);
      expect(state.hasError, isTrue);
      expect(state.hasValue, isFalse);
    });
  });

  group('BusinessProfileNotifier.createProfile (Part P-028B)', () {
    test('on success, forwards every argument to the repository and '
        'transitions state to AsyncData(theCreatedProfile)', () async {
      final fakeRepo = FakeBusinessProfileRepository(fetchResult: null);
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // Let build() settle first (no profile yet), mirroring the real
      // onboarding flow's starting state.
      await container.read(businessProfileProvider.future);

      await container
          .read(businessProfileProvider.notifier)
          .createProfile(
            businessName: 'New Biz',
            businessType: BusinessType.factory,
            country: 'Egypt',
            city: 'Giza',
            description: 'A factory',
            categoryId: 3,
            phoneNumber: '+201001234567',
          );

      expect(fakeRepo.createProfileCallCount, 1);
      expect(fakeRepo.lastBusinessName, 'New Biz');
      expect(fakeRepo.lastBusinessType, BusinessType.factory);
      expect(fakeRepo.lastCountry, 'Egypt');
      expect(fakeRepo.lastCity, 'Giza');
      expect(fakeRepo.lastDescription, 'A factory');
      expect(fakeRepo.lastCategoryId, 3);
      expect(fakeRepo.lastPhoneNumber, '+201001234567');

      final state = container.read(businessProfileProvider);
      expect(
        state,
        const AsyncData<BusinessProfile?>(
          FakeBusinessProfileRepository._defaultCreatedProfile,
        ),
      );
    });

    test('sets state to AsyncLoading synchronously before the repository '
        'call resolves', () async {
      final fakeRepo = FakeBusinessProfileRepository(fetchResult: null);
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(businessProfileProvider.future);

      final future = container
          .read(businessProfileProvider.notifier)
          .createProfile(
            businessName: 'New Biz',
            businessType: BusinessType.trader,
            country: 'Egypt',
            city: 'Cairo',
          );

      expect(container.read(businessProfileProvider).isLoading, isTrue);
      await future;
    });

    test('on failure, state becomes AsyncError (carrying the original '
        'exception), and that same exception is rethrown to the caller', () async {
      final failure = Exception('validation failed');
      final fakeRepo = FakeBusinessProfileRepository(
        fetchResult: null,
        createProfileBehavior: () async => throw failure,
      );
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(businessProfileProvider.future);

      await expectLater(
        container
            .read(businessProfileProvider.notifier)
            .createProfile(
              businessName: 'New Biz',
              businessType: BusinessType.trader,
              country: 'Egypt',
              city: 'Cairo',
            ),
        throwsA(same(failure)),
      );

      final state = container.read(businessProfileProvider);
      expect(state.hasError, isTrue);
      expect(state.error, same(failure));
      // NOT `expect(state.hasValue, isFalse)`: Riverpod's own
      // AsyncNotifier state setter automatically runs the assigned
      // AsyncError through `.copyWithPrevious(oldState)` when it
      // transitions through AsyncLoading()/AsyncError() — this is
      // documented framework behavior (it's what lets `state.value`
      // keep returning "the last known good value" during a failed
      // refresh, for stale-while-revalidate UIs), not something
      // `BusinessProfileNotifier.createProfile` opts into or controls.
      // Because `build()` had already resolved to `AsyncData(null)`
      // before this call, the previous "known good value" is `null`
      // itself — so `state.hasValue` is `true` here, simultaneously
      // with `state.hasError` being `true`. Asserting `hasValue ==
      // false` was asserting against Riverpod's own semantics, not
      // against this part's code; `error` identity (checked above) is
      // the correct, unambiguous check for "did the call fail with the
      // original exception." (`valueOrNull` isn't used here — it isn't
      // exposed as a getter on this project's pinned `flutter_riverpod`
      // version, confirmed via `flutter analyze` on the real machine —
      // `hasError`/`error` already say everything this test needs.)
    });
  });

  test('businessProfileRepositoryProvider is overridable with zero feature '
      'code, per this project\'s established provider convention', () {
    final container = ProviderContainer(
      overrides: [
        businessProfileRepositoryProvider.overrideWithValue(
          FakeBusinessProfileRepository(fetchResult: null),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(businessProfileRepositoryProvider),
      isA<BusinessProfileRepository>(),
    );
  });
}