/// Part P-033 scope: the clean domain representation of a single
/// Product owned by the signed-in Business account — no transport
/// concerns (no raw JSON keys, no DTO types) cross this boundary,
/// mirroring `business_profile_entity.dart` (Part P-028A) and
/// `user_entity.dart` (Part P-020)'s exact pattern.
///
/// ### Field list — confirmed against the real backend (P-031/P-032/
/// P-032B), not assumed
///
/// * `currency` mirrors `products.models.Product.currency`'s locked
///   choice set exactly (Part P-031's own progress note: "locked
///   contract for P-032/P-033/Phase 11") — EGP/SAR/AED/JOD, no default
///   value.
/// * `price` is kept as a [String], not a [double]: DRF's
///   `ModelSerializer` serializes a `DecimalField` to a JSON string by
///   default (`COERCE_DECIMAL_TO_STRING`, on by default, never
///   overridden by P-032's `ProductSerializer`), so representing it as
///   anything else here risks a float round-trip precision loss the
///   backend itself never has. A later step's create/edit form parses
///   this only for the numeric `TextFormField`'s own validation, and
///   always sends the raw decimal string back on write.
/// * `businessId` is read-only here — P-032: `business` is in
///   `read_only_fields` on `ProductSerializer`; a `business`/
///   `business_id` key in a request body is silently dropped, never
///   honored.
/// * `imageUrl` is nullable — P-032's `image` field is
///   `null=True, blank=True`, optional on both read and write.
/// * `variants` is the read-only nested list P-032's `ProductSerializer`
///   still returns (`ProductVariantSerializer`, read-only in THAT
///   serializer). Variant create/update/delete goes through the
///   **separate** write path Part P-032B added
///   (`/api/v1/products/<product_pk>/variants/...`) — this entity only
///   carries what a GET/detail response already includes.
library;

import 'product_variant_entity.dart';

/// Mirrors `products.models.Product.currency`'s locked choice set
/// exactly (Part P-031's progress note). No default — a business must
/// state its own currency explicitly, matching the backend's own field
/// (no `default=` set), so there is deliberately no "first" value here
/// either.
enum Currency {
  egp,
  sar,
  aed,
  jod;

  /// Parses the backend's raw `currency` string. Throws
  /// [FormatException] on anything unrecognized rather than silently
  /// defaulting — mirrors `BusinessType.fromWire`'s exact convention
  /// (Part P-028A).
  static Currency fromWire(String value) {
    switch (value) {
      case 'EGP':
        return Currency.egp;
      case 'SAR':
        return Currency.sar;
      case 'AED':
        return Currency.aed;
      case 'JOD':
        return Currency.jod;
      default:
        throw FormatException('Unknown currency from backend: $value');
    }
  }

  /// Inverse of [fromWire] — used when this app needs to send the value
  /// back to the backend (create/update request bodies).
  String toWire() {
    switch (this) {
      case Currency.egp:
        return 'EGP';
      case Currency.sar:
        return 'SAR';
      case Currency.aed:
        return 'AED';
      case Currency.jod:
        return 'JOD';
    }
  }
}

/// A Product owned by the signed-in Business account, as far as the
/// domain/presentation layers need to know. Constructed only by
/// `ProductRepositoryImpl`'s mapping step (data layer, a later step of
/// this part) — see this file's module docstring for field-shape notes.
class Product {
  const Product({
    required this.id,
    required this.businessId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    this.imageUrl,
    this.isActive = true,
    this.variants = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int id;

  /// Read-only. See this file's module docstring.
  final int businessId;

  final int categoryId;
  final String name;
  final String description;

  /// Kept as the raw decimal string from the backend. See this file's
  /// module docstring for why this is not a [double].
  final String price;

  final Currency currency;

  /// Nullable — no image uploaded yet, or the backend's `image` field
  /// is genuinely empty.
  final String? imageUrl;

  final bool isActive;

  /// Read-only nested list. See this file's module docstring — variant
  /// writes go through a separate repository (a later step of this
  /// part).
  final List<ProductVariant> variants;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product copyWith({
    int? id,
    int? businessId,
    int? categoryId,
    String? name,
    String? description,
    String? price,
    Currency? currency,
    String? imageUrl,
    bool? isActive,
    List<ProductVariant>? variants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      variants: variants ?? this.variants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == id &&
          other.businessId == businessId &&
          other.categoryId == categoryId &&
          other.name == name &&
          other.description == description &&
          other.price == price &&
          other.currency == currency &&
          other.imageUrl == imageUrl &&
          other.isActive == isActive &&
          _variantsEqual(other.variants, variants) &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  static bool _variantsEqual(List<ProductVariant> a, List<ProductVariant> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    categoryId,
    name,
    description,
    price,
    currency,
    imageUrl,
    isActive,
    Object.hashAll(variants),
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Product(id: $id, name: $name, price: $price, currency: $currency, '
      'categoryId: $categoryId, businessId: $businessId)';
}