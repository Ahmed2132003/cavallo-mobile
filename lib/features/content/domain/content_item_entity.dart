/// Part P-044 scope: the unified type `ownContentProvider`
/// (`lib/features/content/presentation/own_content_provider.dart`,
/// STEP 4 of this part) exposes — a single, type-tagged list mixing
/// the signed-in Business account's own [Post]s and [Reel]s for
/// `ContentListScreen` (STEP 5).
///
/// Design choice (this part's own spec explicitly leaves this open —
/// documenting the choice per its own instruction): a `sealed` class
/// with two variants, [PostContentItem]/[ReelContentItem], each
/// wrapping the FULL, already-existing [Post]/[Reel] entity — not a
/// third, separate "flattened" entity duplicating their fields.
/// `ContentListScreen` only needs a summary row per item (a `switch`
/// on the sealed type reads naturally there), while anything needing a
/// Reel-specific field ([Reel.processingStatus],
/// [Reel.durationSeconds]) can still reach it directly off
/// [ReelContentItem.reel] without an unsafe cast. Chosen over a single
/// flattened class (which would need several always-nullable
/// "Reel-only" fields on every Post row) and over a bare enum-tag class
/// (which would lose type safety on the `switch`) — sealed classes are
/// available and idiomatic on this project's Dart 3.7 floor
/// (`pubspec.yaml`).
library;

import 'moderation_status.dart';
import 'post_entity.dart';
import 'reel_entity.dart';

sealed class ContentItem {
  const ContentItem();

  /// The content-type discriminator — a plain [String] (`"post"` /
  /// `"reel"`), NOT an enum, mirroring `QueueItem.contentType`'s exact
  /// same "stay content-type-agnostic, a new type shouldn't need a
  /// signature change" reasoning (Part P-040) — Story (Phase 8) will
  /// be a third variant here later.
  String get type;

  int get id;
  String get caption;
  ModerationStatus get moderationStatus;

  /// Non-null only when [moderationStatus] is
  /// [ModerationStatus.rejected].
  String? get rejectionReason;

  /// The image (Post) or generated thumbnail (Reel, once
  /// [ReelProcessingStatus.ready]) to show in a list row. `null` for a
  /// Reel still processing (no thumbnail exists yet) or a Post/Reel
  /// with no image/thumbnail at all.
  String? get thumbnailUrl;

  DateTime? get createdAt;
}

class PostContentItem extends ContentItem {
  const PostContentItem(this.post);

  final Post post;

  @override
  String get type => 'post';
  @override
  int get id => post.id;
  @override
  String get caption => post.caption;
  @override
  ModerationStatus get moderationStatus => post.status;
  @override
  String? get rejectionReason => post.rejectionReason;
  @override
  String? get thumbnailUrl => post.imageUrl;
  @override
  DateTime? get createdAt => post.createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PostContentItem && other.post == post);

  @override
  int get hashCode => post.hashCode;

  @override
  String toString() => 'PostContentItem($post)';
}

class ReelContentItem extends ContentItem {
  const ReelContentItem(this.reel);

  final Reel reel;

  @override
  String get type => 'reel';
  @override
  int get id => reel.id;
  @override
  String get caption => reel.caption;
  @override
  ModerationStatus get moderationStatus => reel.status;
  @override
  String? get rejectionReason => reel.rejectionReason;
  @override
  String? get thumbnailUrl => reel.thumbnailUrl;
  @override
  DateTime? get createdAt => reel.createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReelContentItem && other.reel == reel);

  @override
  int get hashCode => reel.hashCode;

  @override
  String toString() => 'ReelContentItem($reel)';
}