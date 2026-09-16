/// Part P-028A scope: the clean domain representation of a Business
/// account's own profile — no transport concerns (no raw JSON keys, no
/// DTO types) cross this boundary, per Clean Architecture Section 11,
/// mirroring the pattern `user_entity.dart` (Part P-020) established.
///
/// ### Field list — confirmed against the real backend, not assumed
///
/// The part spec's own "Scope" bullet for this file listed
/// `businessName, businessType, country, city, description, phoneNumber,
/// isVerified` and said nothing about `category`. The spec's own
/// "BEFORE CODING" step, though, explicitly required checking whether
/// P-026 added a `category` FK to `BusinessProfile` before deciding
/// whether a category needs to be represented at all — "check P-026's
/// progress notes first, don't assume."
///
/// Doing that (reading `PROJECT_PROGRESS.md`'s own P-025/P-026 sections
/// instead of guessing) found:
/// * P-025 flagged an explicit open gap: `BusinessProfile` had no
///   `category` FK yet.
/// * P-026 closed that gap: `businesses/migrations/0002_businessprofile_
///   category.py` adds a nullable (`on_delete=SET_NULL`) `category` FK,
///   and `BusinessProfileSerializer`'s write fields include `category`
///   alongside `business_name`/`business_type`/`country`/`city`/
///   `description`.
///
/// So `category` **is** part of the real request/response shape this
/// entity mirrors, and is included here as `categoryId` (nullable — a
/// Business can complete onboarding without picking one, confirmed by
/// P-026's own "Gap check for later phases" note). This is a deliberate,
/// flagged addition beyond the part spec's literal field list, not a
/// silent one — see this feature's `PROJECT_PROGRESS.md` entry for the
/// same note.
///
/// The actual category-tree-based *picker widget* (`GET
/// /api/v1/categories/tree/`, Part P-025) is presentation-layer work and
/// stays out of this part's scope (data/domain/provider only, per the
/// execution prompt) — it belongs to Part P-028B's onboarding/edit
/// screens, per this part's own "Out of Scope" note. This entity/DTO
/// layer only needs to be able to carry a category id through.
///
/// `followerCount` is similarly included even though the spec's field
/// list omitted it: P-026's own progress notes document the real
/// response shape as adding `id`, `is_verified`, *and* `follower_count`
/// (a `# TODO(Phase 9)` placeholder, always `0` today) to the read
/// serializer. Since the "BEFORE CODING" step calls for matching the
/// **exact** response shape rather than a hand-picked subset of it, and
/// dropping a real response field silently would just mean re-adding it
/// later, it's included here now, clearly documented as always `0` for
/// the time being.
library;

/// Mirrors `businesses.models.BusinessProfile.business_type`'s choices
/// on the backend exactly (`"trader"` / `"factory"`) — confirmed from
/// `PROJECT_PROGRESS.md`'s P-024 entry (`business_type (choices
/// trader/factory)`), not guessed.
enum BusinessType {
  trader,
  factory;

  /// Parses the backend's raw `business_type` string. Throws
  /// [FormatException] on anything unrecognized rather than silently
  /// defaulting — mirrors `AccountType.fromWire`'s exact convention
  /// (Part P-020): an unknown value here means the backend's contract
  /// changed underneath this app and callers should know immediately.
  static BusinessType fromWire(String value) {
    switch (value) {
      case 'trader':
        return BusinessType.trader;
      case 'factory':
        return BusinessType.factory;
      default:
        throw FormatException('Unknown business_type from backend: $value');
    }
  }

  /// Inverse of [fromWire] — used when this app needs to send the value
  /// back to the backend (create/update request bodies).
  String toWire() {
    switch (this) {
      case BusinessType.trader:
        return 'trader';
      case BusinessType.factory:
        return 'factory';
    }
  }
}

/// A Business account's own profile, as far as the domain/presentation
/// layers need to know. Constructed only by
/// `BusinessProfileRepositoryImpl`'s mapping step (data layer) — see
/// this file's module docstring for the two fields (`categoryId`,
/// `followerCount`) present here beyond the part spec's original list,
/// and why.
class BusinessProfile {
  const BusinessProfile({
    required this.id,
    required this.businessName,
    required this.businessType,
    required this.country,
    required this.city,
    this.description = '',
    this.phoneNumber,
    this.categoryId,
    required this.isVerified,
    this.followerCount = 0,
  });

  final int id;
  final String businessName;
  final BusinessType businessType;
  final String country;
  final String city;
  final String description;

  /// E.164-formatted (e.g. `"+201001234567"`) once set — the backend
  /// (Part P-027) always normalizes to E.164 on save and rejects
  /// anything that doesn't carry its own explicit country code. `null`
  /// means not set (the backend's own field default is `""`, mapped to
  /// `null` here at the DTO boundary — see
  /// `BusinessProfileResponseDto.toEntity()`).
  final String? phoneNumber;

  /// Nullable — `BusinessProfile.category` is an optional FK on the
  /// backend (`on_delete=SET_NULL`, Part P-026). See this file's module
  /// docstring for why this field exists in the entity even though the
  /// part spec's own field list didn't mention it.
  final int? categoryId;

  /// Read-through only, from `User.is_business_verified` on the backend
  /// (Part P-016) — never settable from this app. Toggled exclusively
  /// by an Admin action server-side.
  final bool isVerified;

  /// Backend-computed placeholder — always `0` until Phase 9
  /// (`# TODO(Phase 9)` in P-026's own serializer). Present here because
  /// it's part of the real response shape (see this file's module
  /// docstring), not because any UI depends on a real value yet.
  final int followerCount;

  BusinessProfile copyWith({
    int? id,
    String? businessName,
    BusinessType? businessType,
    String? country,
    String? city,
    String? description,
    String? phoneNumber,
    int? categoryId,
    bool? isVerified,
    int? followerCount,
  }) {
    return BusinessProfile(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      country: country ?? this.country,
      city: city ?? this.city,
      description: description ?? this.description,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      categoryId: categoryId ?? this.categoryId,
      isVerified: isVerified ?? this.isVerified,
      followerCount: followerCount ?? this.followerCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusinessProfile &&
          other.id == id &&
          other.businessName == businessName &&
          other.businessType == businessType &&
          other.country == country &&
          other.city == city &&
          other.description == description &&
          other.phoneNumber == phoneNumber &&
          other.categoryId == categoryId &&
          other.isVerified == isVerified &&
          other.followerCount == followerCount);

  @override
  int get hashCode => Object.hash(
    id,
    businessName,
    businessType,
    country,
    city,
    description,
    phoneNumber,
    categoryId,
    isVerified,
    followerCount,
  );

  @override
  String toString() =>
      'BusinessProfile(id: $id, businessName: $businessName, '
      'businessType: $businessType, country: $country, city: $city, '
      'categoryId: $categoryId, isVerified: $isVerified)';
}
