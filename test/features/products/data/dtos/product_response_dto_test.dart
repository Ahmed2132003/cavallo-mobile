import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/products/data/dtos/product_response_dto.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';

void main() {
  group('ProductResponseDto', () {
    test('fromJson parses the real P-032 response shape, including nested variants', () {
      final json = {
        'id': 10,
        'business': 1,
        'category': 3,
        'name': 'Cotton T-Shirt',
        'description': 'Plain white cotton t-shirt',
        'price': '199.99',
        'currency': 'EGP',
        'image': 'https://cdn.example.com/products/10.png',
        'is_active': true,
        'variants': [
          {'id': 1, 'name': 'Size', 'value': 'Large'},
        ],
        'created_at': '2026-09-01T10:00:00Z',
        'updated_at': '2026-09-02T12:30:00Z',
      };

      final dto = ProductResponseDto.fromJson(json);

      expect(dto.id, 10);
      expect(dto.business, 1);
      expect(dto.category, 3);
      expect(dto.price, '199.99');
      expect(dto.currency, 'EGP');
      expect(dto.image, 'https://cdn.example.com/products/10.png');
      expect(dto.isActive, true);
      expect(dto.variants, hasLength(1));
      expect(dto.createdAt, DateTime.parse('2026-09-01T10:00:00Z'));
    });

    test('fromJson handles a null image and empty variants (optional fields)', () {
      final json = {
        'id': 11,
        'business': 1,
        'category': 3,
        'name': 'No Image Product',
        'description': '',
        'price': '10.00',
        'currency': 'SAR',
        'image': null,
        'is_active': true,
        'variants': [],
        'created_at': null,
        'updated_at': null,
      };

      final dto = ProductResponseDto.fromJson(json);

      expect(dto.image, isNull);
      expect(dto.variants, isEmpty);
      expect(dto.createdAt, isNull);
    });

    test('toEntity maps currency, businessId, and categoryId correctly', () {
      const dto = ProductResponseDto(
        id: 10,
        business: 1,
        category: 3,
        name: 'Cotton T-Shirt',
        description: 'desc',
        price: '199.99',
        currency: 'AED',
        image: null,
        isActive: true,
        variants: [],
        createdAt: null,
        updatedAt: null,
      );

      final entity = dto.toEntity();

      expect(entity.businessId, 1);
      expect(entity.categoryId, 3);
      expect(entity.currency, Currency.aed);
    });
  });
}