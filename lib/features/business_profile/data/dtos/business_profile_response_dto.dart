/// Part P-028A scope. Field names confirmed against `PROJECT_PROGRESS.md`'s
/// own P-026/P-027 entries (`businesses/serializers.py::
/// BusinessProfileSerializer`) on the real backend, not assumed:
///
/// * P-026 — read fields: `id`, `business_name`, `business_type`,
///   `country`, `city`, `description`, `category`, plus `is_verified`
///   (read-through to `User.is_business_verified`) and `follower_count`
///   (placeholder `0`, `# TODO(Phase 9)`).
/// * P-027 — adds `phone_number` (optional, default `""` server-side,
///   always E.164 on save once non-empty).
///
/// A pure data-shape/JSON concern, same convention as `RegisterResponseDto`
/// (Part P-020): raw wire values only (`business_type` stays a `String`
/// here, not the domain `BusinessType` enum) — no domain-layer imports,
/// so this file has zero knowledge of `BusinessProfile`/`BusinessType`.
/// Mapping to the domain entity happens in
/// `business_profile_repository_impl.dart`, mirroring exactly how
/// `AuthRepositoryImpl.register()` maps `RegisterResponseDto` to `User`.
class BusinessProfileResponseDto {
  const BusinessProfileResponseDto({
    required this.id,
    required this.businessName,
    required this.businessType,
    required this.country,
    required this.city,
    required this.description,
    required this.phoneNumber,
    required this.categoryId,
    required this.isVerified,
    required this.followerCount,
  });

  factory BusinessProfileResponseDto.fromJson(Map<String, dynamic> json) {
    return BusinessProfileResponseDto(
      id: json['id'] as int,
      businessName: json['business_name'] as String,
      // Raw wire value — mapped to the domain `BusinessType` enum by
      // business_profile_repository_impl.dart, never exposed past the
      // repository as a bare string (same convention as
      // RegisterResponseDto.accountType).
      businessType: json['business_type'] as String,
      country: json['country'] as String,
      city: json['city'] as String,
      // `description` is a `TextField(blank=True)` on the backend
      // (P-024) — always a string, never `null`, but defensive against
      // a missing key all the same.
      description: (json['description'] as String?) ?? '',
      // `phone_number` is `CharField(blank=True, default="")` on the
      // backend (P-027) — an unset phone comes back as `""`, not
      // `null`. Kept as the raw `""` here; the `""` → `null` "not set"
      // normalization happens at the entity-mapping step in the repo
      // impl, not in this pure-JSON DTO.
      phoneNumber: (json['phone_number'] as String?) ?? '',
      // `category` is a nullable FK (`on_delete=SET_NULL`, P-026) — DRF's
      // default representation for a plain FK write field is its
      // primary key, so this is read as a bare int id, not a nested
      // object. Flagged here as an assumption to double-check against
      // real captured JSON before Part P-028B builds the category
      // picker on top of it (see this feature's PROJECT_PROGRESS.md
      // entry).
      categoryId: json['category'] as int?,
      isVerified: json['is_verified'] as bool,
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
    );
  }

  final int id;
  final String businessName;
  final String businessType;
  final String country;
  final String city;
  final String description;
  final String phoneNumber;
  final int? categoryId;
  final bool isVerified;
  final int followerCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'business_name': businessName,
    'business_type': businessType,
    'country': country,
    'city': city,
    'description': description,
    'phone_number': phoneNumber,
    'category': categoryId,
    'is_verified': isVerified,
    'follower_count': followerCount,
  };
}
