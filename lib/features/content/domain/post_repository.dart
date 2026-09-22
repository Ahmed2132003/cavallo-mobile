/// Part P-044 scope: the domain-facing contract for Post — mirrors
/// `ProductRepository`'s exact split (Part P-033). Implementation
/// (`post_repository_impl.dart`, this same combined step) is the only
/// thing that knows this is backed by HTTP/multipart/DTOs.
///
/// Calls `/api/v1/posts/` (`content.views.PostListCreateView`, Part
/// P-041) — ownership is always resolved server-side from
/// `request.user.business_profile`, never from a client-supplied id,
/// so there is deliberately no `businessId` parameter anywhere on this
/// contract, same as `ProductRepository`.
///
/// **Scope note (deliberate, this part's own decision — see STEP 2/3's
/// own message):** create + own-list ONLY. `PostDetailView`'s
/// PATCH/DELETE (Part P-041) already exist server-side but have no
/// Flutter caller here — P-044's spec only asks for creation screens
/// and status feedback, not an edit/delete UI. A future part can add
/// `updatePost`/`deletePost` here without changing this contract's
/// shape, same precedent as `ProductRepository`.
///
/// **Image upload note:** `content.serializers.PostSerializer` has a
/// single `image` field alongside `caption` on the SAME create request
/// (one multipart body when an image is attached) — there is no
/// separate "upload image" endpoint, same shape as `ProductRepository`.
library;

import 'dart:io';

import '../../../core/network/paginated_response.dart';
import 'post_entity.dart';

abstract class PostRepository {
  /// Calls `GET /api/v1/posts/` — lists only the signed-in Business
  /// account's own posts. Cursor-paginated; this part's own scope only
  /// consumes the first page, same as `ProductRepository.fetchOwnProducts`.
  Future<PaginatedResponse<Post>> fetchOwnPosts();

  /// Calls `POST /api/v1/posts/` (multipart when [imageFile] is
  /// provided, plain JSON otherwise — `image` is optional on
  /// `Post.image`, same conditional-multipart shape as
  /// `ProductRepository.createProduct`).
  Future<Post> createPost({required String caption, File? imageFile});
}