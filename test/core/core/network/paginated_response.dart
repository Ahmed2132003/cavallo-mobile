/// Generic wrapper for any backend list endpoint using
/// `core.pagination.StandardCursorPagination` (Architecture Section 9,
/// point 7). First real consumer on the Flutter side is Part P-033's
/// "own products" and "public products" list endpoints (Part P-032),
/// but this type is deliberately feature-agnostic (`core/network`, not
/// `features/products/`) since every future paginated list endpoint
/// (Posts P-041, Reels P-042, ...) returns the exact same
/// `{results, next, previous}` shape and should parse it through this
/// one class, not a second hand-rolled one per feature.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.results,
    required this.next,
    required this.previous,
  });

  final List<T> results;

  /// Opaque cursor URL for the next page, or `null` on the last page.
  /// Never parsed/rebuilt by this app — passed back to Dio verbatim as
  /// a full URL if a future "load more" caller needs it. Part P-033
  /// itself only consumes the first page (its own acceptance criteria
  /// don't require pagination UI), so this is carried through but not
  /// yet wired to any "load more" button.
  final String? next;
  final String? previous;

  static PaginatedResponse<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final rawResults = json['results'] as List<dynamic>;
    return PaginatedResponse<T>(
      results: rawResults
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(),
      next: json['next'] as String?,
      previous: json['previous'] as String?,
    );
  }
}