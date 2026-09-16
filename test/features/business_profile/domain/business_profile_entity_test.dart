import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';

void main() {
  group('BusinessType.fromWire / toWire', () {
    test('round-trips both real backend choices', () {
      expect(BusinessType.fromWire('trader'), BusinessType.trader);
      expect(BusinessType.fromWire('factory'), BusinessType.factory);
      expect(BusinessType.trader.toWire(), 'trader');
      expect(BusinessType.factory.toWire(), 'factory');
    });

    test('throws FormatException on an unrecognized value', () {
      expect(
        () => BusinessType.fromWire('wholesaler'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BusinessProfile', () {
    const base = BusinessProfile(
      id: 7,
      businessName: 'Al Ananka Store',
      businessType: BusinessType.trader,
      country: 'Egypt',
      city: 'Cairo',
      description: 'Fashion trader',
      phoneNumber: '+201001234567',
      categoryId: 3,
      isVerified: false,
      followerCount: 12400,
    );

    test('equality/hashCode compare every field', () {
      const identical_ = BusinessProfile(
        id: 7,
        businessName: 'Al Ananka Store',
        businessType: BusinessType.trader,
        country: 'Egypt',
        city: 'Cairo',
        description: 'Fashion trader',
        phoneNumber: '+201001234567',
        categoryId: 3,
        isVerified: false,
        followerCount: 12400,
      );
      final differentCategory = base.copyWith(categoryId: 4);

      expect(base, identical_);
      expect(base.hashCode, identical_.hashCode);
      expect(base, isNot(differentCategory));
    });

    test('copyWith only overrides the given fields', () {
      final updated = base.copyWith(businessName: 'New Name', isVerified: true);

      expect(updated.businessName, 'New Name');
      expect(updated.isVerified, true);
      // Everything else untouched.
      expect(updated.id, base.id);
      expect(updated.country, base.country);
      expect(updated.categoryId, base.categoryId);
      expect(updated.followerCount, base.followerCount);
    });

    test('categoryId, phoneNumber, and description all default sensibly', () {
      const minimal = BusinessProfile(
        id: 1,
        businessName: 'New Business',
        businessType: BusinessType.factory,
        country: 'Egypt',
        city: 'Alexandria',
        isVerified: false,
      );

      expect(minimal.categoryId, isNull);
      expect(minimal.phoneNumber, isNull);
      expect(minimal.description, '');
      expect(minimal.followerCount, 0);
    });
  });
}
