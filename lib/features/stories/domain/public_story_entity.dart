/// Part P-050 scope: the clean, customer-facing domain representation
/// of a single PUBLISHED, still-visible Story — the shape
/// `StoryPublicRepository` hands back from `GET /api/v1/stories/public/`
/// (`StoryPublicListView`, Part P-048). Follows the exact same
/// public-entity convention as `PublicPost`/`PublicReel`
/// (`public_post_entity.dart`/`public_reel_entity.dart`, Part P-045):
/// a genuinely separate class from any future owner-facing `Story`
/// domain entity (P-046/P-047's Flutter side doesn't exist yet — this
/// part builds the customer-viewing side only, per its own scope).
///
/// DELIBERATE NAMING DEVIATION FROM THE MASTER PLAN, FLAGGED NOT
/// SILENT: the master plan's own file list names this
/// `domain/story_entity.dart` with a plain `Story` class carrying a
/// `businessName` field. This project's established public-entity
/// convention (`PublicPost`, `PublicReel`) is used instead —
/// `public_story_entity.dart` / `PublicStory` — for consistency with
/// every other public, customer-facing entity in this codebase. No
/// `businessName` field exists here: `StorySerializer`
/// (`stories/serializers.py`, Part P-046) returns only the business's
/// numeric `id`, never its name — the exact same gap `PostCard`
/// (Part P-045) already hit and solved the same way (see that file's
/// own docstring on why `businessAvatarUrl` isn't a parameter either).
/// `StoryRingWidget`/`StoryViewerScreen` (this part, later steps) take
/// the business's display name as a caller-supplied parameter instead,
/// exactly like `PostCard.businessName` — the caller (a Business
/// Profile screen, which already holds the full `BusinessProfile`) is
/// the one place that actually has it.
library;

class PublicStory {
  const PublicStory({
    required this.id,
    required this.businessId,
    required this.mediaUrl,
    required this.publishedAt,
    required this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;

  final int businessId;

  /// `Story.media` is a required field on the backend (no `null=True`,
  /// no `blank=True` — `stories/models.py`), unlike `Post.image`
  /// (optional). Never null, unlike `PublicPost.imageUrl`/
  /// `PublicReel.videoUrl`.
  final String mediaUrl;

  /// Set once, server-side, at creation (`Story.save()`,
  /// `stories/models.py`) — never client-writable.
  final DateTime publishedAt;

  /// `published_at + 24h`, computed and stored server-side at creation
  /// — never client-writable. `StoryPublicRepositoryImpl` (this part,
  /// next step) only ever returns a [PublicStory] whose `expiresAt` is
  /// still in the future, by construction (the backend's own
  /// `StoryPublicListView` queryset already filters on
  /// `expires_at__gt=timezone.now()` — see that view's docstring), so
  /// callers never need to re-check it themselves.
  final DateTime expiresAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  PublicStory copyWith({
    int? id,
    int? businessId,
    String? mediaUrl,
    DateTime? publishedAt,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PublicStory(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PublicStory &&
          other.id == id &&
          other.businessId == businessId &&
          other.mediaUrl == mediaUrl &&
          other.publishedAt == publishedAt &&
          other.expiresAt == expiresAt &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    mediaUrl,
    publishedAt,
    expiresAt,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'PublicStory(id: $id, businessId: $businessId)';
}