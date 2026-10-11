/// A business the current user follows, as offered by the "New chat"
/// picker. Mirrors `FollowedBusinessSerializer` (`chat/serializers.py`):
/// `{business_id, business_name, business_type, city, country}`.
///
/// [businessId] is the `BusinessProfile` id — exactly what
/// `ConversationRepository.startConversationWithBusiness` expects, so the
/// app never needs the business owner's internal user id.
class FollowedBusiness {
  const FollowedBusiness({
    required this.businessId,
    required this.businessName,
    required this.businessType,
    required this.city,
    required this.country,
  });

  final int businessId;
  final String businessName;

  /// Raw backend value (`"trader"` / `"factory"`); localized by the UI.
  final String businessType;
  final String city;
  final String country;

  factory FollowedBusiness.fromJson(Map<String, dynamic> json) {
    return FollowedBusiness(
      businessId: json['business_id'] as int,
      businessName: json['business_name'] as String,
      businessType: (json['business_type'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      country: (json['country'] as String?) ?? '',
    );
  }
}
