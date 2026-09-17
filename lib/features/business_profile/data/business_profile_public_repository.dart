import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/business_profile_entity.dart';
import '../domain/business_profile_public_repository.dart';
import 'dtos/business_profile_response_dto.dart';

/// Part P-029 scope: implementation of [BusinessProfilePublicRepository].
///
/// Mirrors `BusinessProfileRepositoryImpl` (Part P-028A) exactly:
/// depends only on `dioClientProvider` (never constructs its own [Dio]),
/// maps DTO → domain entity itself, and reuses
/// [BusinessProfileResponseDto] rather than declaring a second DTO for
/// an identical payload (the public view reuses the same DRF serializer
/// — confirmed in the backend source).
///
/// ### The 404 catch — same deliberate exception as `fetchMyProfile()`
///
/// `ErrorInterceptor._mapStatusCode` (Part P-004) only special-cases
/// 400/401/403/5xx, so a 404 falls through to `UnknownFailure`. "This
/// business doesn't exist" is endpoint-specific meaning, and
/// `core/network` stays feature-agnostic per the architecture rule —
/// so the interpretation lives here, in this feature's repository,
/// exactly where P-028A put the `/me/` 404 → `null` mapping. Every
/// other failure still rethrows unmodified.
///
/// The backend route is `<int:pk>/` (`businesses/urls.py`), so a
/// non-numeric id never reaches the view at all — callers must parse the
/// route's `:id` string to an `int` before calling this method (the
/// screen does; see Part P-029's presentation layer).
class BusinessProfilePublicRepositoryImpl
    implements BusinessProfilePublicRepository {
  BusinessProfilePublicRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static String _publicPath(int id) => '/api/v1/businesses/$id/';

  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_publicPath(id));
      return _toEntity(BusinessProfileResponseDto.fromJson(response.data!));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Business genuinely doesn't exist — a real, renderable state,
        // never an error. See this class's docstring.
        return null;
      }
      rethrow;
    }
  }

  /// Identical mapping step to `BusinessProfileRepositoryImpl._toEntity`
  /// (same DTO, same entity, same `phone_number: ""` → `null`
  /// normalization). Duplicated here rather than exported from the other
  /// repository: that method is private by design, and making it public
  /// or shared would couple the owner-facing repository to the public
  /// one for six lines of field copying. Flagged, not silent — if a
  /// third consumer of this DTO ever appears, move it onto the DTO as a
  /// `toEntity()` method instead of duplicating a third time.
  BusinessProfile _toEntity(BusinessProfileResponseDto dto) {
    return BusinessProfile(
      id: dto.id,
      businessName: dto.businessName,
      businessType: BusinessType.fromWire(dto.businessType),
      country: dto.country,
      city: dto.city,
      description: dto.description,
      phoneNumber: dto.phoneNumber.isEmpty ? null : dto.phoneNumber,
      categoryId: dto.categoryId,
      isVerified: dto.isVerified,
      followerCount: dto.followerCount,
    );
  }
}

/// Exposes [BusinessProfilePublicRepository] via Riverpod, same pattern
/// as `businessProfileRepositoryProvider` (Part P-028A) — a `Provider`,
/// overridable in widget tests.
final businessProfilePublicRepositoryProvider =
    Provider<BusinessProfilePublicRepository>(
      (ref) => BusinessProfilePublicRepositoryImpl(
        dio: ref.watch(dioClientProvider),
      ),
    );
