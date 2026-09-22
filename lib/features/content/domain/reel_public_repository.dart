import '../../../core/network/paginated_response.dart';
import 'public_reel_entity.dart';

/// Part P-045 scope: same split as `PostPublicRepository` above, for
/// Reel. Calls `/api/v1/reels/public/` and `/api/v1/reels/{id}/`
/// (`content.views.ReelPublicListView`/`ReelDetailView`, Parts
/// P-042/P-043).
abstract class ReelPublicRepository {
  /// Returns `null` when the reel doesn't exist (404), OR its `status`
  /// isn't `"published"`, OR its `processing_status` isn't `"ready"` —
  /// mirroring exactly what `Reel.published_objects`
  /// (`ReelPublishedManager`) requires server-side for the list
  /// endpoint below. See `ReelPublicRepositoryImpl` for where this is
  /// enforced.
  Future<PublicReel?> fetchPublicReel(int id);

  /// Calls `GET /api/v1/reels/public/?business_id={businessId}` — only
  /// published AND fully-processed Reels. First page only, same as
  /// `PostPublicRepository.fetchBusinessPosts`.
  Future<PaginatedResponse<PublicReel>> fetchBusinessReels(int businessId);
}