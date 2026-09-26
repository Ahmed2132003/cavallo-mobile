import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/search/domain/search_result_entity.dart';

BusinessProfile _business({int id = 1}) => BusinessProfile(
  id: id,
  businessName: 'Test Business',
  businessType: BusinessType.trader,
  country: 'Egypt',
  city: 'Cairo',
  isVerified: false,
);

Product _product({int id = 1}) => Product(
  id: id,
  businessId: 1,
  categoryId: 1,
  name: 'Test Product',
  description: '',
  price: '100.00',
  currency: Currency.egp,
);

void main() {
  group('SearchResult', () {
    test('BusinessSearchResult exposes resultType and id from its business', () {
      final result = BusinessSearchResult(_business(id: 7));

      expect(result.resultType, 'business');
      expect(result.id, 7);
    });

    test('ProductSearchResult exposes resultType and id from its product', () {
      final result = ProductSearchResult(_product(id: 9));

      expect(result.resultType, 'product');
      expect(result.id, 9);
    });

    test('equality is value-based on the wrapped entity', () {
      final a = BusinessSearchResult(_business(id: 1));
      final b = BusinessSearchResult(_business(id: 1));
      final c = ProductSearchResult(_product(id: 1));

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}