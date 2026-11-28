import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/subscriptions/data/dtos/subscription_dtos.dart';
import 'package:social_commerce_app/features/subscriptions/domain/subscription_entities.dart';
import 'package:social_commerce_app/features/subscriptions/domain/subscription_repository.dart';
import 'package:social_commerce_app/features/subscriptions/presentation/providers/subscription_providers.dart';

class _FakeRepository implements SubscriptionRepository {
  _FakeRepository(this.onMe);

  Future<SubscriptionStateEntity?> Function() onMe;

  @override
  Future<SubscriptionStateEntity?> getMySubscription() => onMe();

  @override
  Future<List<PlanEntity>> getPlans() async => const <PlanEntity>[];

  @override
  Future<CustomQuote> getCustomQuote(num gb) => throw UnimplementedError();

  @override
  Future<CheckoutResult> startCheckout({required String plan, num? gb}) =>
      throw UnimplementedError();

  @override
  Future<CheckoutStatus> getCheckoutStatus(int paymentId) =>
      throw UnimplementedError();
}

SubscriptionStateEntity _sub({required bool locked}) =>
    SubscriptionStateDto.fromJson(<String, dynamic>{
      'status': 'active',
      'state': 'active',
      'locked': locked,
    });

ProviderContainer _container(_FakeRepository repo) {
  final ProviderContainer container = ProviderContainer(
    // Riverpod 3 retries failed providers by default; keep errors immediate.
    retry: (int retryCount, Object error) => null,
    overrides: [subscriptionRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  // autoDispose providers need a listener to stay alive between reads.
  container.listen(isBusinessLockedProvider, (prev, next) {});
  return container;
}

void main() {
  test(
    'is false while loading, then true once the server says locked',
    () async {
      final _FakeRepository repo = _FakeRepository(
        () async => _sub(locked: true),
      );
      final ProviderContainer container = _container(repo);
      expect(container.read(isBusinessLockedProvider), isFalse);
      await container.read(mySubscriptionProvider.future);
      expect(container.read(isBusinessLockedProvider), isTrue);
    },
  );

  test('is false when the subscription is not locked', () async {
    final ProviderContainer container = _container(
      _FakeRepository(() async => _sub(locked: false)),
    );
    await container.read(mySubscriptionProvider.future);
    expect(container.read(isBusinessLockedProvider), isFalse);
  });

  test('is false when there is no subscription (null)', () async {
    final ProviderContainer container = _container(
      _FakeRepository(() async => null),
    );
    expect(await container.read(mySubscriptionProvider.future), isNull);
    expect(container.read(isBusinessLockedProvider), isFalse);
  });

  test('is false when loading fails', () async {
    final ProviderContainer container = _container(
      _FakeRepository(() async => throw const UnknownFailure(message: 'boom')),
    );
    await expectLater(
      container.read(mySubscriptionProvider.future),
      throwsA(isA<UnknownFailure>()),
    );
    expect(container.read(isBusinessLockedProvider), isFalse);
  });

  test('invalidate refreshes the lock state', () async {
    final _FakeRepository repo = _FakeRepository(
      () async => _sub(locked: true),
    );
    final ProviderContainer container = _container(repo);
    await container.read(mySubscriptionProvider.future);
    expect(container.read(isBusinessLockedProvider), isTrue);

    repo.onMe = () async => _sub(locked: false);
    container.invalidate(mySubscriptionProvider);
    await container.read(mySubscriptionProvider.future);
    expect(container.read(isBusinessLockedProvider), isFalse);
  });
}
