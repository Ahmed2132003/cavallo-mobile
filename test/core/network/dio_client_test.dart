import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/dio_client.dart';
import 'package:social_commerce_app/core/network/interceptors/auth_interceptor.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/core/network/interceptors/logging_interceptor.dart';

void main() {
  test(
    'dioClientProvider builds a Dio with the three interceptors attached, '
    'in order, with zero feature code present',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dio = container.read(dioClientProvider);

      expect(dio, isA<Dio>());

      // Dio itself prepends an internal ImplyContentTypeInterceptor when
      // you construct a Dio() instance — that's not one of ours, so we
      // check that our three interceptors are present and in the right
      // relative order, rather than asserting a fixed total count.
      final loggingIndex = dio.interceptors.indexWhere(
        (i) => i is LoggingInterceptor,
      );
      final authIndex = dio.interceptors.indexWhere(
        (i) => i is AuthInterceptor,
      );
      final errorIndex = dio.interceptors.indexWhere(
        (i) => i is ErrorInterceptor,
      );

      expect(loggingIndex, isNot(-1), reason: 'LoggingInterceptor missing');
      expect(authIndex, isNot(-1), reason: 'AuthInterceptor missing');
      expect(errorIndex, isNot(-1), reason: 'ErrorInterceptor missing');
      expect(loggingIndex, lessThan(authIndex));
      expect(authIndex, lessThan(errorIndex));
    },
  );
  
  test('dioClientProvider itself is overridable in a throwaway test container', () {
    final fakeDio = Dio(BaseOptions(baseUrl: 'https://override.test'));
    final container = ProviderContainer(
      overrides: [dioClientProvider.overrideWithValue(fakeDio)],
    );
    addTearDown(container.dispose);

    final dio = container.read(dioClientProvider);

    expect(identical(dio, fakeDio), isTrue);
    expect(dio.options.baseUrl, 'https://override.test');
  });

  test('authTokenGetterProvider defaults to a no-op getter returning null', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final getToken = container.read(authTokenGetterProvider);

    expect(await getToken(), isNull);
  });
}
