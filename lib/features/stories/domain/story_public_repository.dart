import '../../../core/network/paginated_response.dart';
import 'public_story_entity.dart';

/// Part P-050 scope: the domain-facing contract for PUBLIC, read-only
/// Story reads and view-tracking writes — what a Customer sees and
/// does while watching a business's Stories. Same domain/data split as
/// `PostPublicRepository`/`ReelPublicRepository` (Part P-045):
/// interface here in `domain/`, implementation in `data/`.
abstract class StoryPublicRepository {
  /// Calls `GET /api/v1/stories/public/?business_id={businessId}`
  /// (`stories.views.StoryPublicListView`, Part P-048) — only
  /// currently-visible (published AND not-yet-expired) Stories for one
  /// business. Cursor-paginated; this part only consumes the first
  /// page, same scope decision as
  /// `PostPublicRepository.fetchBusinessPosts` (Part P-045) —
  /// `StoryViewerScreen`'s sequence (this part, later step) is built
  /// from that first page only.
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  );

  /// Calls `POST /api/v1/stories/{id}/view/`
  /// (`stories.views.StoryViewRecordView`, Part P-049) — records that
  /// the signed-in customer viewed this Story. Idempotent on the
  /// backend (`StoryView.objects.get_or_create`). Deliberately returns
  /// `Future<void>` rather than a bool/result the UI branches on: the
  /// master plan's own spec requires this call to be fire-and-forget
  /// and never block advancing to the next story. See
  /// `StoryPublicRepositoryImpl.recordView` (next step) for exactly
  /// how a failure here is swallowed (via `reportError`) rather than
  /// ever rethrown into an unawaited caller.
  Future<void> recordView(int storyId);
}