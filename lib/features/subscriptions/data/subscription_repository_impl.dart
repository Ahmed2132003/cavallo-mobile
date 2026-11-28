import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../../business_console/data/dtos/dto_parsing.dart';
import '../domain/subscription_entities.dart';
import '../domain/subscription_repository.dart';
import 'dtos/subscription_dtos.dart';

/// Part FL-01 — REST data layer for subscriptions, on the shared Dio client.
/// Every method throws a typed [ApiFailure] (same convention as
/// `OrdersRepository`); a malformed body becomes an [UnknownFailure].
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl(this._dio);

  final Dio _dio;

  static const String _plansPath = '/api/v1/monetization/plans/';
  static const String _mePath = '/api/v1/monetization/subscription/me/';
  static const String _quotePath =
      '/api/v1/monetization/subscriptions/custom-quote/';
  static const String _checkoutPath =
      '/api/v1/payments/subscriptions/checkout/';

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      final Object? error = e.error;
      throw error is ApiFailure
          ? error
          : UnknownFailure(message: e.message ?? 'Unexpected network error.');
    } on FormatException catch (e) {
      throw UnknownFailure(message: e.message);
    }
  }

  @override
  Future<List<PlanEntity>> getPlans() => _guard(() async {
    final Response<dynamic> response = await _dio.get<dynamic>(_plansPath);
    final Object? data = response.data;
    // Documented as a plain array; a paginated envelope is tolerated.
    final List<dynamic> raw = DtoParsing.asList(
      data is Map ? data['results'] : data,
      'plans',
    );
    final List<PlanEntity> plans = <PlanEntity>[];
    for (int i = 0; i < raw.length; i++) {
      final PlanEntity? plan = PlanDto.fromJson(
        DtoParsing.asMap(raw[i], 'plans[$i]'),
      );
      if (plan != null) plans.add(plan);
    }
    return plans;
  });

  @override
  Future<SubscriptionStateEntity?> getMySubscription() async {
    try {
      return await _guard(() async {
        final Response<dynamic> response = await _dio.get<dynamic>(_mePath);
        return SubscriptionStateDto.fromJson(
          DtoParsing.asMap(response.data, 'subscription'),
        );
      });
    } on ApiFailure catch (failure) {
      // 404 = no business profile / no subscription: "none", not an error.
      if (failure.code == 'NOT_FOUND') return null;
      rethrow;
    }
  }

  @override
  Future<CustomQuote> getCustomQuote(num gb) => _guard(() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      _quotePath,
      queryParameters: <String, dynamic>{'gb': gb},
    );
    return CustomQuoteDto.fromJson(DtoParsing.asMap(response.data, 'quote'));
  });

  @override
  Future<CheckoutResult> startCheckout({required String plan, num? gb}) =>
      _guard(() async {
        final Response<dynamic> response = await _dio.post<dynamic>(
          _checkoutPath,
          data: <String, dynamic>{'plan': plan, if (gb != null) 'gb': gb},
        );
        return CheckoutResultDto.fromJson(
          DtoParsing.asMap(response.data, 'checkout'),
        );
      });

  @override
  Future<CheckoutStatus> getCheckoutStatus(int paymentId) => _guard(() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '$_checkoutPath$paymentId/status/',
    );
    return CheckoutStatusDto.fromJson(
      DtoParsing.asMap(response.data, 'checkoutStatus'),
    );
  });
}
