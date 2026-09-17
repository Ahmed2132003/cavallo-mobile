import '../../domain/product_variant_entity.dart';

/// Maps `products.serializers.ProductVariantSerializer`'s read-only
/// nested shape (Part P-032) — `{id, name, value}` — which is exactly
/// the same shape Part P-032B's standalone variant read endpoints
/// (`GET /api/v1/products/<product_pk>/variants/<pk>/`, and the create/
/// update responses) return, so one DTO covers both.
class ProductVariantDto {
  const ProductVariantDto({
    required this.id,
    required this.name,
    required this.value,
  });

  factory ProductVariantDto.fromJson(Map<String, dynamic> json) {
    return ProductVariantDto(
      id: json['id'] as int,
      name: json['name'] as String,
      value: json['value'] as String,
    );
  }

  final int id;
  final String name;
  final String value;

  ProductVariant toEntity() =>
      ProductVariant(id: id, name: name, value: value);
}

/// The write body for Part P-032B's variant create/update endpoints
/// (`POST`/`PATCH /api/v1/products/<product_pk>/variants/...`).
/// `product` is deliberately never a field here — P-032B's own progress
/// note confirms it is resolved exclusively from the URL's
/// `product_pk`, never from the request body
/// (`ProductVariantWriteSerializer` has no writable `product` field).
class ProductVariantRequestDto {
  const ProductVariantRequestDto({required this.name, required this.value});

  final String name;
  final String value;

  Map<String, dynamic> toJson() => {'name': name, 'value': value};
}