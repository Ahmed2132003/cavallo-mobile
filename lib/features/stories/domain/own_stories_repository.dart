import '../../../core/network/paginated_response.dart';
import 'own_story_entity.dart';

/// Part P-083 scope: the domain-facing contract for reading the signed-in
/// Business account's OWN stories (all statuses). Same domain/data split
/// as `StoryPublicRepository` (Part P-050): interface here, implementation
/// in `data/own_stories_repository.dart`.
///
/// Creation is NOT part of this contract -- it stays exclusively in
/// `StoryCreationRepository` (Part P-051), which this part never touches.
abstract class OwnStoriesRepository {
  /// Calls `GET /api/v1/stories/` (`StoryListCreateView`, Part P-046/P-047):
  /// only the signed-in business's own stories, newest first, across ALL
  /// statuses. Cursor-paginated (`{results, next, previous}`); this part
  /// only consumes the first page (20 items), same scope decision as
  /// `ProductRepository.fetchOwnProducts` -- no "load more" UI.
  ///
  /// Every `DioException` is rethrown untouched so `.error` stays a typed
  /// `ApiFailure` (`ErrorInterceptor`, Part P-004).
  Future<PaginatedResponse<OwnStory>> listOwnStories();
}
