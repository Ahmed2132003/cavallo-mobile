import 'search_filters.dart';
import 'search_page_entity.dart';

/// Part P-065 STEP 1 scope: the domain-facing contract for
/// `GET /api/v1/search/` (Part P-064). Implemented by
/// `SearchRepositoryImpl` (STEP 2, `data/search_repository_impl.dart`).
abstract class SearchRepository {
  /// [q] is the free-text query (`null`/empty means "no text query" —
  /// recency mode on the backend, per `search/cursor.py`). [filters]
  /// supplies every other, independently-combinable filter. [cursor]
  /// resumes a previous page — `null` for the first page.
  Future<SearchPage> search({
    String? q,
    SearchFilters filters = const SearchFilters(),
    String? cursor,
  });
}