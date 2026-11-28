import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/subscriptions/data/dtos/subscription_dtos.dart';
import 'package:social_commerce_app/features/subscriptions/domain/subscription_entities.dart';

const Map<String, dynamic> _meJson = <String, dynamic>{
  'plan': <String, dynamic>{
    'id': 3,
    'code': 'pro',
    'name': 'Pro',
    'name_ar': 'pro-ar',
    'name_en': 'Pro',
  },
  'status': 'active',
  'state': 'active',
  'days_left': 12,
  'trial_ends_at': null,
  'current_period_end': '2026-12-10T10:00:00Z',
  'purge_at': null,
  'quota_bytes': 53687091200,
  'used_bytes': 1024,
  'is_featured_effective': true,
  'pending_plan': null,
  'locked': false,
};

void main() {
  group('PlanDto', () {
    test('parses a fixed plan', () {
      final PlanEntity? plan = PlanDto.fromJson(<String, dynamic>{
        'id': 2,
        'name': 'Pro',
        'code': 'pro',
        'name_ar': 'pro-ar',
        'name_en': 'Pro',
        'price_egp': '300.00',
        'storage_bytes': 53687091200,
        'is_featured': true,
        'trial_days': 0,
        'is_custom': false,
        'sort_order': 2,
      });
      expect(plan, isNotNull);
      expect(plan!.id, 2);
      expect(plan.code, 'pro');
      expect(plan.priceEgp, '300.00');
      expect(plan.storageBytes, 53687091200);
      expect(plan.isFeatured, isTrue);
      expect(plan.isCustom, isFalse);
      expect(plan.isFree, isFalse);
    });

    test('custom plan keeps null price and storage', () {
      final PlanEntity plan =
          PlanDto.fromJson(<String, dynamic>{
            'id': 5,
            'code': 'infinity',
            'price_egp': null,
            'storage_bytes': null,
            'is_custom': true,
          })!;
      expect(plan.priceEgp, isNull);
      expect(plan.storageBytes, isNull);
      expect(plan.isCustom, isTrue);
      expect(plan.name, '');
      expect(plan.trialDays, 0);
    });

    test('free plan with trial days', () {
      final PlanEntity plan =
          PlanDto.fromJson(<String, dynamic>{
            'id': 1,
            'code': 'free',
            'trial_days': 7,
          })!;
      expect(plan.isFree, isTrue);
      expect(plan.trialDays, 7);
    });

    test('a legacy plan without code is skipped', () {
      expect(
        PlanDto.fromJson(<String, dynamic>{'id': 9, 'code': null}),
        isNull,
      );
    });

    test('a numeric price is rendered with 2 decimals', () {
      final PlanEntity plan =
          PlanDto.fromJson(<String, dynamic>{
            'id': 2,
            'code': 'pro',
            'price_egp': 300,
          })!;
      expect(plan.priceEgp, '300.00');
    });

    test('a catalog plan without id throws FormatException', () {
      expect(
        () => PlanDto.fromJson(<String, dynamic>{'code': 'pro'}),
        throwsFormatException,
      );
    });
  });

  group('SubscriptionStateDto', () {
    test('parses a full response', () {
      final SubscriptionStateEntity s = SubscriptionStateDto.fromJson(_meJson);
      expect(s.plan?.code, 'pro');
      expect(s.plan?.id, 3);
      expect(s.status, 'active');
      expect(s.state, 'active');
      expect(s.daysLeft, 12);
      expect(s.periodEnd, DateTime.utc(2026, 12, 10, 10));
      expect(s.trialEndsAt, isNull);
      expect(s.purgeAt, isNull);
      expect(s.quotaBytes, 53687091200);
      expect(s.usedBytes, 1024);
      expect(s.remainingBytes, 53687090176);
      expect(s.isFeatured, isTrue);
      expect(s.pendingPlan, isNull);
      expect(s.locked, isFalse);
    });

    test('an empty body yields safe defaults (not locked)', () {
      final SubscriptionStateEntity s = SubscriptionStateDto.fromJson(
        <String, dynamic>{},
      );
      expect(s.plan, isNull);
      expect(s.status, '');
      expect(s.state, '');
      expect(s.locked, isFalse);
      expect(s.isFeatured, isFalse);
      expect(s.remainingBytes, isNull);
    });

    test('locked comes from the locked field, not from status/state', () {
      final SubscriptionStateEntity a = SubscriptionStateDto.fromJson(
        <String, dynamic>{..._meJson, 'status': 'expired', 'locked': false},
      );
      final SubscriptionStateEntity b = SubscriptionStateDto.fromJson(
        <String, dynamic>{..._meJson, 'status': 'active', 'locked': true},
      );
      expect(a.locked, isFalse);
      expect(b.locked, isTrue);
    });

    test('pending_plan is kept apart from plan (object or code string)', () {
      final SubscriptionStateEntity asMap = SubscriptionStateDto.fromJson(
        <String, dynamic>{
          ..._meJson,
          'pending_plan': <String, dynamic>{'id': 2, 'code': 'max'},
        },
      );
      final SubscriptionStateEntity asCode = SubscriptionStateDto.fromJson(
        <String, dynamic>{..._meJson, 'pending_plan': 'max'},
      );
      expect(asMap.plan?.code, 'pro');
      expect(asMap.pendingPlan?.code, 'max');
      expect(asMap.pendingPlan?.id, 2);
      expect(asCode.pendingPlan?.code, 'max');
    });

    test('numeric strings and bad dates are tolerated', () {
      final SubscriptionStateEntity s =
          SubscriptionStateDto.fromJson(<String, dynamic>{
            ..._meJson,
            'days_left': '5',
            'quota_bytes': '100',
            'used_bytes': 250,
            'purge_at': 'not-a-date',
          });
      expect(s.daysLeft, 5);
      expect(s.quotaBytes, 100);
      expect(s.purgeAt, isNull);
      expect(s.remainingBytes, 0);
    });
  });

  group('CustomQuoteDto', () {
    test('parses the quote', () {
      final CustomQuote q = CustomQuoteDto.fromJson(<String, dynamic>{
        'gb': '20.00',
        'price_egp': '630.00',
        'quota_bytes': 21474836480,
        'is_featured': true,
      });
      expect(q.gb, '20.00');
      expect(q.priceEgp, '630.00');
      expect(q.quotaBytes, 21474836480);
      expect(q.isFeatured, isTrue);
    });

    test('a missing price throws FormatException', () {
      expect(
        () => CustomQuoteDto.fromJson(<String, dynamic>{
          'gb': '20.00',
          'quota_bytes': 1,
        }),
        throwsFormatException,
      );
    });
  });

  group('Checkout DTOs', () {
    test('CheckoutResultDto parses the 201 body', () {
      final CheckoutResult r = CheckoutResultDto.fromJson(<String, dynamic>{
        'payment_id': 41,
        'checkout_url': 'https://pay.example/c/41',
        'amount_egp': '630.00',
      });
      expect(r.paymentId, 41);
      expect(r.checkoutUrl, 'https://pay.example/c/41');
      expect(r.amountEgp, '630.00');
    });

    test('CheckoutResultDto without checkout_url throws', () {
      expect(
        () => CheckoutResultDto.fromJson(<String, dynamic>{
          'payment_id': 41,
          'amount_egp': '630.00',
        }),
        throwsFormatException,
      );
    });

    test('CheckoutStatusDto maps statuses and the optional gb', () {
      CheckoutStatus parse(String status, Object? gb) =>
          CheckoutStatusDto.fromJson(<String, dynamic>{
            'payment_id': 41,
            'status': status,
            'plan': 'infinity',
            'gb': gb,
            'amount_egp': '630.00',
          });
      expect(parse('pending', '20.00').status, CheckoutPaymentStatus.pending);
      expect(parse('pending', '20.00').gb, '20.00');
      expect(parse('completed', null).status, CheckoutPaymentStatus.completed);
      expect(parse('completed', null).gb, isNull);
      expect(parse('failed', null).status.isTerminal, isTrue);
      expect(parse('pending', null).status.isTerminal, isFalse);
      expect(parse('weird', null).status, CheckoutPaymentStatus.unknown);
      expect(parse('completed', null).plan, 'infinity');
    });
  });
}
