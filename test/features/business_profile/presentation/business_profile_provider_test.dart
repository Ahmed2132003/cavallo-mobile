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
///
/// ### Part P-028C2 addition — [updateProfile] / mutable fetch state
///
/// [updateProfile] is now genuinely exercised too
/// (`BusinessProfileNotifier.updateProfile`/`refreshProfile`, this
/// part's own addition), using the same injectable-behavior shape as
/// [createProfileBehavior] — see [updateProfileBehavior].
///
/// [fetchResult]/[fetchError] moved from constructor-only `final` fields
/// to mutable [currentFetchResult]/[currentFetchError]: [refreshProfile]'s
/// own contract is "re-run the same GET and see whatever it now
/// returns," which isn't exercisable at all from a fake whose fetch
/// result is frozen at construction time. Every pre-existing call site
/// (`FakeBusinessProfileRepository(fetchResult: ..., fetchError: ...)`)
/// is unaffected — the named constructor parameters are unchanged, only
/// where they're stored changed.
class FakeBusinessProfileRepository implements BusinessProfileRepository {
  FakeBusinessProfileRepository({
    BusinessProfile? fetchResult,
    Object? fetchError,
    this.createProfileBehavior,
    this.updateProfileBehavior,
  }) : currentFetchResult = fetchResult,
       currentFetchError = fetchError;

  /// What [fetchMyProfile] resolves to when [currentFetchError] is null
  /// — `null` here means "no profile yet" (a valid result, not the
  /// "don't throw" default), matching the real repository's own
  /// 404-to-`null` contract. Mutable (Part P-028C2) so a test can change
  /// what the "backend" holds between two notifier calls (e.g. before
  /// calling `refreshProfile()`).
  BusinessProfile? currentFetchResult;

  /// When non-null, [fetchMyProfile] throws this instead of resolving.
  /// Mutable for the same reason as [currentFetchResult].
  Object? currentFetchError;

  /// Invoked by [createProfile]. Return the [BusinessProfile] to
  /// "create," or `throw` an [ApiFailure]-shaped object to simulate a
  /// backend rejection. `null` (the default) returns a fixed successful
  /// [BusinessProfile].
  final Future<BusinessProfile> Function()? createProfileBehavior;

  /// Part P-028C2 addition — mirrors [createProfileBehavior]'s exact
  /// shape for [updateProfile]. `null` (the default) applies the patch
  /// on top of [currentFetchResult] and returns the result (and updates
  /// [currentFetchResult] to match, mirroring how a real PATCH persists
  /// server-side) — see [updateProfile]'s own body.
  final Future<BusinessProfile> Function()? updateProfileBehavior;

  int createProfileCallCount = 0;
  String? lastBusinessName;
  BusinessType? lastBusinessType;
  String? lastCountry;
  String? lastCity;
  String? lastDescription;
  int? lastCategoryId;
  String? lastPhoneNumber;

  /// Part P-028C2 addition — same shape as the `create*` fields above,
  /// prefixed `lastUpdate*` so a test exercising both calls in sequence
  /// can tell which call left which trace, rather than one call
  /// silently overwriting the other's recorded arguments.
  int updateProfileCallCount = 0;
  String? lastUpdateBusinessName;
  BusinessType? lastUpdateBusinessType;
  String? lastUpdateCountry;
  String? lastUpdateCity;
  Patchable<String>? lastUpdateDescription;
  Patchable<int>? lastUpdateCategoryId;
  Patchable<String>? lastUpdatePhoneNumber;

  static const _defaultCreatedProfile = BusinessProfile(
    id: 42,
    businessName: 'Created Business',
    businessType: BusinessType.trader,
    country: 'Egypt',
    city: 'Cairo',
    isVerified: false,
  );

  /// Part P-028C2 addition — the fixed profile [updateProfile] returns
  /// when [updateProfileBehavior] is null AND [currentFetchResult] is
  /// itself null (nothing to patch on top of) — kept separate from
  /// [_defaultCreatedProfile] so a test can tell "this came from create"
  /// apart from "this came from update" by identity/equality alone.
  static const _defaultUpdatedProfileWithNoPriorProfile = BusinessProfile(
    id: 99,
    businessName: 'Updated With No Prior Profile',
    businessType: BusinessType.trader,
    country: 'Egypt',
    city: 'Cairo',
    isVerified: false,
  );

  @override
  Future<BusinessProfile?> fetchMyProfile() async {
    if (currentFetchError != null) {
      throw currentFetchError!;
    }
    return currentFetchResult;
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
  }) async {
    updateProfileCallCount++;
    lastUpdateBusinessName = businessName;
    lastUpdateBusinessType = businessType;
    lastUpdateCountry = country;
    lastUpdateCity = city;
    lastUpdateDescription = description;
    lastUpdateCategoryId = categoryId;
    lastUpdatePhoneNumber = phoneNumber;
    if (updateProfileBehavior != null) {
      return updateProfileBehavior!();
    }
    final current = currentFetchResult;
    if (current == null) {
      return _defaultUpdatedProfileWithNoPriorProfile;
    }
    // Applies the patch on top of the previous "server state" and
    // persists it there too — mirrors a real PATCH's effect, and lets a
    // test exercise `refreshProfile()` afterwards and see the same
    // updated value without wiring a second fake.
    final updated = BusinessProfile(
      id: current.id,
      businessName: businessName ?? current.businessName,
      businessType: businessType ?? current.businessType,
      country: country ?? current.country,
      city: city ?? current.city,
      description: description.isSet
          ? (description.value ?? '')
          : current.description,
      phoneNumber: phoneNumber.isSet ? phoneNumber.value : current.phoneNumber,
      categoryId: categoryId.isSet ? categoryId.value : current.categoryId,
      isVerified: current.isVerified,
      followerCount: current.followerCount,
    );
    currentFetchResult = updated;
    return updated;
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
      // See the identical note in this same test's P-028B version of
      // this comment: `state.hasValue` is also `true` here because
      // Riverpod's AsyncNotifier runs the assigned AsyncError through
      // `copyWithPrevious` automatically — this is documented framework
      // behavior, not something this notifier opts into. `error`
      // identity is the correct, unambiguous check here.
    });
  });

  group('BusinessProfileNotifier.updateProfile (Part P-028C2)', () {
    test('on success, forwards every argument — including the Patchable '
        'tri-state fields exactly as passed — to the repository, and '
        'transitions state to AsyncData(theUpdatedProfile)', () async {
      final fakeRepo = FakeBusinessProfileRepository(fetchResult: _profile);
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(businessProfileProvider.future);

      await container
          .read(businessProfileProvider.notifier)
          .updateProfile(
            businessName: 'Renamed Store',
            country: 'Egypt',
            city: 'Alexandria',
            description: const Patchable.value('New description'),
            categoryId: const Patchable.value(5),
            phoneNumber: const Patchable.clear(),
          );

      expect(fakeRepo.updateProfileCallCount, 1);
      expect(fakeRepo.lastUpdateBusinessName, 'Renamed Store');
      // Never passed → stays at its default, meaning "leave alone".
      expect(fakeRepo.lastUpdateBusinessType, isNull);
      expect(fakeRepo.lastUpdateCountry, 'Egypt');
      expect(fakeRepo.lastUpdateCity, 'Alexandria');
      expect(fakeRepo.lastUpdateDescription?.isSet, isTrue);
      expect(fakeRepo.lastUpdateDescription?.value, 'New description');
      expect(fakeRepo.lastUpdateCategoryId?.isSet, isTrue);
      expect(fakeRepo.lastUpdateCategoryId?.value, 5);
      // Patchable.clear() → isSet true, value null (explicit clear, not
      // "leave alone").
      expect(fakeRepo.lastUpdatePhoneNumber?.isSet, isTrue);
      expect(fakeRepo.lastUpdatePhoneNumber?.value, isNull);

      final state = container.read(businessProfileProvider);
      expect(state.hasValue, isTrue);
      expect(state.value?.businessName, 'Renamed Store');
      expect(state.value?.city, 'Alexandria');
      expect(state.value?.description, 'New description');
      expect(state.value?.phoneNumber, isNull);
    });

    test('a field left at its Patchable.unset() default never reaches '
        'the repository as "set" — distinct from an explicit clear', () async {
      final fakeRepo = FakeBusinessProfileRepository(fetchResult: _profile);
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(businessProfileProvider.future);

      await container
          .read(businessProfileProvider.notifier)
          .updateProfile(businessName: 'Only This Changed');

      expect(fakeRepo.lastUpdateDescription?.isSet, isFalse);
      expect(fakeRepo.lastUpdateCategoryId?.isSet, isFalse);
      expect(fakeRepo.lastUpdatePhoneNumber?.isSet, isFalse);
    });

    test('sets state to AsyncLoading synchronously before the repository '
        'call resolves', () async {
      final fakeRepo = FakeBusinessProfileRepository(fetchResult: _profile);
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(businessProfileProvider.future);

      final future = container
          .read(businessProfileProvider.notifier)
          .updateProfile(city: 'Luxor');

      expect(container.read(businessProfileProvider).isLoading, isTrue);
      await future;
    });

    test('on failure, state becomes AsyncError (carrying the original '
        'exception), and that same exception is rethrown to the caller', () async {
      final failure = Exception('validation failed');
      final fakeRepo = FakeBusinessProfileRepository(
        fetchResult: _profile,
        updateProfileBehavior: () async => throw failure,
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
            .updateProfile(city: 'Luxor'),
        throwsA(same(failure)),
      );

      final state = container.read(businessProfileProvider);
      expect(state.hasError, isTrue);
      expect(state.error, same(failure));
      // A failed PATCH must not falsely mark the profile as persisted —
      // the acceptance criterion this test exists for. `state.value`
      // (via `copyWithPrevious`, see the createProfile test's note
      // above) still holds the last known-good `_profile`, unchanged —
      // it is NOT the (never-produced) patched value.
      expect(state.value, _profile);
    });
  });

  group('BusinessProfileNotifier.refreshProfile (Part P-028C2)', () {
    test('re-runs fetchMyProfile and assigns whatever it now returns to '
        'state, without disposing/rebuilding the notifier instance', () async {
      final fakeRepo = FakeBusinessProfileRepository(fetchResult: _profile);
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(businessProfileProvider.future);
      final notifierBefore = container.read(businessProfileProvider.notifier);

      const updatedOnServer = BusinessProfile(
        id: 7,
        businessName: 'Al Ananka Store (changed elsewhere)',
        businessType: BusinessType.trader,
        country: 'Egypt',
        city: 'Cairo',
        isVerified: true,
      );
      fakeRepo.currentFetchResult = updatedOnServer;

      await notifierBefore.refreshProfile();

      expect(
        container.read(businessProfileProvider),
        const AsyncData<BusinessProfile?>(updatedOnServer),
      );
      // Confirms this uses AsyncValue.guard + a direct `state =`
      // assignment, not `ref.invalidateSelf()` — see refreshProfile's
      // own docstring in business_profile_provider.dart for why this
      // matters to app_router.dart's _SessionRefreshListenable
      // subscription (Part P-028C1).
      expect(
        identical(
          container.read(businessProfileProvider.notifier),
          notifierBefore,
        ),
        isTrue,
      );
    });

    test('sets state to AsyncLoading synchronously before the fetch '
        'resolves', () async {
      final fakeRepo = FakeBusinessProfileRepository(fetchResult: _profile);
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(businessProfileProvider.future);

      final future = container
          .read(businessProfileProvider.notifier)
          .refreshProfile();

      expect(container.read(businessProfileProvider).isLoading, isTrue);
      await future;
    });

    test('a failed refresh settles into AsyncError and does NOT rethrow '
        '— unlike createProfile/updateProfile, a failed refresh is a '
        'non-destructive, retryable condition', () async {
      final fakeRepo = FakeBusinessProfileRepository(fetchResult: _profile);
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(businessProfileProvider.future);

      fakeRepo.currentFetchError = Exception('network down');

      // Must complete without throwing.
      await container.read(businessProfileProvider.notifier).refreshProfile();

      final state = container.read(businessProfileProvider);
      expect(state.hasError, isTrue);
    });

    test('a fresh 404 (fetch now returns null) maps to AsyncData(null), '
        'not AsyncError — re-arming the onboarding redirect rather than '
        'showing an error, exactly like build() does', () async {
      final fakeRepo = FakeBusinessProfileRepository(fetchResult: _profile);
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(businessProfileProvider.future);

      fakeRepo.currentFetchResult = null;

      await container.read(businessProfileProvider.notifier).refreshProfile();

      final state = container.read(businessProfileProvider);
      expect(state, const AsyncData<BusinessProfile?>(null));
      expect(state.hasError, isFalse);
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