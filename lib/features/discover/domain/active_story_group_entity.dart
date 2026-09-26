/// Part P-062 scope: one business's currently-visible Stories, grouped
/// client-side (see `DiscoverRepository.fetchActiveStoryGroups`'s own
/// docstring for why the grouping happens here and not on the
/// backend). Deliberately thin: wraps the existing [PublicStory] list
/// (Part P-050) rather than duplicating any of its fields, same
/// "wrap, don't flatten" choice `PostFeedItem`/`ReelFeedItem`
/// (`feed/domain/feed_item_entity.dart`) already made for Home Feed.
///
/// No `businessName` field, for the same reason `PublicStory` itself
/// has none (see that entity's own docstring): the backend's Story
/// payload only ever carries a numeric business id. `StoriesBarWidget`
/// (a later step) resolves each group's display name the same way
/// `HomeFeedScreen`'s `_FeedListItem` already resolves one per feed
/// row -- through `businessProfilePublicProvider(businessId)` -- kept
/// out of this pure-data entity on purpose.
library;

import '../../stories/domain/public_story_entity.dart';

class ActiveStoryGroup {
  const ActiveStoryGroup({required this.businessId, required this.stories});

  final int businessId;

  /// Never empty -- `DiscoverRepositoryImpl` (STEP 2) only ever
  /// constructs a group for a business that has at least one active
  /// Story; a business with zero is simply absent from the list
  /// `fetchActiveStoryGroups()` returns, exactly like
  /// `StoryRingWidget` already renders nothing for that case.
  final List<PublicStory> stories;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveStoryGroup &&
          other.businessId == businessId &&
          _sameStoryIds(other.stories, stories));

  static bool _sameStoryIds(List<PublicStory> a, List<PublicStory> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(businessId, Object.hashAll(stories.map((s) => s.id)));

  @override
  String toString() =>
      'ActiveStoryGroup(businessId: $businessId, storyCount: ${stories.length})';
}