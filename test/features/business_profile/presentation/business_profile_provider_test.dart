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
class FakeBusinessProfileRepository implements BusinessProfileRepository {
  FakeBusinessProfileRepository({this.fetchResult, this.fetchError});

  /// What [fetchMyProfile] resolves to when [fetchError] is null —
  /// `null` here means "no profile yet" (a valid result, not the
  /// "don't throw" default), matching the real repository's own
  /// 404-to-`null` contract.
  final BusinessProfile? fetchResult;

  /// When non-null, [fetchMyProfile] throws this instead of resolving.
  final Object? fetchError;

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
  }) {
    throw UnimplementedError(
      'Not exercised by BusinessProfileNotifier in this part — see this '
      "file's/business_profile_provider.dart's own scope note (P-028B's "
      'job).',
    );
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
      "file's/business_profile_provider.dart's own scope note (P-028B's "
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
