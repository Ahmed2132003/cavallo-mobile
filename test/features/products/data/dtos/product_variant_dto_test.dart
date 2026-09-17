import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/products/data/dtos/product_variant_dto.dart';

void main() {
  group('ProductVariantDto', () {
    test('fromJson parses all fields', () {
      final dto = ProductVariantDto.fromJson({
        'id': 5,
        'name': 'Size',
        'value': 'Large',
      });

      expect(dto.id, 5);
      expect(dto.name, 'Size');
      expect(dto.value, 'Large');
    });

    test('toEntity maps to a matching ProductVariant', () {
      const dto = ProductVariantDto(id: 5, name: 'Size', value: 'Large');
      final entity = dto.toEntity();

      expect(entity.id, 5);
      expect(entity.name, 'Size');
      expect(entity.value, 'Large');
    });
  });

  group('ProductVariantRequestDto', () {
    test('toJson never includes a product field', () {
      const dto = ProductVariantRequestDto(name: 'Color', value: 'Red');

      final json = dto.toJson();

      expect(json, {'name': 'Color', 'value': 'Red'});
      expect(json.containsKey('product'), isFalse);
    });
  });
}