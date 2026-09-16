/// Part P-028A scope. Field names confirmed against
/// `BusinessProfileSerializer`'s write fields (P-026: `business_name`,
/// `business_type`, `country`, `city`, `description`, `category`; P-027:
/// `phone_number`) — not assumed. Used for the onboarding "create my
/// profile for the first time" call; Part P-028B's onboarding screen is
/// the intended caller, via `BusinessProfileRepository.createProfile()`.
///
/// Pure data-shape/JSON concern, same convention as `RegisterRequestDto`
/// (Part P-020): [businessType] is the already-wire-converted raw string
/// (`"trader"`/`"factory"`), converted from the domain `BusinessType` enum
/// by the caller (`business_profile_repository_impl.dart`) — this DTO has
/// no domain-layer imports.
class BusinessProfileCreateRequestDto {
  const BusinessProfileCreateRequestDto({
    required this.businessName,
    required this.businessType,
    required this.country,
    required this.city,
    this.description,
    this.categoryId,
    this.phoneNumber,
  });

  final String businessName;
  final String businessType;
  final String country;
  final String city;

  /// Optional on the backend. Omitted from [toJson] entirely when
  /// `null` — a brand-new profile has nothing to explicitly clear, so
  /// there's no "clear vs. leave alone" ambiguity here the way there is
  /// on the PATCH/update DTO.
  final String? description;
  final int? categoryId;
  final String? phoneNumber;

  Map<String, dynamic> toJson() => {
    'business_name': businessName,
    'business_type': businessType,
    'country': country,
    'city': city,
    if (description != null) 'description': description,
    if (categoryId != null) 'category': categoryId,
    if (phoneNumber != null) 'phone_number': phoneNumber,
  };
}
