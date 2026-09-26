/// Part P-065 STEP 1 scope: [SearchResult] — the unified type
/// `SearchNotifier` (STEP 3) exposes, mixing [BusinessProfile] and
/// [Product] results from `GET /api/v1/search/` (Part P-064) in the
/// SAME order the backend returns them in.
///
/// `sealed`, two variants, wrapping the full, already-existing entity
/// — the exact same design choice already used for [ContentItem]
/// (`content/domain/content_item_entity.dart`, Part P-044) and
/// [FeedItem] (`feed/domain/feed_item_entity.dart`, Part P-061), for
/// the same reason: a third, flattened entity duplicating fields would
/// only drift from the real one over time.
library;

import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';

sealed class SearchResult {
  const SearchResult();

  /// `"business"` / `"product"` — the backend's own `result_type`
  /// discriminator (`search.serializers.SearchResultSerializer`,
  /// P-064), not a locally invented enum. Kept a plain [String], same
  /// reasoning as `FeedItem.contentType`.
  String get resultType;

  int get id;
}

class BusinessSearchResult extends SearchResult {
  const BusinessSearchResult(this.business);

  final BusinessProfile business;

  @override
  String get resultType => 'business';
  @override
  int get id => business.id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusinessSearchResult && other.business == business);

  @override
  int get hashCode => business.hashCode;

  @override
  String toString() => 'BusinessSearchResult($business)';
}

class ProductSearchResult extends SearchResult {
  const ProductSearchResult(this.product);

  final Product product;

  @override
  String get resultType => 'product';
  @override
  int get id => product.id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductSearchResult && other.product == product);

  @override
  int get hashCode => product.hashCode;

  @override
  String toString() => 'ProductSearchResult($product)';
}