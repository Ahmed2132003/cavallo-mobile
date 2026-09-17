import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';

/// Part P-029 scope. Mirrors `business_profile_repository_impl_test.dart`
/// (Part P-028A)'s exact setup — a real [ErrorInterceptor] attached to a
/// mocked [Dio] adapter, so failure-path assertions see genuine
/// [ApiFailure] variants, not raw status codes — applied to
/// [BusinessProfilePublicRepositoryImpl] instead: `GET
/// /api/v1/businesses/{id}/`, confirmed public and `AllowAny` in
/// `businesses/views.py` on the real backend (`BusinessProfilePublicView`,
/// Part P-026), reusing the same `BusinessProfileSerializer` and
/// therefore the same response shape [fullJson] below mirrors.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late BusinessProfilePublicRepositoryImpl repository;

  const fullJson = {
    'id': 7,
    'business_name': 'Al Ananka Store',
    'business_type': 'trader',
    'country': 'Egypt',
    'city': 'Cairo',
    'description': 'Fashion trader',
    'phone_number': '+201001234567',
    'category': 3,
    'is_verified': true,
    'follower_count': 0,
  };

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    // Real ErrorInterceptor attached, exactly like dioClientProvider's
    // chain (Part P-004) — same convention as every other repository
    // test in this project.
    dio.interceptors.add(ErrorInterceptor());

    repository = BusinessProfilePublicRepositoryImpl(dio: dio);
  });

  group('fetchPublicProfile', () {
    test('maps a 200 response to a BusinessProfile', () async {
      adapter.onGet(
        '/api/v1/businesses/7/',
        (server) => server.reply(200, fullJson),
      );

      final profile = await repository.fetchPublicProfile(7);

      expect(
        profile,
        const BusinessProfile(
          id: 7,
          businessName: 'Al Ananka Store',
          businessType: BusinessType.trader,
          country: 'Egypt',
          city: 'Cairo',
          description: 'Fashion trader',
          phoneNumber: '+201001234567',
          categoryId: 3,
          isVerified: true,
          followerCount: 0,
        ),
      );
    });

    test('an unverified business maps isVerified to false', () async {
      adapter.onGet(
        '/api/v1/businesses/8/',
        (server) =>
            server.reply(200, {...fullJson, 'id': 8, 'is_verified': false}),
      );

      final profile = await repository.fetchPublicProfile(8);

      expect(profile?.isVerified, isFalse);
    });

    test('a 404 (business does not exist) returns null — never thrown as an '
        'error', () async {
      adapter.onGet(
        '/api/v1/businesses/999999/',
        (server) => server.reply(404, {
          'error': {'code': 'NOT_FOUND', 'message': 'Not found.'},
        }),
      );

      final profile = await repository.fetchPublicProfile(999999);

      expect(profile, isNull);
    });

    test('a genuine 500 still propagates as ServerFailure, not null', () async {
      adapter.onGet(
        '/api/v1/businesses/7/',
        (server) => server.reply(500, {
          'error': {'code': 'SERVER_ERROR', 'message': 'Something broke'},
        }),
      );

      try {
        await repository.fetchPublicProfile(7);
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ServerFailure>());
      }
    });

    test(
      'a network failure (no connectivity) propagates as NetworkFailure',
      () async {
        adapter.onGet(
          '/api/v1/businesses/7/',
          (server) => server.throws(
            0,
            DioException.connectionError(
              requestOptions: RequestOptions(path: '/api/v1/businesses/7/'),
              reason: 'Failed host lookup',
            ),
          ),
        );

        try {
          await repository.fetchPublicProfile(7);
          fail('Expected a DioException to be thrown');
        } on DioException catch (e) {
          expect(e.error, isA<NetworkFailure>());
        }
      },
    );
  });
}
