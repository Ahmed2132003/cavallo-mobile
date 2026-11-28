import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/subscriptions/data/subscription_repository_impl.dart';
import 'package:social_commerce_app/features/subscriptions/domain/subscription_entities.dart';

import '../../chat/data/fake_http_client_adapter.dart';

Map<String, dynamic> _envelope(
  String code, {
  Map<String, dynamic> fields = const <String, dynamic>{},
}) => <String, dynamic>{
  'error': <String, dynamic>{'code': code, 'message': 'm', 'fields': fields},
};

void main() {
  late FakeHttpClientAdapter adapter;
  late SubscriptionRepositoryImpl repository;

  setUp(() {
    adapter = FakeHttpClientAdapter();
    final Dio dio =
        Dio(BaseOptions(baseUrl: 'http://test.local'))
          ..httpClientAdapter = adapter
          ..interceptors.add(ErrorInterceptor());
    repository = SubscriptionRepositoryImpl(dio);
  });

  Matcher failure<T extends ApiFailure>(String code) =>
      throwsA(isA<T>().having((ApiFailure f) => f.code, 'code', code));

  group('getPlans', () {
    test('GETs the catalog and drops legacy plans', () async {
      adapter.enqueue(
        statusCode: 200,
        data: <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'code': 'free', 'price_egp': '0.00'},
          <String, dynamic>{'id': 8, 'code': null, 'name': 'Featured 30d'},
          <String, dynamic>{
            'id': 5,
            'code': 'infinity',
            'price_egp': null,
            'storage_bytes': null,
            'is_custom': true,
          },
        ],
      );
      final List<PlanEntity> plans = await repository.getPlans();
      expect(adapter.requestedOptions.single.method, 'GET');
      expect(
        adapter.requestedOptions.single.path,
        '/api/v1/monetization/plans/',
      );
      expect(plans.map((PlanEntity p) => p.code), <String>['free', 'infinity']);
      expect(plans.last.isCustom, isTrue);
    });

    test('tolerates a paginated envelope', () async {
      adapter.enqueue(
        statusCode: 200,
        data: <String, dynamic>{
          'results': <Map<String, dynamic>>[
            <String, dynamic>{'id': 2, 'code': 'pro'},
          ],
        },
      );
      expect((await repository.getPlans()).single.code, 'pro');
    });

    test('a malformed body becomes an UnknownFailure', () async {
      adapter.enqueue(statusCode: 200, data: <String, dynamic>{'oops': 1});
      await expectLater(repository.getPlans(), throwsA(isA<UnknownFailure>()));
    });
  });

  group('getMySubscription', () {
    test('parses subscription/me', () async {
      adapter.enqueue(
        statusCode: 200,
        data: <String, dynamic>{
          'plan': <String, dynamic>{'id': 3, 'code': 'pro'},
          'status': 'active',
          'state': 'active',
          'locked': true,
          'pending_plan': <String, dynamic>{'id': 2, 'code': 'max'},
        },
      );
      final SubscriptionStateEntity? s = await repository.getMySubscription();
      expect(
        adapter.requestedOptions.single.path,
        '/api/v1/monetization/subscription/me/',
      );
      expect(s!.locked, isTrue);
      expect(s.plan?.code, 'pro');
      expect(s.pendingPlan?.code, 'max');
    });

    test('404 NOT_FOUND means no subscription (null, not an error)', () async {
      adapter.enqueue(statusCode: 404, data: _envelope('NOT_FOUND'));
      expect(await repository.getMySubscription(), isNull);
    });

    test('403 SUBSCRIPTION_REQUIRED is rethrown as an AuthFailure', () async {
      adapter.enqueue(
        statusCode: 403,
        data: _envelope('SUBSCRIPTION_REQUIRED'),
      );
      await expectLater(
        repository.getMySubscription(),
        failure<AuthFailure>('SUBSCRIPTION_REQUIRED'),
      );
    });

    test('500 is a ServerFailure, not swallowed', () async {
      adapter.enqueue(statusCode: 500, data: _envelope('SERVER_ERROR'));
      await expectLater(
        repository.getMySubscription(),
        failure<ServerFailure>('SERVER_ERROR'),
      );
    });
  });

  group('getCustomQuote', () {
    test('GETs with ?gb= and parses the quote', () async {
      adapter.enqueue(
        statusCode: 200,
        data: <String, dynamic>{
          'gb': '20.00',
          'price_egp': '630.00',
          'quota_bytes': 21474836480,
          'is_featured': true,
        },
      );
      final CustomQuote q = await repository.getCustomQuote(20);
      final RequestOptions request = adapter.requestedOptions.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/monetization/subscriptions/custom-quote/');
      expect(request.queryParameters, <String, dynamic>{'gb': 20});
      expect(q.priceEgp, '630.00');
    });

    test('400 keeps the gb field error', () async {
      adapter.enqueue(
        statusCode: 400,
        data: _envelope(
          'VALIDATION_ERROR',
          fields: <String, dynamic>{
            'gb': <String>['out of range'],
          },
        ),
      );
      await expectLater(
        repository.getCustomQuote(5),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.fields['gb'],
            'fields.gb',
            <String>['out of range'],
          ),
        ),
      );
    });
  });

  group('startCheckout', () {
    test('POSTs only the plan code for a fixed plan', () async {
      adapter.enqueue(
        statusCode: 201,
        data: <String, dynamic>{
          'payment_id': 41,
          'checkout_url': 'https://pay.example/c/41',
          'amount_egp': '300.00',
        },
      );
      final CheckoutResult r = await repository.startCheckout(plan: 'pro');
      final RequestOptions request = adapter.requestedOptions.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/payments/subscriptions/checkout/');
      expect(request.data, <String, dynamic>{'plan': 'pro'});
      expect(r.paymentId, 41);
    });

    test('sends gb for the custom plan', () async {
      adapter.enqueue(
        statusCode: 201,
        data: <String, dynamic>{
          'payment_id': 42,
          'checkout_url': 'https://pay.example/c/42',
          'amount_egp': '630.00',
        },
      );
      await repository.startCheckout(plan: 'infinity', gb: 20);
      expect(adapter.requestedOptions.single.data, <String, dynamic>{
        'plan': 'infinity',
        'gb': 20,
      });
    });

    test('409 downgrade_blocked_usage keeps its lowercase code', () async {
      adapter.enqueue(
        statusCode: 409,
        data: _envelope(
          'downgrade_blocked_usage',
          fields: <String, dynamic>{'used_bytes': 5, 'target_quota_bytes': 9},
        ),
      );
      await expectLater(
        repository.startCheckout(plan: 'pro'),
        failure<UnknownFailure>('downgrade_blocked_usage'),
      );
    });

    test('409 downgrade_already_pending', () async {
      adapter.enqueue(
        statusCode: 409,
        data: _envelope('downgrade_already_pending'),
      );
      await expectLater(
        repository.startCheckout(plan: 'pro'),
        failure<UnknownFailure>('downgrade_already_pending'),
      );
    });

    test('503 gateway failure is a ServerFailure', () async {
      adapter.enqueue(statusCode: 503, data: _envelope('SERVICE_UNAVAILABLE'));
      await expectLater(
        repository.startCheckout(plan: 'pro'),
        failure<ServerFailure>('SERVICE_UNAVAILABLE'),
      );
    });

    test('a 201 without checkout_url becomes an UnknownFailure', () async {
      adapter.enqueue(
        statusCode: 201,
        data: <String, dynamic>{'payment_id': 1, 'amount_egp': '1.00'},
      );
      await expectLater(
        repository.startCheckout(plan: 'pro'),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('getCheckoutStatus', () {
    test('GETs the status path and parses it', () async {
      adapter.enqueue(
        statusCode: 200,
        data: <String, dynamic>{
          'payment_id': 42,
          'status': 'pending',
          'plan': 'infinity',
          'gb': '20.00',
          'amount_egp': '630.00',
        },
      );
      final CheckoutStatus s = await repository.getCheckoutStatus(42);
      expect(
        adapter.requestedOptions.single.path,
        '/api/v1/payments/subscriptions/checkout/42/status/',
      );
      expect(s.status, CheckoutPaymentStatus.pending);
      expect(s.plan, 'infinity');
      expect(s.gb, '20.00');
    });

    test(
      '404 is NOT swallowed here (only subscription/me maps it to null)',
      () async {
        adapter.enqueue(statusCode: 404, data: _envelope('NOT_FOUND'));
        await expectLater(
          repository.getCheckoutStatus(7),
          failure<UnknownFailure>('NOT_FOUND'),
        );
      },
    );
  });
}
