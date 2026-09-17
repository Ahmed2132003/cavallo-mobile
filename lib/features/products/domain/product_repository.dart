import 'dart:io';

import '../../../core/network/paginated_response.dart';
import 'product_entity.dart';
import 'product_variant_entity.dart';

/// Part P-033 scope: the domain-facing contract the presentation layer
/// (provider + screens, later steps of this part) depends on. The
/// implementation (`product_repository_impl.dart`, STEP 4) is the only
/// thing that knows this is backed by HTTP/multipart/DTOs — mirrors
/// `BusinessProfileRepository`'s exact split (Part P-028A).
///
/// All product-CRUD methods below call `/api/v1/products/` /
/// `/api/v1/products/<pk>/` (Part P-032) — ownership is always resolved
/// server-side from `request.user.business_profile`, never from a
/// client-supplied id, so there is deliberately no `businessId`
/// parameter anywhere on this contract.
///
/// **Image upload note:** P-032's `ProductSerializer` has a single
/// `image` field alongside every other product field on the SAME
/// create/update request (one multipart body) — there is no separate
/// "upload image" endpoint. [createProduct]/[updateProduct] therefore
/// take an optional [imageFile] as just another field of the same call;
/// the "upload-in-progress / retry" UX this part's Acceptance Criteria
/// asks for applies to that whole save call, not to the image alone.
abstract class ProductRepository {
  /// Calls `GET /api/v1/products/` — lists only the signed-in Business
  /// account's own products (server-side filtered from
  /// `request.user.business_profile`, Part P-032). Cursor-paginated;
  /// this part's own scope only consumes the first page (see
  /// `PaginatedResponse`'s own docstring) — no "load more" UI is part
  /// of this part's Acceptance Criteria.
  Future<PaginatedResponse<Product>> fetchOwnProducts();

  /// Calls `POST /api/v1/products/` (multipart). `business` is never
  /// sent — P-032's `perform_create()` always attributes ownership
  /// server-side; a spoofed value would be silently ignored anyway.
  /// [imageFile] is optional — P-032's `image` field is
  /// `null=True, blank=True`.
  Future<Product> createProduct({
    required int categoryId,
    required String name,
    required String description,
    required String price,
    required Currency currency,
    File? imageFile,
    bool isActive = true,
  });

  /// Calls `PATCH /api/v1/products/<pk>/` (multipart when [imageFile]
  /// is provided, plain JSON otherwise). Every parameter is optional —
  /// only non-null ones are sent, matching a real partial update.
  /// Server-side, P-032's `perform_update()` raises `PermissionDenied`
  /// if [productId] doesn't belong to the signed-in business's own
  /// products — surfaces here as a normal thrown `ApiFailure`
  /// (Part P-004), nothing special-cased in this contract for it.
  Future<Product> updateProduct({
    required int productId,
    int? categoryId,
    String? name,
    String? description,
    String? price,
    Currency? currency,
    File? imageFile,
    bool? isActive,
  });

  /// Calls `DELETE /api/v1/products/<pk>/` — P-032's inherited soft
  /// delete (`is_deleted=True`), never a real row deletion. Same
  /// ownership check as [updateProduct].
  Future<void> deleteProduct(int productId);
}

/// Part P-032B scope: the separate write path for a Product's variants,
/// scoped under `/api/v1/products/<product_pk>/variants/...`. Kept as
/// its own contract (not folded into [ProductRepository]) because it
/// operates one relationship-hop deeper (Product → ProductVariant) and
/// every method needs the parent [productId] explicitly — mirrors how
/// P-032B itself is a genuinely separate endpoint group, not an
/// extension of `ProductSerializer`'s own (still read-only) nested
/// `variants` field.
abstract class ProductVariantRepository {
  /// Calls `POST /api/v1/products/<productId>/variants/`.
  Future<ProductVariant> createVariant({
    required int productId,
    required String name,
    required String value,
  });

  /// Calls `PATCH /api/v1/products/<productId>/variants/<variantId>/`.
  Future<ProductVariant> updateVariant({
    required int productId,
    required int variantId,
    String? name,
    String? value,
  });

  /// Calls `DELETE /api/v1/products/<productId>/variants/<variantId>/`.
  /// Per P-032B's own note, this is a REAL hard delete on the backend
  /// (`ProductVariant` has no `SoftDeleteModel` mixin) — not
  /// recoverable, unlike [ProductRepository.deleteProduct].
  Future<void> deleteVariant({required int productId, required int variantId});
}