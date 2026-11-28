import 'subscription_entities.dart';

/// Part FL-01 — data contract for subscriptions. Every method throws a typed
/// `ApiFailure` (never a raw `DioException`).
abstract interface class SubscriptionRepository {
  /// Catalog plans only (legacy "Featured" plans without a `code` are dropped).
  Future<List<PlanEntity>> getPlans();

  /// `null` when the business has no subscription / profile (HTTP 404).
  Future<SubscriptionStateEntity?> getMySubscription();

  /// [gb] up to 2 decimals (server limit); out-of-range -> ValidationFailure on `gb`.
  Future<CustomQuote> getCustomQuote(num gb);

  /// [plan] is the plan CODE. [gb] is only for the custom plan; null = not sent.
  Future<CheckoutResult> startCheckout({required String plan, num? gb});

  Future<CheckoutStatus> getCheckoutStatus(int paymentId);
}
