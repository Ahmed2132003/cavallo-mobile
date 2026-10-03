/// Part P-083 (Stories list tab) scope: the OWNER-facing domain
/// representation of a Story -- what `GET /api/v1/stories/`
/// (`StoryListCreateView`, Part P-046/P-047) returns for the signed-in
/// Business account. Deliberately a separate class from [PublicStory]
/// (`public_story_entity.dart`, Part P-050): that one is customer-facing
/// and by design never carries `status`, because every row of the public
/// endpoint is already published and not yet expired. The owner's list
/// returns ALL statuses, expired ones included
/// (`Story.objects.filter(business=business)`, no status/expiry filter).
///
/// ### Real backend `status` values
///
/// `Moderatable.Status` (`moderation/models.py`) defines exactly three:
/// `pending_review`, `published`, `rejected`. There is NO `approved`
/// and NO `expired` value in the API (approving a Story moves it
/// straight to `published`). "Expired" is therefore derived on the
/// client from `expires_at` -- see [OwnStory.displayStatus].
///
/// ### `rejectionReason`
///
/// `StorySerializer` (`stories/serializers.py`) does NOT return
/// `rejection_reason` today (Post/Reel got it in P-044, Story did not --
/// a documented open backend gap). The field is carried as optional so
/// the screen shows it automatically if the backend adds it later; it is
/// never invented client-side.
library;

/// The raw `status` string the backend sent, as an enum.
enum OwnStoryStatus {
  pendingReview,
  published,
  rejected,

  /// A `status` value this app version does not know about. Kept as a
  /// distinct value (instead of throwing) so one unexpected string can
  /// never make the whole list fail to render.
  unknown;

  static OwnStoryStatus fromWire(String? value) {
    switch (value) {
      case 'pending_review':
        return OwnStoryStatus.pendingReview;
      case 'published':
        return OwnStoryStatus.published;
      case 'rejected':
        return OwnStoryStatus.rejected;
      default:
        return OwnStoryStatus.unknown;
    }
  }
}

/// What the owner should SEE for a story at a given moment: the wire
/// status combined with `expires_at`.
enum OwnStoryDisplayStatus { pending, published, rejected, expired, unknown }

class OwnStory {
  const OwnStory({
    required this.id,
    required this.businessId,
    required this.mediaUrl,
    required this.status,
    required this.publishedAt,
    required this.expiresAt,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  final int id;

  final int businessId;

  /// `Story.media` is required on the backend, never null.
  final String mediaUrl;

  final OwnStoryStatus status;

  /// Set once, server-side, at creation (`Story.save()`).
  final DateTime publishedAt;

  /// `published_at + 24h`, computed and stored server-side at creation.
  final DateTime expiresAt;

  /// Null today for every story (backend gap, see library doc). Never
  /// an empty string -- the DTO normalizes blank to null.
  final String? rejectionReason;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The status to display at [now].
  ///
  /// * `rejected` stays `rejected` even after `expires_at`, because the
  ///   rejection (and its reason) is what the owner needs to see.
  /// * `unknown` stays `unknown`.
  /// * Any other story whose `expires_at` is not after [now] is
  ///   `expired`: it can never be visible to customers again (the public
  ///   endpoint requires `expires_at > now`), whether it was published
  ///   or was still pending review when its 24h ran out.
  OwnStoryDisplayStatus displayStatus(DateTime now) {
    if (status == OwnStoryStatus.rejected) {
      return OwnStoryDisplayStatus.rejected;
    }
    if (status == OwnStoryStatus.unknown) {
      return OwnStoryDisplayStatus.unknown;
    }
    if (!expiresAt.isAfter(now)) {
      return OwnStoryDisplayStatus.expired;
    }
    return status == OwnStoryStatus.pendingReview
        ? OwnStoryDisplayStatus.pending
        : OwnStoryDisplayStatus.published;
  }

  /// Time left of the 24h window, or null when there is no meaningful
  /// countdown: only a `published` story that has not expired yet has
  /// one. A pending or rejected story is not visible to customers, so a
  /// countdown for it would be misleading.
  Duration? remaining(DateTime now) {
    if (status != OwnStoryStatus.published || !expiresAt.isAfter(now)) {
      return null;
    }
    return expiresAt.difference(now);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OwnStory &&
          other.id == id &&
          other.businessId == businessId &&
          other.mediaUrl == mediaUrl &&
          other.status == status &&
          other.publishedAt == publishedAt &&
          other.expiresAt == expiresAt &&
          other.rejectionReason == rejectionReason &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    mediaUrl,
    status,
    publishedAt,
    expiresAt,
    rejectionReason,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'OwnStory(id: $id, status: ${status.name})';
}
