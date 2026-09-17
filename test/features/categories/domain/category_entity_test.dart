import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/categories/domain/category_entity.dart';

void main() {
  group('CategoryNode', () {
    test('equality/hashCode compare id, name, slug, and every child', () {
      const a = CategoryNode(
        id: 1,
        name: 'Fashion',
        slug: 'fashion',
        children: [CategoryNode(id: 2, name: 'Men', slug: 'men')],
      );
      const identical_ = CategoryNode(
        id: 1,
        name: 'Fashion',
        slug: 'fashion',
        children: [CategoryNode(id: 2, name: 'Men', slug: 'men')],
      );
      const differentChildren = CategoryNode(
        id: 1,
        name: 'Fashion',
        slug: 'fashion',
        children: [CategoryNode(id: 3, name: 'Women', slug: 'women')],
      );

      expect(a, identical_);
      expect(a.hashCode, identical_.hashCode);
      expect(a, isNot(differentChildren));
    });

    test('children defaults to an empty list for a leaf category', () {
      const leaf = CategoryNode(id: 5, name: 'Shoes', slug: 'shoes');

      expect(leaf.children, isEmpty);
    });
  });
}