import '../../../core/network/paginated_response.dart';
import 'saved_item.dart';

/// Part P-113 (STEP 3B): reading the signed-in user's saved items.
///
/// Only the LIST lives here. Saving and unsaving already exist in
/// `SocialInteractionRepository` (`saveContent` / `unsaveContent`, P-058), so
/// the Saved screen reuses that one instead of adding a second implementation.
abstract class SavedRepository {
  /// `GET /api/v1/saves/me/`, newest first, mixed Posts / Reels / Products,
  /// standard `{results, next, previous}` cursor pagination.
  ///
  /// [cursor], when given, is the exact `next` URL of the previous page and is
  /// passed to Dio verbatim, never rebuilt (same rule as every other list).
  /// Rows whose `content_type` this app does not know are dropped.
  Future<PaginatedResponse<SavedItem>> listSaved({String? cursor});
}
