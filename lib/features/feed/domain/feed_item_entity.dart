/// Part P-061 scope: the unified type the Home Feed provider
/// (`home_feed_provider.dart`, STEP 2) exposes — a single, type-tagged
/// list mixing published [PublicPost]s and [PublicReel]s from
/// `GET /api/v1/feed/home/` (Parts P-059/P-060).
///
/// Mirrors `ContentItem`'s (`content/domain/content_item_entity.dart`,
/// Part P-044) exact design choice: a `sealed` class with two variants,
/// each wrapping the FULL, already-existing [PublicPost]/[PublicReel]
/// entity — not a third, flattened entity duplicating their fields.
/// `HomeFeedScreen` (STEP 3) only needs `contentType`/`id`/`businessId`
/// to pick `PostCard` vs `ReelCard` and resolve the business name;
/// anything card-specific stays reachable off `.post`/`.reel` directly.
library;

import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';

sealed class FeedItem {
  const FeedItem();

  /// `"post"` / `"reel"` — the backend's own discriminator
  /// (`feed.serializers.FeedItemSerializer`, P-059), not a locally
  /// invented enum. Kept a plain [String] for the same "a new content
  /// type shouldn't need a signature change" reasoning as
  /// `ContentItem.type` and `QueueItem.contentType`.
  String get contentType;

  int get id;
  int get businessId;
}

class PostFeedItem extends FeedItem {
  const PostFeedItem(this.post);

  final PublicPost post;

  @override
  String get contentType => 'post';
  @override
  int get id => post.id;
  @override
  int get businessId => post.businessId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PostFeedItem && other.post == post);

  @override
  int get hashCode => post.hashCode;

  @override
  String toString() => 'PostFeedItem($post)';
}

class ReelFeedItem extends FeedItem {
  const ReelFeedItem(this.reel);

  final PublicReel reel;

  @override
  String get contentType => 'reel';
  @override
  int get id => reel.id;
  @override
  int get businessId => reel.businessId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ReelFeedItem && other.reel == reel);

  @override
  int get hashCode => reel.hashCode;

  @override
  String toString() => 'ReelFeedItem($reel)';
}