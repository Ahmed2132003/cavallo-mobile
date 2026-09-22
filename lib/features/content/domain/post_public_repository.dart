import '../../../core/network/paginated_response.dart';
import 'public_post_entity.dart';

/// Part P-045 scope: the domain-facing contract for PUBLIC, read-only
/// Post reads — what a Customer sees while browsing. Mirrors
/// `ProductPublicRepository`'s exact split (Part P-034): interface
/// here in `domain/`, implementation in `data/`. Deliberately a
/// separate contract from `PostRepository` (Part P-044), which is "my
/// own posts" CRUD resolved from `request.user` — never merged with
/// it.
abstract class PostPublicRepository {
  /// Calls `GET /api/v1/posts/{id}/` (`content.views.PostDetailView`,
  /// public GET). Returns `null` — a real, renderable "not found"
  /// state, never an error — when the post does not exist (backend
  /// 404) OR when it exists but its `status` is not `"published"`. See
  /// `PostPublicRepositoryImpl` for why this endpoint (not a
  /// `/public/` detail route, which doesn't exist) is used.
  Future<PublicPost?> fetchPublicPost(int id);

  /// Calls `GET /api/v1/posts/public/?business_id={businessId}`
  /// (`content.views.PostPublicListView`, Part P-043) — only published
  /// Posts, optionally narrowed to one business. Cursor-paginated; this
  /// part only consumes the first page, same scope decision as
  /// `ProductPublicRepository.fetchBusinessProducts` (Part P-034).
  Future<PaginatedResponse<PublicPost>> fetchBusinessPosts(int businessId);
}