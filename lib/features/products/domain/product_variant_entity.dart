/// Part P-033 scope: the clean domain representation of a single
/// Product variant (a simple name/value option pair — e.g. `Size:
/// Large`), as returned by `products.serializers.ProductVariantSerializer`'s
/// read-only nested output (Part P-032) and by the standalone variant
/// write endpoints (Part P-032B).
///
/// This is a plain value object — Part P-032B's own progress note
/// confirms `ProductVariant` has no independent existence without its
/// parent `Product` (`on_delete=CASCADE`, and a REAL hard delete, not
/// soft), so this entity is always used in the context of a specific
/// product id, never persisted or fetched on its own.
library;

class ProductVariant {
  const ProductVariant({this.id, required this.name, required this.value});

  /// `null` for a variant the user has added in the create/edit form
  /// but not yet persisted to the backend (the
  /// `POST /api/v1/products/<product_pk>/variants/` call from Part
  /// P-032B hasn't run for it yet). Always non-null for a variant read
  /// back from the backend.
  final int? id;

  final String name;
  final String value;

  ProductVariant copyWith({int? id, String? name, String? value}) {
    return ProductVariant(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductVariant &&
          other.id == id &&
          other.name == name &&
          other.value == value);

  @override
  int get hashCode => Object.hash(id, name, value);

  @override
  String toString() => 'ProductVariant(id: $id, name: $name, value: $value)';
}