import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/products/domain/product_variant_entity.dart';

void main() {
  group('ProductVariant', () {
    const base = ProductVariant(id: 1, name: 'Size', value: 'Large');

    test('equality/hashCode compare every field', () {
      const identical_ = ProductVariant(id: 1, name: 'Size', value: 'Large');
      final differentValue = base.copyWith(value: 'Medium');

      expect(base, identical_);
      expect(base.hashCode, identical_.hashCode);
      expect(base, isNot(differentValue));
    });

    test('copyWith only overrides the given fields', () {
      final updated = base.copyWith(value: 'Medium');

      expect(updated.value, 'Medium');
      expect(updated.id, base.id);
      expect(updated.name, base.name);
    });

    test('id is nullable for a not-yet-persisted variant', () {
      const notYetSaved = ProductVariant(name: 'Color', value: 'Red');

      expect(notYetSaved.id, isNull);
    });
  });
}