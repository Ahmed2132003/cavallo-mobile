import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/business_profile_entity.dart';
import '../domain/business_profile_repository.dart';
import 'dtos/business_profile_create_request_dto.dart';
import 'dtos/business_profile_response_dto.dart';

/// Part P-028A scope: `lib/features/business_profile/data/` — the
/// `BusinessProfileRepository` implementation. Mirrors
/// `AuthRepositoryImpl`'s (Part P-020) exact conventions: depends only on
/// `dioClientProvider` (never constructs its own `Dio`), maps
/// DTO → domain entity itself (DTOs stay domain-unaware), and — with one
/// deliberate, documented exception below — does NOT catch/re-wrap
/// [DioException]. A failed call surfaces to the caller as-is, with
/// `.error` already a typed `ApiFailure` (Part P-004's `ErrorInterceptor`
/// guarantees this for anything that passed through `dioClientProvider`'s
/// chain) — callers should catch [DioException] and read `.error`,
/// exactly as `AuthRepositoryImpl`'s callers do.
///
/// ### The one deliberate exception: 404 on `fetchMyProfile()`
///
/// `ErrorInterceptor._mapStatusCode` (Part P-004, confirmed by reading
/// the real source rather than assumed) only special-cases 400/401/403/
/// 5xx — a 404 falls through to its `UnknownFailure` catch-all, exactly
/// like any other unrecognized status code. But per this part's own
/// spec, "a null result (backend 404) is a valid, meaningful state (not
/// an error) representing 'no profile yet, needs onboarding.'" That
/// meaning is specific to *this* endpoint (a fresh Business account's
/// `/me/` genuinely 404s until onboarding completes — P-026's own
/// progress notes) — `core/network` stays feature-agnostic per the
/// architecture rule, so this 404-specific interpretation belongs here,
/// in this feature's repository, not in the shared `ErrorInterceptor`.
/// [fetchMyProfile] is therefore the only method here that catches
/// [DioException] at all, and only to special-case exactly this one
/// status code — every other failure (network, 5xx, a genuine
/// `UnknownFailure` for some other reason) still rethrows unmodified.
class BusinessProfileRepositoryImpl implements BusinessProfileRepository {
  BusinessProfileRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _mePath = '/api/v1/businesses/me/';

  @override
  Future<BusinessProfile?> fetchMyProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_mePath);
      return _toEntity(BusinessProfileResponseDto.fromJson(response.data!));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // No profile yet — a valid, expected state per this part's own
        // spec, never surfaced as an error. See this method's module
        // docstring for why this is the one place this repository
        // catches DioException at all.
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<BusinessProfile> createProfile({
    required String businessName,
    required BusinessType businessType,
    required String country,
    required String city,
    String? description,
    int? categoryId,
    String? phoneNumber,
  }) async {
    final requestDto = BusinessProfileCreateRequestDto(
      businessName: businessName,
      businessType: businessType.toWire(),
      country: country,
      city: city,
      description: description,
      categoryId: categoryId,
      phoneNumber: phoneNumber,
    );

    final response = await _dio.post<Map<String, dynamic>>(
      _mePath,
      data: requestDto.toJson(),
    );

    return _toEntity(BusinessProfileResponseDto.fromJson(response.data!));
  }

  @override
  Future<BusinessProfile> updateProfile({
    String? businessName,
    BusinessType? businessType,
    String? country,
    String? city,
    Patchable<String> description = const Patchable.unset(),
    Patchable<int> categoryId = const Patchable.unset(),
    Patchable<String> phoneNumber = const Patchable.unset(),
  }) async {
    // Built directly as a Map, unlike `createProfile`'s dedicated
    // request DTO: this body's shape is entirely conditional on which
    // named parameters were actually passed (see `Patchable`'s
    // docstring in business_profile_repository.dart for why a plain
    // nullable parameter can't express "leave alone" vs. "clear"). A
    // dedicated DTO class here would just wrap the same conditional-map
    // logic without adding any real type safety over doing it inline —
    // mirroring how `AuthRepositoryImpl.refresh()` (Part P-020) builds
    // `data: {'refresh': refreshToken}` directly for a one-off body
    // rather than introducing a single-field DTO class for it.
    final body = <String, dynamic>{
      if (businessName != null) 'business_name': businessName,
      if (businessType != null) 'business_type': businessType.toWire(),
      if (country != null) 'country': country,
      if (city != null) 'city': city,
      if (description.isSet) 'description': description.value,
      if (categoryId.isSet) 'category': categoryId.value,
      if (phoneNumber.isSet) 'phone_number': phoneNumber.value,
    };

    final response = await _dio.patch<Map<String, dynamic>>(
      _mePath,
      data: body,
    );

    return _toEntity(BusinessProfileResponseDto.fromJson(response.data!));
  }

  /// Maps the pure-JSON [BusinessProfileResponseDto] to the domain
  /// [BusinessProfile] entity — the one place `business_type` (raw wire
  /// string) becomes [BusinessType] (domain enum), and the one place the
  /// backend's `phone_number: ""` "not set" convention becomes `null`,
  /// mirroring `AuthRepositoryImpl.register()`'s equivalent mapping step
  /// for `RegisterResponseDto` → `User`.
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

/// Exposes [BusinessProfileRepository] to the rest of the app via
/// Riverpod, per this project's established pattern
/// (`dioClientProvider`, `authRepositoryProvider`) — a `Provider`, not a
/// singleton/global, so it's overridable in tests and in Part P-028B's
/// widget tree.
final businessProfileRepositoryProvider = Provider<BusinessProfileRepository>(
  (ref) => BusinessProfileRepositoryImpl(dio: ref.watch(dioClientProvider)),
);
