import '../../domain/category_entity.dart';

/// Maps `categories.services.build_category_tree()`'s exact real shape
/// (Part P-025, confirmed by reading the backend source directly):
/// `{"id", "name", "slug", "children": [...]}`, recursively — every
/// node in the tree, at every depth, has this same shape.
class CategoryNodeDto {
  const CategoryNodeDto({
    required this.id,
    required this.name,
    required this.slug,
    required this.children,
  });

  factory CategoryNodeDto.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'] as List<dynamic>? ?? const [];
    return CategoryNodeDto(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      children: rawChildren
          .map((e) => CategoryNodeDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final String name;
  final String slug;
  final List<CategoryNodeDto> children;

  CategoryNode toEntity() {
    return CategoryNode(
      id: id,
      name: name,
      slug: slug,
      children: children.map((c) => c.toEntity()).toList(),
    );
  }
}