import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_variant_entity.dart';

void main() {
  group('Currency.fromWire / toWire', () {
    test('round-trips all four locked backend choices', () {
      expect(Currency.fromWire('EGP'), Currency.egp);
      expect(Currency.fromWire('SAR'), Currency.sar);
      expect(Currency.fromWire('AED'), Currency.aed);
      expect(Currency.fromWire('JOD'), Currency.jod);

      expect(Currency.egp.toWire(), 'EGP');
      expect(Currency.sar.toWire(), 'SAR');
      expect(Currency.aed.toWire(), 'AED');
      expect(Currency.jod.toWire(), 'JOD');
    });

    test('throws FormatException on an unrecognized value', () {
      expect(
        () => Currency.fromWire('USD'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Product', () {
    const base = Product(
      id: 10,
      businessId: 1,
      categoryId: 3,
      name: 'Cotton T-Shirt',
      description: 'Plain white cotton t-shirt',
      price: '199.99',
      currency: Currency.egp,
      imageUrl: 'https://cdn.example.com/products/10.png',
      isActive: true,
      variants: [ProductVariant(id: 1, name: 'Size', value: 'Large')],
    );

    test('equality/hashCode compare every field, including variants', () {
      const identical_ = Product(
        id: 10,
        businessId: 1,
        categoryId: 3,
        name: 'Cotton T-Shirt',
        description: 'Plain white cotton t-shirt',
        price: '199.99',
        currency: Currency.egp,
        imageUrl: 'https://cdn.example.com/products/10.png',
        isActive: true,
        variants: [ProductVariant(id: 1, name: 'Size', value: 'Large')],
      );
      final differentVariants = base.copyWith(variants: const []);

      expect(base, identical_);
      expect(base.hashCode, identical_.hashCode);
      expect(base, isNot(differentVariants));
    });

    test('copyWith only overrides the given fields', () {
      final updated = base.copyWith(name: 'New Name', isActive: false);

      expect(updated.name, 'New Name');
      expect(updated.isActive, false);
      expect(updated.id, base.id);
      expect(updated.price, base.price);
      expect(updated.variants, base.variants);
    });

    test('imageUrl and variants default sensibly for a fresh product', () {
      const minimal = Product(
        id: 1,
        businessId: 1,
        categoryId: 1,
        name: 'New Product',
        description: '',
        price: '10.00',
        currency: Currency.sar,
      );

      expect(minimal.imageUrl, isNull);
      expect(minimal.isActive, true);
      expect(minimal.variants, isEmpty);
    });
  });
}