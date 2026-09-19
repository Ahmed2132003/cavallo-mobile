import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/product_entity.dart';
import '../domain/product_repository.dart';
import 'dtos/product_response_dto.dart';

/// Part P-033 scope: `lib/features/products/data/` — the
/// [ProductRepository] implementation. Mirrors
/// `BusinessProfileRepositoryImpl`'s (Part P-028A) exact conventions:
/// depends only on `dioClientProvider` (never constructs its own
/// `Dio`), maps DTO → domain entity itself, and does NOT catch/re-wrap
/// [DioException] anywhere — every failure surfaces to the caller as-is,
/// with `.error` already a typed `ApiFailure` (Part P-004's
/// `ErrorInterceptor`). Confirmed against P-032's real, documented
/// status-code behavior: a cross-business PATCH/DELETE 403s
/// (`PermissionDenied`, server-side object check inside
/// `perform_update`/`perform_destroy`) and maps to `AuthFailure` —
/// `ErrorInterceptor._mapStatusCode` treats 401 and 403 identically —
/// there is no separate `PermissionFailure` type to special-case here.
///
/// ### Image upload — one request body, not two
///
/// P-032's `ProductSerializer` has a single `image` field alongside
/// every other product field on the SAME create/update request — there
/// is no separate "upload image" endpoint (confirmed from P-032's own
/// progress notes, not assumed). So:
/// * When [File]? `imageFile` is `null`, [createProduct]/[updateProduct]
///   send a plain JSON body (a `Map`) — no multipart needed for a
///   request with no file in it.
/// * When `imageFile` is provided, the WHOLE body (every other field
///   included) becomes a single [FormData] — DRF's parser accepts both
///   shapes on the same view, so this is a client-side optimization
///   (skip multipart when there's nothing to attach), not a backend
///   requirement either way.
///
/// ### Manual-testing note — MinIO internal hostname (not a P-033 bug)
///
/// During this part's own manual verification, a created product's
/// image appeared as the "no image" placeholder in `ProductListScreen`
/// despite a successful 201 create. A temporary debug print (since
/// removed) confirmed the backend's own response carries a fully
/// correct `image` URL — the create request, the DTO parsing, and the
/// list screen's rendering are all correct end to end. The URL itself
/// simply isn't reachable from outside the backend's Docker network in
/// this local dev environment (its host segment is the internal
/// container hostname `minio`, e.g.
/// `http://minio:9000/scd-dev-media/...`), which no device outside that
/// Docker network — including the Android emulator — can resolve. This
/// is a local backend/infra configuration matter (the MinIO
/// public/presigned-URL endpoint needs to be set to a host reachable
/// from outside its container network), entirely outside this part's
/// and this file's scope. No Flutter-side change is needed or
/// appropriate here — once the backend serves a reachable URL, this
/// same code renders it with no changes required.
class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _productsPath = '/api/v1/products/';

  static String _detailPath(int productId) => '/api/v1/products/$productId/';

  @override
  Future<PaginatedResponse<Product>> fetchOwnProducts() async {
    final response = await _dio.get<Map<String, dynamic>>(_productsPath);
    return PaginatedResponse.fromJson<Product>(
      response.data!,
      (json) => ProductResponseDto.fromJson(json).toEntity(),
    );
  }

  @override
  Future<Product> createProduct({
    required int categoryId,
    required String name,
    required String description,
    required String price,
    required Currency currency,
    File? imageFile,
    bool isActive = true,
  }) async {
    final fields = <String, dynamic>{
      'category': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency.toWire(),
      'is_active': isActive,
    };

    final data = imageFile == null
        ? fields
        : await _toFormData(fields, imageFile);

    final response = await _dio.post<Map<String, dynamic>>(
      _productsPath,
      data: data,
    );

    return ProductResponseDto.fromJson(response.data!).toEntity();
  }

  @override
  Future<Product> updateProduct({
    required int productId,
    int? categoryId,
    String? name,
    String? description,
    String? price,
    Currency? currency,
    File? imageFile,
    bool? isActive,
  }) async {
    final fields = <String, dynamic>{
      if (categoryId != null) 'category': categoryId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (price != null) 'price': price,
      if (currency != null) 'currency': currency.toWire(),
      if (isActive != null) 'is_active': isActive,
    };

    final data = imageFile == null
        ? fields
        : await _toFormData(fields, imageFile);

    final response = await _dio.patch<Map<String, dynamic>>(
      _detailPath(productId),
      data: data,
    );

    return ProductResponseDto.fromJson(response.data!).toEntity();
  }

  @override
  Future<void> deleteProduct(int productId) async {
    await _dio.delete<void>(_detailPath(productId));
  }

  /// Builds a [FormData] carrying every field in [fields] plus the
  /// image under the `image` key — matching P-032's `ProductSerializer`
  /// field name exactly. `is_active` (a [bool] in [fields]) is
  /// stringified here (`'true'`/`'false'`) since multipart form fields
  /// are always strings on the wire; DRF's `BooleanField` accepts both
  /// string forms on a multipart-parsed request. The plain-JSON path
  /// above needs no such conversion — Dio's JSON encoder sends a real
  /// boolean.
  Future<FormData> _toFormData(
    Map<String, dynamic> fields,
    File imageFile,
  ) async {
    final stringFields = fields.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    return FormData.fromMap({
      ...stringFields,
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.uri.pathSegments.last,
      ),
    });
  }
}

/// Exposes [ProductRepository] to the rest of the app via Riverpod, per
/// this project's established pattern (`dioClientProvider`,
/// `businessProfileRepositoryProvider`) — a `Provider`, not a
/// singleton/global, so it's overridable in tests and in this part's
/// own screens.
final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepositoryImpl(dio: ref.watch(dioClientProvider)),
);