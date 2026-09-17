import '../../domain/product_entity.dart';
import 'product_variant_dto.dart';

/// Maps `products.serializers.ProductSerializer`'s exact real read
/// shape (Part P-032, confirmed from its own progress notes — not the
/// original part spec's literal field guess):
/// `{id, business, category, name, description, price, currency, image,
/// is_active, variants, created_at, updated_at}`.
///
/// `business` is a bare business-profile id (`int`), never a nested
/// object — P-032's own handoff note flags this explicitly: "the
/// Flutter side needs a separate `GET /api/v1/businesses/{id}/` call
/// (P-026) for the business's display name/logo alongside a product."
/// That call is out of this part's scope (not needed by any of P-033's
/// own acceptance criteria) — `businessId` is carried on [Product] for
/// a future part to use.
class ProductResponseDto {
  const ProductResponseDto({
    required this.id,
    required this.business,
    required this.category,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.image,
    required this.isActive,
    required this.variants,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductResponseDto.fromJson(Map<String, dynamic> json) {
    final rawVariants = json['variants'] as List<dynamic>? ?? const [];
    return ProductResponseDto(
      id: json['id'] as int,
      business: json['business'] as int,
      category: json['category'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: json['price'] as String,
      currency: json['currency'] as String,
      image: json['image'] as String?,
      isActive: json['is_active'] as bool,
      variants: rawVariants
          .map((e) => ProductVariantDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  final int id;
  final int business;
  final int category;
  final String name;
  final String description;

  /// Raw decimal string from the backend. See `product_entity.dart`'s
  /// module docstring for why [Product.price] stays a [String] too.
  final String price;

  final String currency;
  final String? image;
  final bool isActive;
  final List<ProductVariantDto> variants;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product toEntity() {
    return Product(
      id: id,
      businessId: business,
      categoryId: category,
      name: name,
      description: description,
      price: price,
      currency: Currency.fromWire(currency),
      imageUrl: image,
      isActive: isActive,
      variants: variants.map((v) => v.toEntity()).toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}