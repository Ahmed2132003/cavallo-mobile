/// Part FL-01 — tolerant JSON parsers for the subscription endpoints
/// (BE-01 plans, BE-03 custom-quote, BE-06 subscription/me, BE-07 checkout).
///
/// Same style as `DtoParsing`: anything essential that is missing or has the
/// wrong type throws a [FormatException] with the JSON path (the repository
/// turns it into an `UnknownFailure`). Optional values never throw: a wrong
/// type becomes `null` / a safe default. Money stays a decimal STRING.
library;

import '../../../business_console/data/dtos/dto_parsing.dart';
import '../../domain/subscription_entities.dart';

String? _str(Map<String, dynamic> json, String key) {
  final Object? v = json[key];
  return v is String ? v : null;
}

bool _bool(Map<String, dynamic> json, String key) => json[key] == true;

int? _int(Map<String, dynamic> json, String key) {
  final Object? v = json[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

DateTime? _date(Map<String, dynamic> json, String key) {
  final String? raw = _str(json, key);
  return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
}

/// `{id, code, name, name_ar, name_en}` or just a plan code string.
abstract final class PlanRefDto {
  static SubscriptionPlanRef? parse(Object? raw) {
    if (raw is String) {
      return raw.isEmpty ? null : SubscriptionPlanRef(code: raw);
    }
    if (raw is! Map) return null;
    final Map<String, dynamic> json = DtoParsing.asMap(raw, 'plan');
    return SubscriptionPlanRef(
      id: _int(json, 'id'),
      code: _str(json, 'code'),
      name: _str(json, 'name'),
      nameAr: _str(json, 'name_ar'),
      nameEn: _str(json, 'name_en'),
    );
  }
}

abstract final class PlanDto {
  /// Null for a legacy "Featured" plan (`code` is null): not a storage plan.
  static PlanEntity? fromJson(Map<String, dynamic> json) {
    const String p = 'plan';
    final String? code = _str(json, 'code');
    if (code == null || code.isEmpty) return null;
    return PlanEntity(
      id: DtoParsing.reqInt(json, 'id', p),
      code: code,
      name: _str(json, 'name') ?? '',
      nameAr: _str(json, 'name_ar') ?? '',
      nameEn: _str(json, 'name_en') ?? '',
      priceEgp: DtoParsing.optMoney(json, 'price_egp', p),
      storageBytes: _int(json, 'storage_bytes'),
      isFeatured: _bool(json, 'is_featured'),
      trialDays: _int(json, 'trial_days') ?? 0,
      isCustom: _bool(json, 'is_custom'),
      sortOrder: _int(json, 'sort_order') ?? 0,
    );
  }
}

abstract final class SubscriptionStateDto {
  static SubscriptionStateEntity fromJson(Map<String, dynamic> json) {
    return SubscriptionStateEntity(
      plan: PlanRefDto.parse(json['plan']),
      status: _str(json, 'status') ?? '',
      state: _str(json, 'state') ?? '',
      daysLeft: _int(json, 'days_left'),
      trialEndsAt: _date(json, 'trial_ends_at'),
      periodEnd: _date(json, 'current_period_end'),
      purgeAt: _date(json, 'purge_at'),
      quotaBytes: _int(json, 'quota_bytes'),
      usedBytes: _int(json, 'used_bytes'),
      isFeatured: _bool(json, 'is_featured_effective'),
      pendingPlan: PlanRefDto.parse(json['pending_plan']),
      locked: _bool(json, 'locked'),
    );
  }
}

abstract final class CustomQuoteDto {
  static CustomQuote fromJson(Map<String, dynamic> json) {
    const String p = 'quote';
    return CustomQuote(
      gb: DtoParsing.reqMoney(json, 'gb', p),
      priceEgp: DtoParsing.reqMoney(json, 'price_egp', p),
      quotaBytes: DtoParsing.reqInt(json, 'quota_bytes', p),
      isFeatured: _bool(json, 'is_featured'),
    );
  }
}

abstract final class CheckoutResultDto {
  static CheckoutResult fromJson(Map<String, dynamic> json) {
    const String p = 'checkout';
    return CheckoutResult(
      paymentId: DtoParsing.reqInt(json, 'payment_id', p),
      checkoutUrl: DtoParsing.reqString(json, 'checkout_url', p),
      amountEgp: DtoParsing.reqMoney(json, 'amount_egp', p),
    );
  }
}

abstract final class CheckoutStatusDto {
  static CheckoutStatus fromJson(Map<String, dynamic> json) {
    const String p = 'checkoutStatus';
    return CheckoutStatus(
      paymentId: DtoParsing.reqInt(json, 'payment_id', p),
      status: CheckoutPaymentStatus.fromRaw(_str(json, 'status')),
      plan: _str(json, 'plan') ?? '',
      gb: DtoParsing.optMoney(json, 'gb', p),
      amountEgp: DtoParsing.reqMoney(json, 'amount_egp', p),
    );
  }
}
