import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/data/dtos/business_profile_response_dto.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/content/data/dtos/post_public_response_dto.dart';
import 'package:social_commerce_app/features/content/data/dtos/reel_public_response_dto.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';
import 'package:social_commerce_app/features/products/data/dtos/product_response_dto.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/search/data/search_repository_impl.dart';
import 'package:social_commerce_app/features/search/domain/search_result_entity.dart';

/// Part P-110 STEP 2 scope: the Flutter DATA/DOMAIN layer carries the
/// backend's new `is_featured` flag (display-only, ADR-006) on
/// BusinessProfile, Product, PublicPost and PublicReel. No UI here.
void main() {
  Map<String, dynamic> businessJson({Object? featured = _absent}) => {
    'id': 7,
    'business_name': 'Cairo Textiles',
    'business_type': 'factory',
    'country': 'Egypt',
    'city': 'Cairo',
    'description': 'Wholesale fabric factory',
    'phone_number': '+201001234567',
    'category': 3,
    'is_verified': true,
    'follower_count': 240,
    if (!identical(featured, _absent)) 'is_featured': featured,
  };

  Map<String, dynamic> productJson({Object? featured = _absent}) => {
    'id': 55,
    'business': 7,
    'category': 3,
    'name': 'Cotton Roll',
    'description': 'Raw cotton fabric roll',
    'price': '199.99',
    'currency': 'EGP',
    'image': null,
    'is_active': true,
    'variants': [],
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
    if (!identical(featured, _absent)) 'is_featured': featured,
  };

  Map<String, dynamic> postJson({Object? featured = _absent}) => {
    'id': 1,
    'business': 7,
    'caption': 'New season',
    'image': null,
    'likes_count': 2,
    'comments_count': 1,
    'shares_count': 0,
    'is_liked': false,
    'is_saved': false,
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
    if (!identical(featured, _absent)) 'is_featured': featured,
  };

  Map<String, dynamic> reelJson({Object? featured = _absent}) => {
    'id': 2,
    'business': 7,
    'caption': 'Factory tour',
    'video': 'https://cdn.example.com/r.mp4',
    'thumbnail': 'https://cdn.example.com/r.jpg',
    'duration_seconds': 20,
    'likes_count': 0,
    'comments_count': 0,
    'shares_count': 0,
    'is_liked': false,
    'is_saved': false,
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
    if (!identical(featured, _absent)) 'is_featured': featured,
  };

  group('DTO parsing: true / false / missing key', () {
    test('BusinessProfileResponseDto', () {
      expect(
        BusinessProfileResponseDto.fromJson(
          businessJson(featured: true),
        ).isFeatured,
        isTrue,
      );
      expect(
        BusinessProfileResponseDto.fromJson(
          businessJson(featured: false),
        ).isFeatured,
        isFalse,
      );
      expect(
        BusinessProfileResponseDto.fromJson(businessJson()).isFeatured,
        isFalse,
      );
    });

    test('BusinessProfileResponseDto.toJson round-trips is_featured', () {
      final dto = BusinessProfileResponseDto.fromJson(
        businessJson(featured: true),
      );
      expect(dto.toJson()['is_featured'], isTrue);
    });

    test('ProductResponseDto + toEntity', () {
      final yes = ProductResponseDto.fromJson(productJson(featured: true));
      final no = ProductResponseDto.fromJson(productJson(featured: false));
      final missing = ProductResponseDto.fromJson(productJson());
      expect(yes.isFeatured, isTrue);
      expect(yes.toEntity().isFeatured, isTrue);
      expect(no.toEntity().isFeatured, isFalse);
      expect(missing.toEntity().isFeatured, isFalse);
    });

    test('PostPublicResponseDto + toEntity', () {
      final yes = PostPublicResponseDto.fromJson(postJson(featured: true));
      final no = PostPublicResponseDto.fromJson(postJson(featured: false));
      final missing = PostPublicResponseDto.fromJson(postJson());
      expect(yes.toEntity().isFeatured, isTrue);
      expect(no.toEntity().isFeatured, isFalse);
      expect(missing.toEntity().isFeatured, isFalse);
    });

    test('ReelPublicResponseDto + toEntity', () {
      final yes = ReelPublicResponseDto.fromJson(reelJson(featured: true));
      final no = ReelPublicResponseDto.fromJson(reelJson(featured: false));
      final missing = ReelPublicResponseDto.fromJson(reelJson());
      expect(yes.toEntity().isFeatured, isTrue);
      expect(no.toEntity().isFeatured, isFalse);
      expect(missing.toEntity().isFeatured, isFalse);
    });
  });

  group('entities: default, copyWith, equality', () {
    test('BusinessProfile', () {
      const base = BusinessProfile(
        id: 1,
        businessName: 'A',
        businessType: BusinessType.trader,
        country: 'Egypt',
        city: 'Cairo',
        isVerified: false,
      );
      expect(base.isFeatured, isFalse);
      final featured = base.copyWith(isFeatured: true);
      expect(featured.isFeatured, isTrue);
      expect(featured, isNot(equals(base)));
      expect(featured.copyWith(isFeatured: false), equals(base));
    });

    test('Product', () {
      const base = Product(
        id: 1,
        businessId: 1,
        categoryId: 1,
        name: 'P',
        description: '',
        price: '1.00',
        currency: Currency.egp,
      );
      expect(base.isFeatured, isFalse);
      final featured = base.copyWith(isFeatured: true);
      expect(featured.isFeatured, isTrue);
      expect(featured, isNot(equals(base)));
    });

    test('PublicPost', () {
      const base = PublicPost(id: 1, businessId: 1, caption: 'c');
      expect(base.isFeatured, isFalse);
      final featured = base.copyWith(isFeatured: true);
      expect(featured.isFeatured, isTrue);
      expect(featured, isNot(equals(base)));
    });

    test('PublicReel', () {
      const base = PublicReel(id: 1, businessId: 1, caption: 'c');
      expect(base.isFeatured, isFalse);
      final featured = base.copyWith(isFeatured: true);
      expect(featured.isFeatured, isTrue);
      expect(featured, isNot(equals(base)));
    });
  });

  group('repositories map is_featured into the entities', () {
    late Dio dio;
    late DioAdapter adapter;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(ErrorInterceptor());
    });

    test('public profile repository', () async {
      adapter.onGet(
        '/api/v1/businesses/7/',
        (server) => server.reply(200, businessJson(featured: true)),
      );
      adapter.onGet(
        '/api/v1/businesses/8/',
        (server) => server.reply(200, businessJson(featured: false)),
      );
      final repository = BusinessProfilePublicRepositoryImpl(dio: dio);

      expect((await repository.fetchPublicProfile(7))!.isFeatured, isTrue);
      expect((await repository.fetchPublicProfile(8))!.isFeatured, isFalse);
    });

    test('search repository: business AND product results', () async {
      adapter.onGet(
        '/api/v1/search/',
        (server) => server.reply(200, {
          'items': [
            {...businessJson(featured: true), 'result_type': 'business'},
            {...productJson(featured: true), 'result_type': 'product'},
            {...businessJson(featured: false), 'result_type': 'business'},
            {...productJson(featured: false), 'result_type': 'product'},
          ],
          'next_cursor': null,
        }),
        queryParameters: {},
      );
      final repository = SearchRepositoryImpl(dio: dio);

      final page = await repository.search();

      expect((page.items[0] as BusinessSearchResult).business.isFeatured,
          isTrue);
      expect((page.items[1] as ProductSearchResult).product.isFeatured, isTrue);
      expect((page.items[2] as BusinessSearchResult).business.isFeatured,
          isFalse);
      expect(
        (page.items[3] as ProductSearchResult).product.isFeatured,
        isFalse,
      );
    });
  });
}

const Object _absent = Object();
