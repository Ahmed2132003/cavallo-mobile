import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_profile/data/dtos/business_profile_response_dto.dart';

void main() {
  group('BusinessProfileResponseDto.fromJson', () {
    test('parses a full real-shaped response (category and phone set)', () {
      final dto = BusinessProfileResponseDto.fromJson({
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
      });

      expect(dto.id, 7);
      expect(dto.businessName, 'Al Ananka Store');
      expect(dto.businessType, 'trader');
      expect(dto.country, 'Egypt');
      expect(dto.city, 'Cairo');
      expect(dto.description, 'Fashion trader');
      expect(dto.phoneNumber, '+201001234567');
      expect(dto.categoryId, 3);
      expect(dto.isVerified, true);
      expect(dto.followerCount, 12400);
    });

    test('a fresh profile with no category/phone yet: category null, '
        'phone_number the backend\'s own "" default', () {
      final dto = BusinessProfileResponseDto.fromJson({
        'id': 9,
        'business_name': 'New Factory',
        'business_type': 'factory',
        'country': 'Egypt',
        'city': 'Giza',
        'description': '',
        'phone_number': '',
        'category': null,
        'is_verified': false,
        'follower_count': 0,
      });

      expect(dto.categoryId, isNull);
      expect(dto.phoneNumber, '');
      expect(dto.description, '');
    });

    test(
      'missing description/phone_number/follower_count keys default safely',
      () {
        final dto = BusinessProfileResponseDto.fromJson({
          'id': 9,
          'business_name': 'New Factory',
          'business_type': 'factory',
          'country': 'Egypt',
          'city': 'Giza',
          'category': null,
          'is_verified': false,
        });

        expect(dto.description, '');
        expect(dto.phoneNumber, '');
        expect(dto.followerCount, 0);
      },
    );
  });

  test('toJson matches the backend field names exactly', () {
    const dto = BusinessProfileResponseDto(
      id: 7,
      businessName: 'Al Ananka Store',
      businessType: 'trader',
      country: 'Egypt',
      city: 'Cairo',
      description: 'Fashion trader',
      phoneNumber: '+201001234567',
      categoryId: 3,
      isVerified: true,
      followerCount: 12400,
    );

    expect(dto.toJson(), {
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
    });
  });
}
