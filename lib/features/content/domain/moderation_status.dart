/// Part P-044 scope: mirrors `moderation.models.Moderatable.Status`
/// exactly (`"pending_review"` / `"published"` / `"rejected"`) — the
/// shared status contract every Moderatable-backed content type (Post,
/// Reel, and Story later) uses identically, confirmed against
/// `moderation/models.py` on GitHub, not guessed. Kept in its own file
/// (not nested inside `post_entity.dart`) because both [Post] (Part
/// P-041) and [Reel] (Part P-042) need it identically, plus the
/// unified `ContentItem` wrapper (`content_item_entity.dart`).
library;

enum ModerationStatus {
  pendingReview,
  published,
  rejected;

  /// Parses the backend's raw `status` string. Throws [FormatException]
  /// on anything unrecognized rather than silently defaulting — same
  /// convention as `Currency.fromWire`/`QueueItemStatus.fromWire`
  /// elsewhere in this project (Parts P-033/P-040).
  static ModerationStatus fromWire(String value) {
    switch (value) {
      case 'pending_review':
        return ModerationStatus.pendingReview;
      case 'published':
        return ModerationStatus.published;
      case 'rejected':
        return ModerationStatus.rejected;
      default:
        throw FormatException(
          'Unknown moderation status from backend: $value',
        );
    }
  }
}