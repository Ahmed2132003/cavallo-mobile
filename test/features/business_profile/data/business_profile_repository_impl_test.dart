import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_repository_impl.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_repository.dart';

/// Part P-028A scope. Exercises [BusinessProfileRepositoryImpl] against a
/// mocked Dio adapter shaped like the confirmed real `/api/v1/businesses/
/// me/` contract (P-026 + P-027, confirmed via PROJECT_PROGRESS.md — see
/// this feature's own module docstrings for exact field-name sourcing) —
/// not the real running backend. Mirrors `auth_repository_impl_test.dart`
/// (Part P-020)'s exact setup: a real `ErrorInterceptor` attached to a
/// mocked adapter, so failure-path assertions see genuine `ApiFailure`
/// variants, not raw status codes.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late BusinessProfileRepositoryImpl repository;

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
    'follower_count': 12400,
  };

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    // Real ErrorInterceptor attached, exactly like dioClientProvider's
    // chain (Part P-004) — see auth_repository_impl_test.dart for the
    // same convention.
    dio.interceptors.add(ErrorInterceptor());

    repository = BusinessProfileRepositoryImpl(dio: dio);
  });

  group('fetchMyProfile', () {
    test('maps a 200 response to a BusinessProfile', () async {
      adapter.onGet(
        '/api/v1/businesses/me/',
        (server) => server.reply(200, fullJson),
      );

      final profile = await repository.fetchMyProfile();

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
          followerCount: 12400,
        ),
      );
    });

    test(
      'a 404 (no profile yet) returns null — never thrown as an error',
      () async {
        adapter.onGet(
          '/api/v1/businesses/me/',
          (server) => server.reply(404, {
            'error': {'code': 'NOT_FOUND', 'message': 'Not found.'},
          }),
        );

        final profile = await repository.fetchMyProfile();

        expect(profile, isNull);
      },
    );

    test('a genuine 500 still propagates as ServerFailure, not null', () async {
      adapter.onGet(
        '/api/v1/businesses/me/',
        (server) => server.reply(500, {
          'error': {'code': 'SERVER_ERROR', 'message': 'Something broke'},
        }),
      );

      try {
        await repository.fetchMyProfile();
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ServerFailure>());
      }
    });
  });

  group('createProfile', () {
    test('POSTs required + optional fields and maps the response', () async {
      adapter.onPost(
        '/api/v1/businesses/me/',
        (server) => server.reply(201, fullJson),
        data: {
          'business_name': 'Al Ananka Store',
          'business_type': 'trader',
          'country': 'Egypt',
          'city': 'Cairo',
          'description': 'Fashion trader',
          'category': 3,
          'phone_number': '+201001234567',
        },
      );

      final profile = await repository.createProfile(
        businessName: 'Al Ananka Store',
        businessType: BusinessType.trader,
        country: 'Egypt',
        city: 'Cairo',
        description: 'Fashion trader',
        categoryId: 3,
        phoneNumber: '+201001234567',
      );

      expect(profile.id, 7);
      expect(profile.businessType, BusinessType.trader);
    });

    test('omits optional fields from the body when left null', () async {
      adapter.onPost(
        '/api/v1/businesses/me/',
        (server) => server.reply(201, fullJson),
        data: {
          'business_name': 'Al Ananka Store',
          'business_type': 'trader',
          'country': 'Egypt',
          'city': 'Cairo',
        },
      );

      await repository.createProfile(
        businessName: 'Al Ananka Store',
        businessType: BusinessType.trader,
        country: 'Egypt',
        city: 'Cairo',
      );
      // http_mock_adapter matches the route+body above; reaching here
      // without throwing an "unmocked route" error already proves the
      // body omitted the optional fields exactly as expected.
    });

    test('a phone number missing its country code surfaces the exact backend '
        'ValidationFailure message (P-027 handoff note)', () async {
      adapter.onPost(
        '/api/v1/businesses/me/',
        (server) => server.reply(400, {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Invalid input',
            'fields': {
              'phone_number': [
                'Enter a valid phone number including the country code, '
                    'e.g. +201234567890.',
              ],
            },
          },
        }),
        data: {
          'business_name': 'Al Ananka Store',
          'business_type': 'trader',
          'country': 'Egypt',
          'city': 'Cairo',
          'phone_number': '01001234567',
        },
      );

      try {
        await repository.createProfile(
          businessName: 'Al Ananka Store',
          businessType: BusinessType.trader,
          country: 'Egypt',
          city: 'Cairo',
          phoneNumber: '01001234567',
        );
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ValidationFailure>());
        expect((e.error as ValidationFailure).fields['phone_number'], [
          'Enter a valid phone number including the country code, e.g. '
              '+201234567890.',
        ]);
      }
    });
  });

  group('updateProfile', () {
    test('PATCHes only the fields actually passed', () async {
      adapter.onPatch(
        '/api/v1/businesses/me/',
        (server) => server.reply(200, fullJson),
        data: {'business_name': 'New Name'},
      );

      await repository.updateProfile(businessName: 'New Name');
      // Reaching here without an "unmocked route" error proves the body
      // contained *only* business_name — country/city/description/
      // category/phone_number were all correctly left out.
    });

    test('Patchable.clear() sends an explicit null; Patchable.unset() '
        '(the default) omits the field entirely', () async {
      adapter.onPatch(
        '/api/v1/businesses/me/',
        (server) => server.reply(200, fullJson),
        // category explicitly cleared; description/phone_number left
        // out entirely since they default to Patchable.unset().
        data: {'category': null},
      );

      await repository.updateProfile(categoryId: const Patchable.clear());
    });

    test('Patchable.value(x) sends the given value', () async {
      adapter.onPatch(
        '/api/v1/businesses/me/',
        (server) => server.reply(200, fullJson),
        data: {'category': 5},
      );

      await repository.updateProfile(categoryId: const Patchable.value(5));
    });
  });
}
