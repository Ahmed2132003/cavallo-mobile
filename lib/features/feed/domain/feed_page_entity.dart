/// Part P-061 scope: one page of `GET /api/v1/feed/home/` — the parsed
/// `{items, next_cursor}` shape P-059/P-060 document. Deliberately NOT
/// `PaginatedResponse<T>` (`core/network/paginated_response.dart`):
/// that type is for the standard DRF `{results, next, previous}` shape
/// (a full URL in `next`). The Home Feed's cursor is a single opaque
/// string value, not a URL, and the backend's own contract is
/// documented as "never parsed or built client-side" — reusing a type
/// whose field is literally named for a URL would invite exactly that
/// misuse later.
library;

import 'feed_item_entity.dart';

class FeedPage {
  const FeedPage({required this.items, required this.nextCursor});

  final List<FeedItem> items;

  /// Opaque. Passed back to [FeedRepository.fetchHomeFeed] verbatim as
  /// `cursor` on the next call — never parsed, decoded, or constructed
  /// here or anywhere else in this app. `null` means both tiers
  /// (following + backfill) are exhausted — no more pages.
  final String? nextCursor;
}