import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_profile/data/dtos/business_profile_create_request_dto.dart';

void main() {
  test('toJson includes every field when all are provided', () {
    const dto = BusinessProfileCreateRequestDto(
      businessName: 'Al Ananka Store',
      businessType: 'trader',
      country: 'Egypt',
      city: 'Cairo',
      description: 'Fashion trader',
      categoryId: 3,
      phoneNumber: '+201001234567',
    );

    expect(dto.toJson(), {
      'business_name': 'Al Ananka Store',
      'business_type': 'trader',
      'country': 'Egypt',
      'city': 'Cairo',
      'description': 'Fashion trader',
      'category': 3,
      'phone_number': '+201001234567',
    });
  });

  test('toJson omits description/category/phone_number entirely when null '
      '(nothing to clear on a brand-new profile)', () {
    const dto = BusinessProfileCreateRequestDto(
      businessName: 'New Factory',
      businessType: 'factory',
      country: 'Egypt',
      city: 'Giza',
    );

    expect(dto.toJson(), {
      'business_name': 'New Factory',
      'business_type': 'factory',
      'country': 'Egypt',
      'city': 'Giza',
    });
  });
}
