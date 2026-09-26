/// Part P-062 scope: abstract contract for the Discover screen's two
/// data needs -- the stories bar and the Recommended/general-content
/// section. Same interface-segregation pattern as `FeedRepository`
/// (`feed/domain/feed_repository.dart`, Part P-061): the presentation
/// layer depends on this, never on `DiscoverRepositoryImpl` directly.
library;

import '../../feed/domain/feed_page_entity.dart';
import 'active_story_group_entity.dart';

abstract class DiscoverRepository {
  /// Every currently-visible (published, not-yet-expired) Story across
  /// ALL businesses, grouped by business -- one [ActiveStoryGroup] per
  /// business that has at least one active Story. Backed by
  /// `GET /api/v1/stories/public/` (`StoryPublicListView`, Part P-048)
  /// called with NO `business_id` filter, which is the same endpoint
  /// `StoryPublicRepository.fetchBusinessStories` already calls with
  /// one -- the query-driven visibility guarantee documented on that
  /// view (a Story disappears the instant it expires, independent of
  /// the sweep job) holds here too, since it's the exact same queryset.
  /// The grouping itself happens client-side in the repository
  /// implementation: the backend endpoint returns a flat list, there is
  /// no grouped-by-business endpoint on the server.
  Future<List<ActiveStoryGroup>> fetchActiveStoryGroups();

  /// `cursor == null` -> first page. `cursor` non-null -> whatever
  /// `FeedPage.nextCursor` returned from the previous call, passed back
  /// completely unmodified -- identical contract to
  /// `FeedRepository.fetchHomeFeed`, just against
  /// `GET /api/v1/feed/discover/` (Part P-062's own backend endpoint,
  /// STEP 1) instead of `/feed/home/`. Reuses the SAME [FeedItem] /
  /// [FeedPage] types Home Feed uses -- both endpoints return the exact
  /// same `{content_type, ...}` shape (`feed.serializers.FeedItemSerializer`
  /// on both), so no new entity was written for this part.
  Future<FeedPage> fetchDiscoverFeed({String? cursor});
}