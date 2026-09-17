import 'category_entity.dart';

/// New feature scope (Part P-033, STEP 6): the domain-facing contract
/// for reading the category tree. Read-only forever — the backend's
/// `categories/urls.py` has exactly one `GET` route, no write endpoint
/// exists at all (confirmed in `categories/views.py`'s own docstring:
/// "No write endpoint exists here on purpose").
abstract class CategoryRepository {
  /// Fetches the full active category tree.
  ///
  /// [forceRefresh] bypasses this repository's own local cache (see
  /// `CategoryRepositoryImpl`'s docstring) and always hits the network
  /// — used by a future step's picker widget for an explicit "Retry"
  /// action, mirroring how `businessProfilePublicProvider`
  /// (Part P-029) exposes retry as re-invoking the fetch rather than a
  /// dedicated method.
  Future<List<CategoryNode>> fetchCategoryTree({bool forceRefresh = false});
}