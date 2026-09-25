/// Part P-061 scope: abstract contract for the Home Feed data source —
/// same interface-segregation pattern as every other feature
/// (`ProductRepository`, `PostRepository`, ...): the presentation layer
/// depends on this, never on `FeedRepositoryImpl` directly.
library;

import 'feed_page_entity.dart';

abstract class FeedRepository {
  /// `cursor == null` → first page (following tier first, backfilled
  /// with featured/general content in the same page if the following
  /// tier doesn't fill it — see P-059's `get_home_feed()`). `cursor`
  /// non-null → whatever `FeedPage.nextCursor` returned from the
  /// previous call, passed back completely unmodified.
  Future<FeedPage> fetchHomeFeed({String? cursor});
}