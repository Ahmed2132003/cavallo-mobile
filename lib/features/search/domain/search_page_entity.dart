/// Part P-065 STEP 1 scope: one page of `GET /api/v1/search/` — the
/// parsed `{items, next_cursor}` shape (confirmed against the real
/// `search/views.py` on `cavallo-app` main). Deliberately NOT
/// `PaginatedResponse<T>` (`core/network/paginated_response.dart`),
/// for the exact same reason `FeedPage`
/// (`feed/domain/feed_page_entity.dart`, Part P-061) isn't: that type
/// is for the standard DRF `{results, next, previous}` shape (a full
/// URL in `next`). Search's own cursor (`search/cursor.py`, P-064) is
/// a single opaque string value the backend's own docstring calls
/// "never parsed or built client-side" — reusing a type whose field is
/// literally named for a URL would invite exactly that misuse later.
library;

import 'search_result_entity.dart';

class SearchPage {
  const SearchPage({required this.items, required this.nextCursor});

  final List<SearchResult> items;

  /// Opaque. Passed back to [SearchRepository.search] verbatim as
  /// `cursor` on the next call — never parsed, decoded, or constructed
  /// here or anywhere else in this app. `null` means no more pages.
  ///
  /// ⚠️ A cursor is only valid for the exact "query text present vs.
  /// absent" mode it was issued in (`search/cursor.py`'s own
  /// "relevance-or-recency" note — mixing a relevance-mode cursor into
  /// a now-textless request is rejected server-side as
  /// `InvalidCursorError`). `SearchNotifier` (STEP 3) is responsible
  /// for discarding any held cursor whenever the search text's
  /// presence/absence changes, never reusing it across that switch.
  final String? nextCursor;
}