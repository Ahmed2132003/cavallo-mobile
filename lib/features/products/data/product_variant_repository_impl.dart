import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/product_repository.dart';
import '../domain/product_variant_entity.dart';
import 'dtos/product_variant_dto.dart';

/// Part P-032B scope: `lib/features/products/data/` — the
/// [ProductVariantRepository] implementation. Mirrors
/// `ProductRepositoryImpl`'s (this same part, STEP 4) exact
/// conventions, which themselves mirror `BusinessProfileRepositoryImpl`
/// (Part P-028A): depends only on `dioClientProvider` (never constructs
/// its own `Dio`), maps DTO → domain entity itself, and does NOT
/// catch/re-wrap [DioException] anywhere — every failure surfaces to
/// the caller as-is, with `.error` already a typed `ApiFailure` (Part
/// P-004's `ErrorInterceptor`).
///
/// Confirmed directly against the real backend
/// (`products/views.py`/`products/serializers.py`,
/// `github.com/Ahmed2132003/cavallo-app`), not assumed:
/// * A cross-business create/update/delete 403s (`PermissionDenied`,
///   an explicit `_check_owner` call inside each view's own write
///   path) — `ErrorInterceptor._mapStatusCode` maps 403 to
///   `AuthFailure`, exactly like `ProductRepositoryImpl`. There is no
///   separate `PermissionFailure` type to special-case here either.
/// * [deleteVariant] is a REAL hard delete on the backend
///   (`ProductVariant` inherits `TimestampedModel` only, never
///   `SoftDeleteModel` — confirmed in `products/models.py`) — not
///   recoverable, unlike `ProductRepositoryImpl.deleteProduct`'s soft
///   delete. See [ProductVariantRepository.deleteVariant]'s own
///   docstring in `product_repository.dart`.
/// * No image/multipart concern exists anywhere on this contract — a
///   variant is a plain `{name, value}` pair
///   (`ProductVariantWriteSerializer` has no `image`/`product` field at
///   all), so every request here is plain JSON, never `FormData` —
///   unlike `ProductRepositoryImpl`'s create/update, this class needs
///   no `_toFormData` helper at all.
class ProductVariantRepositoryImpl implements ProductVariantRepository {
  ProductVariantRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static String _listPath(int productId) =>
      '/api/v1/products/$productId/variants/';

  static String _detailPath(int productId, int variantId) =>
      '/api/v1/products/$productId/variants/$variantId/';

  @override
  Future<ProductVariant> createVariant({
    required int productId,
    required String name,
    required String value,
  }) async {
    final requestDto = ProductVariantRequestDto(name: name, value: value);

    final response = await _dio.post<Map<String, dynamic>>(
      _listPath(productId),
      data: requestDto.toJson(),
    );

    return ProductVariantDto.fromJson(response.data!).toEntity();
  }

  @override
  Future<ProductVariant> updateVariant({
    required int productId,
    required int variantId,
    String? name,
    String? value,
  }) async {
    // Built directly as a Map, matching
    // `BusinessProfileRepositoryImpl.updateProfile`'s own convention
    // for a conditional partial-update body — only the parameters
    // actually passed are sent, so an omitted `name`/`value` is left
    // untouched server-side rather than overwritten with a stale
    // value.
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (value != null) 'value': value,
    };

    final response = await _dio.patch<Map<String, dynamic>>(
      _detailPath(productId, variantId),
      data: body,
    );

    return ProductVariantDto.fromJson(response.data!).toEntity();
  }

  @override
  Future<void> deleteVariant({
    required int productId,
    required int variantId,
  }) async {
    await _dio.delete<void>(_detailPath(productId, variantId));
  }
}

/// Exposes [ProductVariantRepository] to the rest of the app via
/// Riverpod, per this project's established pattern
/// (`dioClientProvider`, `productRepositoryProvider`) — a `Provider`,
/// not a singleton/global, so it's overridable in tests and in this
/// part's own screens.
final productVariantRepositoryProvider = Provider<ProductVariantRepository>(
  (ref) => ProductVariantRepositoryImpl(dio: ref.watch(dioClientProvider)),
);