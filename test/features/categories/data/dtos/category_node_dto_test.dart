import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/categories/data/dtos/category_node_dto.dart';

void main() {
  group('CategoryNodeDto', () {
    test('fromJson parses a nested tree recursively', () {
      final dto = CategoryNodeDto.fromJson({
        'id': 1,
        'name': 'Fashion',
        'slug': 'fashion',
        'children': [
          {'id': 2, 'name': 'Men', 'slug': 'men', 'children': []},
        ],
      });

      expect(dto.id, 1);
      expect(dto.children, hasLength(1));
      expect(dto.children.single.name, 'Men');
    });

    test('fromJson defaults children to an empty list when absent', () {
      final dto = CategoryNodeDto.fromJson({
        'id': 5,
        'name': 'Shoes',
        'slug': 'shoes',
      });

      expect(dto.children, isEmpty);
    });

    test('toEntity maps the full nested tree to matching CategoryNodes', () {
      final dto = CategoryNodeDto.fromJson({
        'id': 1,
        'name': 'Fashion',
        'slug': 'fashion',
        'children': [
          {'id': 2, 'name': 'Men', 'slug': 'men', 'children': []},
        ],
      });

      final entity = dto.toEntity();

      expect(entity.id, 1);
      expect(entity.children.single.id, 2);
      expect(entity.children.single.name, 'Men');
    });
  });
}