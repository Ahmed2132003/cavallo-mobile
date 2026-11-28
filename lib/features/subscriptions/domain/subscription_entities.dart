/// Part FL-01 — domain model of storage subscriptions (backend BE-01/03/06/07).
///
/// Money is a decimal STRING (never a double), like the rest of the app.
/// `status` / `state` are kept as the raw backend strings: UI code must gate
/// on [SubscriptionStateEntity.locked], never on `state` or `status`.
library;

/// A catalog plan from `GET /api/v1/monetization/plans/`.
class PlanEntity {
  const PlanEntity({
    required this.id,
    required this.code,
    required this.name,
    required this.nameAr,
    required this.nameEn,
    required this.priceEgp,
    required this.storageBytes,
    required this.isFeatured,
    required this.trialDays,
    required this.isCustom,
    required this.sortOrder,
  });

  final int id;

  /// `free|pro|max|ultra|infinity` - the value `startCheckout` expects.
  final String code;
  final String name;
  final String nameAr;
  final String nameEn;

  /// Decimal string; null for the custom plan (priced by GB).
  final String? priceEgp;

  /// Null for the custom plan.
  final int? storageBytes;
  final bool isFeatured;
  final int trialDays;
  final bool isCustom;
  final int sortOrder;

  bool get isFree => code == 'free';
}

/// The `plan` / `pending_plan` reference inside `subscription/me/`. Every
/// field is optional on purpose (parsing is tolerant).
class SubscriptionPlanRef {
  const SubscriptionPlanRef({
    this.id,
    this.code,
    this.name,
    this.nameAr,
    this.nameEn,
  });

  final int? id;
  final String? code;
  final String? name;
  final String? nameAr;
  final String? nameEn;
}

/// `GET /api/v1/monetization/subscription/me/`.
///
/// [plan] is the CURRENT plan, [pendingPlan] the one that starts when the
/// current period ends (a scheduled downgrade) - never mix them up.
class SubscriptionStateEntity {
  const SubscriptionStateEntity({
    required this.status,
    required this.state,
    required this.isFeatured,
    required this.locked,
    this.plan,
    this.daysLeft,
    this.trialEndsAt,
    this.periodEnd,
    this.purgeAt,
    this.quotaBytes,
    this.usedBytes,
    this.pendingPlan,
  });

  final SubscriptionPlanRef? plan;
  final String status;
  final String state;
  final int? daysLeft;
  final DateTime? trialEndsAt;
  final DateTime? periodEnd;
  final DateTime? purgeAt;
  final int? quotaBytes;
  final int? usedBytes;

  /// Backend `is_featured_effective`.
  final bool isFeatured;
  final SubscriptionPlanRef? pendingPlan;

  /// Server-decided lock. Do NOT derive it from [status] / [state].
  final bool locked;

  int? get remainingBytes {
    final int? quota = quotaBytes;
    final int? used = usedBytes;
    if (quota == null || used == null) return null;
    return used >= quota ? 0 : quota - used;
  }
}

/// `GET|POST .../subscriptions/custom-quote/`.
class CustomQuote {
  const CustomQuote({
    required this.gb,
    required this.priceEgp,
    required this.quotaBytes,
    required this.isFeatured,
  });

  /// Decimal string, e.g. `"20.00"`.
  final String gb;
  final String priceEgp;
  final int quotaBytes;
  final bool isFeatured;
}

/// `POST .../payments/subscriptions/checkout/` -> 201.
class CheckoutResult {
  const CheckoutResult({
    required this.paymentId,
    required this.checkoutUrl,
    required this.amountEgp,
  });

  final int paymentId;
  final String checkoutUrl;
  final String amountEgp;
}

enum CheckoutPaymentStatus {
  pending,
  completed,
  failed,
  unknown;

  static CheckoutPaymentStatus fromRaw(String? raw) => switch (raw) {
    'pending' => pending,
    'completed' => completed,
    'failed' => failed,
    _ => unknown,
  };

  bool get isTerminal => this == completed || this == failed;
}

/// `GET .../checkout/<payment_id>/status/`.
class CheckoutStatus {
  const CheckoutStatus({
    required this.paymentId,
    required this.status,
    required this.plan,
    required this.gb,
    required this.amountEgp,
  });

  final int paymentId;
  final CheckoutPaymentStatus status;

  /// Plan CODE (not an id).
  final String plan;

  /// Decimal string for the custom plan, null otherwise.
  final String? gb;
  final String amountEgp;
}
