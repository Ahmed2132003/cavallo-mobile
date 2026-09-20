import '../../../core/network/paginated_response.dart';
import 'queue_item_entity.dart';

/// Part P-040 scope: the domain-facing contract the moderation
/// presentation layer depends on. The implementation
/// (`moderation_repository_impl.dart`) is the only thing that knows this
/// is backed by HTTP and DTOs — same split as `AuthRepository` /
/// `ProductRepository`.
///
/// Every method maps 1:1 onto a Part P-038 endpoint under
/// `/api/v1/moderation/`, all gated server-side by
/// `HasCapability("can_moderate_content")` (a Django permission, granted
/// through the Moderator/Admin Group — see the P-040 gap note in
/// PROJECT_PROGRESS.md about how that differs from the `is_moderator`
/// flag this app uses for its router gate).
///
/// Failures are NOT re-wrapped: they surface as a `DioException` whose
/// `.error` is a typed `ApiFailure` (Part P-004). Two backend outcomes
/// have no dedicated `ApiFailure` subtype and arrive as
/// `UnknownFailure` — callers that need them must read
/// `DioException.response?.statusCode`:
///   * 409 — the item was already decided (e.g. by another moderator).
///   * 404 — the queue row no longer exists.
abstract class ModerationRepository {
  /// Calls `GET /api/v1/moderation/queue/` — pending items only. The
  /// backend orders by `-created_at` (newest first) and cursor-paginates;
  /// this method asks for the maximum page size (100) so the presentation
  /// layer can apply its own "fast_path first, then oldest first" sort
  /// over as many items as one request can carry. Sorting is deliberately
  /// NOT done here — it is a presentation rule.
  ///
  /// [priority] narrows the list server-side (`?priority=`). `null`
  /// (the default) returns both priorities.
  Future<PaginatedResponse<QueueItem>> fetchQueue({QueuePriority? priority});

  /// Calls `POST /api/v1/moderation/queue/{id}/approve/` and returns the
  /// updated row (its `status` is now `approved`).
  Future<QueueItem> approve(int queueItemId);

  /// Calls `POST /api/v1/moderation/queue/{id}/reject/` with
  /// `{"reason": ...}` and returns the updated row (its `status` is now
  /// `rejected`). A blank [reason] is rejected by the backend with a 400
  /// (`ValidationFailure`, field `reason`) — the UI enforces the same
  /// rule before ever calling this, but the backend stays the authority.
  Future<QueueItem> reject({required int queueItemId, required String reason});
}