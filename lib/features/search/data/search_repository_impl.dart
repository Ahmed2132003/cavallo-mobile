/// Part P-065 STEP 2 scope: [SearchRepositoryImpl] — the concrete data
/// source for `GET /api/v1/search/` (Part P-064, confirmed against the
/// real `search/views.py`/`search/serializers.py` on `cavallo-app`
/// `main`, not the part spec's literal guess).
///
/// Follows `FeedRepositoryImpl`'s (Part P-061, `feed/data/
/// feed_repository.dart`) exact conventions: depends only on
/// `dioClientProvider`, never constructs its own [Dio]; a plain
/// `Provider` exposes it for override in tests/screens.
///
/// ### Parsing — zero duplicated DTO logic (mostly)
///
/// Each raw item is a flat merge of `{"result_type": "business"|
/// "product", ...}` with either `BusinessProfileSerializer`'s or
/// `ProductSerializer`'s own fields at the SAME top level — confirmed
/// against the real `search/serializers.py::SearchResultSerializer.
/// to_representation()`, which does `data = dict(serializer(...).data);
/// data["result_type"] = ...` (a flat dict update, not a nested
/// `{"business": {...}}`/`{"product": {...}}` envelope). So each item
/// is parsed through the EXISTING `BusinessProfileResponseDto`/
/// `ProductResponseDto` (Parts P-028A/P-033) exactly as-is — the extra
/// `result_type` key is simply never read by either DTO's `fromJson`,
/// the same "extra keys naturally dropped at the boundary" pattern
/// `FeedRepositoryImpl` already relies on for `content_type`. No new
/// per-item DTO class is written for this part.
///
/// ### `BusinessProfileResponseDto` → `BusinessProfile`: a third,
/// deliberately duplicated `_toEntity`, not a shared one
///
/// Unlike `ProductResponseDto` (which already carries its own
/// `toEntity()`), `BusinessProfileResponseDto` has none — both existing
/// consumers (`BusinessProfileRepositoryImpl`, Part P-028A, and
/// `BusinessProfilePublicRepositoryImpl`, Part P-029) map it via their
/// own private `_toEntity`. `BusinessProfilePublicRepositoryImpl`'s own
/// docstring flags this explicitly: "if a third consumer of this DTO
/// ever appears, move it onto the DTO as a `toEntity()` method instead
/// of duplicating a third time." This part IS that third consumer, but
/// the fix it names would touch two already-completed, already-tested
/// parts (P-028A/P-029) that P-065's own scope never asked to change —
/// architecture Section 9's own rule (never touch a previous part's
/// files unless the current part explicitly requires it). So this file
/// duplicates the exact same mapping a third time here, field-for-field
/// identical to `BusinessProfilePublicRepositoryImpl._toEntity`, rather
/// than editing those two files. Flagged, not silent — worth raising as
/// a genuine, quick follow-up refactor (move it onto the DTO once, all
/// three call sites drop their private copy), but out of THIS part's
/// scope to do unasked.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../business_profile/data/dtos/business_profile_response_dto.dart';
import '../../business_profile/domain/business_profile_entity.dart';
import '../../products/data/dtos/product_response_dto.dart';
import '../domain/search_filters.dart';
import '../domain/search_page_entity.dart';
import '../domain/search_repository.dart';
import '../domain/search_result_entity.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _searchPath = '/api/v1/search/';

  /// Builds the exact query-parameter map `search/views.py::SearchView.
  /// get()` parses: `q`, `category`, `country`, `city`, `business_type`,
  /// `min_rating`, `featured_only`, `min_price`, `max_price`, `cursor`.
  /// Every key is OMITTED entirely (never sent as an empty string or a
  /// literal `"null"`) when its value is absent — mirrors the backend's
  /// own `params.get(...) or None` handling, and keeps a first-page,
  /// no-filter call's query string genuinely empty rather than a string
  /// of `key=`-with-nothing pairs.
  Map<String, dynamic> _buildQueryParameters({
    String? q,
    required SearchFilters filters,
    String? cursor,
  }) {
    final query = <String, dynamic>{};

    if (q != null && q.isNotEmpty) query['q'] = q;
    if (filters.categoryId != null) {
      query['category'] = filters.categoryId.toString();
    }
    if (filters.country != null) query['country'] = filters.country;
    if (filters.city != null) query['city'] = filters.city;
    if (filters.businessType != null) {
      query['business_type'] = filters.businessType;
    }
    if (filters.minRating != null) query['min_rating'] = filters.minRating;
    // `featured_only` is only ever sent when true — the backend already
    // defaults an absent param to `false` (`views.py`'s own
    // `featured_only_raw ... else False`), so sending `featured_only=
    // false` explicitly would be redundant, never incorrect.
    if (filters.featuredOnly) query['featured_only'] = 'true';
    if (filters.minPrice != null) query['min_price'] = filters.minPrice;
    if (filters.maxPrice != null) query['max_price'] = filters.maxPrice;
    if (cursor != null) query['cursor'] = cursor;

    return query;
  }

  /// Identical mapping step to `BusinessProfilePublicRepositoryImpl.
  /// _toEntity` (same DTO, same entity, same `phone_number: ""` →
  /// `null` normalization). See this file's module docstring for why
  /// it's duplicated here rather than added to the DTO itself.
  BusinessProfile _businessToEntity(BusinessProfileResponseDto dto) {
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

  @override
  Future<SearchPage> search({
    String? q,
    SearchFilters filters = const SearchFilters(),
    String? cursor,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _searchPath,
      queryParameters: _buildQueryParameters(
        q: q,
        filters: filters,
        cursor: cursor,
      ),
    );
    final data = response.data!;
    final rawItems = data['items'] as List<dynamic>;

    final items = rawItems.map((raw) {
      final json = raw as Map<String, dynamic>;
      final resultType = json['result_type'] as String;
      return switch (resultType) {
        'business' => BusinessSearchResult(
          _businessToEntity(BusinessProfileResponseDto.fromJson(json)),
        ),
        'product' => ProductSearchResult(
          ProductResponseDto.fromJson(json).toEntity(),
        ),
        _ => throw FormatException(
          'Unknown search result_type: "$resultType"',
        ),
      };
    }).toList();

    return SearchPage(
      items: items,
      nextCursor: data['next_cursor'] as String?,
    );
  }
}

/// Exposes [SearchRepository] via Riverpod — a plain `Provider`, same
/// pattern as `feedRepositoryProvider` / `productPublicRepositoryProvider`.
final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepositoryImpl(dio: ref.watch(dioClientProvider)),
);