/// Part P-065 STEP 1 scope: [SearchFilters] — the already-validated set
/// of filter values `SearchRepository.search()` (STEP 2) sends to
/// `GET /api/v1/search/` (Part P-064's endpoint).
///
/// Mirrors the backend's own `search.services.SearchFilters` dataclass
/// field names/shapes exactly (confirmed against the real
/// `search/views.py`/`search/services.py` on `cavallo-app` `main`, not
/// assumed from the part spec's literal field list):
/// `category_id`, `country`, `city`, `business_type`, `min_rating`,
/// `featured_only`, `min_price`, `max_price`. All eight are optional
/// and independently combinable — this part's own Detailed
/// Implementation note ("every filter is optional and combinable").
///
/// `businessType` is kept as the raw wire string (`"trader"`/
/// `"factory"`), NOT the domain `BusinessType` enum from
/// `business_profile_entity.dart`: the backend's own `business_type`
/// query param is compared with plain string equality against
/// `BusinessProfile.business_type` (`search/services.py`,
/// `build_business_queryset()`) — this class only ever WRITES the
/// param, never reads one back. `SearchFilterPanel` (STEP 4) is the
/// layer that turns a user-facing Trader/Factory/Either choice into
/// this raw string.
///
/// `minRating`/`minPrice`/`maxPrice` are kept as plain [String] (not
/// [double]/`Decimal`), same reasoning `Product.price` already uses
/// (see `product_entity.dart`'s module docstring): a decimal
/// round-trip should never touch a binary float, and the backend
/// itself parses these with `Decimal(raw)`
/// (`search/views.py::_parse_decimal`).
library;

class SearchFilters {
  const SearchFilters({
    this.categoryId,
    this.country,
    this.city,
    this.businessType,
    this.minRating,
    this.featuredOnly = false,
    this.minPrice,
    this.maxPrice,
  });

  final int? categoryId;
  final String? country;
  final String? city;

  /// Raw wire value (`"trader"` | `"factory"`) or `null` for "either".
  /// See this file's module docstring for why this isn't `BusinessType`.
  final String? businessType;

  /// e.g. `"4"` for "4 stars & up" — the raw decimal string sent as
  /// the backend's `min_rating` param. See this file's module
  /// docstring for why this is a [String].
  final String? minRating;

  final bool featuredOnly;
  final String? minPrice;
  final String? maxPrice;

  /// True when every field is at its default ("no filter applied") —
  /// `SearchFilterPanel` (STEP 4) uses this to show/hide a "Clear
  /// filters" affordance without duplicating the check there.
  bool get isEmpty =>
      categoryId == null &&
      country == null &&
      city == null &&
      businessType == null &&
      minRating == null &&
      !featuredOnly &&
      minPrice == null &&
      maxPrice == null;

  /// Each `clearX` flag exists because `copyWith`'s usual
  /// `x ?? this.x` convention cannot otherwise distinguish "leave this
  /// field alone" from "set it back to null" — the same pattern
  /// `FeedState.copyWith`'s `clearNextCursor` already uses in this
  /// project (`home_feed_provider.dart`, Part P-061).
  SearchFilters copyWith({
    int? categoryId,
    String? country,
    String? city,
    String? businessType,
    String? minRating,
    bool? featuredOnly,
    String? minPrice,
    String? maxPrice,
    bool clearCategoryId = false,
    bool clearCountry = false,
    bool clearCity = false,
    bool clearBusinessType = false,
    bool clearMinRating = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return SearchFilters(
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      country: clearCountry ? null : (country ?? this.country),
      city: clearCity ? null : (city ?? this.city),
      businessType: clearBusinessType
          ? null
          : (businessType ?? this.businessType),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      featuredOnly: featuredOnly ?? this.featuredOnly,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchFilters &&
          other.categoryId == categoryId &&
          other.country == country &&
          other.city == city &&
          other.businessType == businessType &&
          other.minRating == minRating &&
          other.featuredOnly == featuredOnly &&
          other.minPrice == minPrice &&
          other.maxPrice == maxPrice);

  @override
  int get hashCode => Object.hash(
    categoryId,
    country,
    city,
    businessType,
    minRating,
    featuredOnly,
    minPrice,
    maxPrice,
  );

  @override
  String toString() =>
      'SearchFilters(categoryId: $categoryId, country: $country, '
      'city: $city, businessType: $businessType, minRating: $minRating, '
      'featuredOnly: $featuredOnly, minPrice: $minPrice, '
      'maxPrice: $maxPrice)';
}