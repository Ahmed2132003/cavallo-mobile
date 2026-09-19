import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/product_entity.dart';
import '../domain/product_public_repository.dart';
import 'dtos/product_response_dto.dart';

/// Part P-034 scope: [ProductPublicRepository] implementation.
///
/// Follows `BusinessProfilePublicRepositoryImpl`'s (Part P-029) exact
/// conventions: depends only on `dioClientProvider`, reuses P-033's
/// `ProductResponseDto` (the public endpoints return the very same
/// `ProductSerializer` shape — no parallel DTO), and interprets a 404
/// HERE rather than in `core/network`, which must stay feature-agnostic.
/// Every other failure is rethrown untouched, so `.error` stays a typed
/// `ApiFailure` from `ErrorInterceptor` (Part P-004).
class ProductPublicRepositoryImpl implements ProductPublicRepository {
  ProductPublicRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _publicListPath = '/api/v1/products/public/';

  static String _detailPath(int id) => '/api/v1/products/$id/';

  @override
  Future<Product?> fetchPublicProduct(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_detailPath(id));
      final product = ProductResponseDto.fromJson(response.data!).toEntity();
      // The backend's detail GET also serves inactive (hidden) products.
      // A public reader must not see them — treated as not found.
      if (!product.isActive) {
        return null;
      }
      return product;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Product genuinely doesn't exist — a real, renderable state,
        // never an error.
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<PaginatedResponse<Product>> fetchBusinessProducts(
    int businessId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _publicListPath,
      queryParameters: {'business_id': businessId},
    );
    return PaginatedResponse.fromJson<Product>(
      response.data!,
      (json) => ProductResponseDto.fromJson(json).toEntity(),
    );
  }
}

/// Exposes [ProductPublicRepository] via Riverpod — a plain `Provider`
/// so tests and screens can override it, same pattern as
/// `productRepositoryProvider` (Part P-033) and
/// `businessProfilePublicRepositoryProvider` (Part P-029).
final productPublicRepositoryProvider = Provider<ProductPublicRepository>(
  (ref) => ProductPublicRepositoryImpl(dio: ref.watch(dioClientProvider)),
);
