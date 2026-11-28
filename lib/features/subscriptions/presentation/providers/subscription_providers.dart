import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/subscription_repository_impl.dart';
import '../../domain/subscription_entities.dart';
import '../../domain/subscription_repository.dart';

/// Part FL-01 — Riverpod wiring for subscriptions (no UI).
final Provider<SubscriptionRepository> subscriptionRepositoryProvider =
    Provider<SubscriptionRepository>((Ref ref) {
      return SubscriptionRepositoryImpl(ref.watch(dioClientProvider));
    });

/// Catalog plans (public endpoint). Refresh with `ref.invalidate(plansProvider)`.
final FutureProvider<List<PlanEntity>> plansProvider =
    FutureProvider<List<PlanEntity>>((Ref ref) {
      return ref.watch(subscriptionRepositoryProvider).getPlans();
    });

/// The business's own subscription; `null` data = no subscription (404).
/// autoDispose so a state never survives into another login. Refresh with
/// `ref.invalidate(mySubscriptionProvider)` (e.g. after a checkout completes).
final FutureProvider<SubscriptionStateEntity?> mySubscriptionProvider =
    FutureProvider.autoDispose<SubscriptionStateEntity?>((Ref ref) {
      return ref.watch(subscriptionRepositoryProvider).getMySubscription();
    });

/// `true` only when the server says `locked`. Loading, error and "no
/// subscription" all read as NOT locked (the server enforces the real gate
/// with 403 `SUBSCRIPTION_REQUIRED`). Only watch it for business accounts.
final Provider<bool> isBusinessLockedProvider = Provider.autoDispose<bool>((
  Ref ref,
) {
  return ref.watch(mySubscriptionProvider).value?.locked ?? false;
});
