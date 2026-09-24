import '../../../core/network/paginated_response.dart';
import 'comment_entity.dart';
import 'report_reason.dart';

/// Part P-058 scope: the domain-facing contract covering all six
/// Phase 9 backend interactions (Follow P-052, Like P-053, Save
/// P-054, Comment P-055, Share P-056, Report P-057) behind one
/// repository — consolidated per this part's own Scope note ("a
/// single repository covering follow/like/save/share/comment/report
/// calls — reasonable to consolidate given how closely related and
/// small each individual call is"). Interface here in `domain/`,
/// implementation in `data/` — same split as every prior repository
/// in this project (`PostPublicRepository`, `ProductPublicRepository`,
/// ...).
///
/// Every method's request/response shape below is copied verbatim
/// from the real backend source (`social/views.py`, `social/
/// serializers.py`, `reports/views.py`, `reports/serializers.py` —
/// `cavallo-app`), not from the master-plan spec's prose, per this
/// project's own "check first" convention (P-052 → P-057 each did
/// this before writing a line of backend code; this step does the
/// same for the Flutter side).
abstract class SocialInteractionRepository {
  // ---- Follow (P-052) — business-scoped, not content-type-scoped ----

  /// `POST /api/v1/businesses/{businessId}/follow/`. Idempotent.
  /// Returns the server's canonical `following` value (always `true`
  /// on success — repeating this call on an already-followed business
  /// is harmless and still returns `true`).
  Future<bool> followBusiness(int businessId);

  /// `DELETE /api/v1/businesses/{businessId}/follow/`. Idempotent.
  /// Returns the server's canonical `following` value (always `false`
  /// on success, including the harmless no-op of unfollowing a
  /// business never followed).
  Future<bool> unfollowBusiness(int businessId);

  // ---- Like (P-053) — content_type must be "post" or "reel" ----

  /// `POST /api/v1/likes/` with `{content_type, object_id}`.
  /// Idempotent. Returns the server's canonical `liked` value.
  Future<bool> likeContent({
    required String contentType,
    required int objectId,
  });

  /// `DELETE /api/v1/likes/` with `{content_type, object_id}`.
  /// Idempotent. Returns the server's canonical `liked` value.
  Future<bool> unlikeContent({
    required String contentType,
    required int objectId,
  });

  // ---- Save (P-054) — content_type: "post" | "reel" | "product" ----

  /// `POST /api/v1/saves/` with `{content_type, object_id}`.
  /// Idempotent. Returns the server's canonical `saved` value.
  Future<bool> saveContent({
    required String contentType,
    required int objectId,
  });

  /// `DELETE /api/v1/saves/` with `{content_type, object_id}`.
  /// Idempotent. Returns the server's canonical `saved` value.
  Future<bool> unsaveContent({
    required String contentType,
    required int objectId,
  });

  // ---- Comment (P-055) — content_type must be "post" or "reel" ----

  /// `POST /api/v1/comments/` with `{content_type, object_id, text}`.
  /// NOT idempotent (a genuine new Comment row every call, same as
  /// any create endpoint). Target must be published — a pending/
  /// rejected/deleted Post or Reel returns 404. Returns the created
  /// [CommentEntity] (backend responds `201` with the full
  /// `CommentSerializer` shape).
  Future<CommentEntity> createComment({
    required String contentType,
    required int objectId,
    required String text,
  });

  /// `GET /api/v1/comments/?content_type=..&object_id=..`, public
  /// (no auth required), cursor-paginated, newest-first. Hidden
  /// comments are filtered SERVER-SIDE per viewer role (anonymous/
  /// unrelated user never receives them; the comment's own author and
  /// moderators do, with `isHidden: true`) — this repository must
  /// apply NO additional client-side filtering, per this part's own
  /// Detailed Implementation note ("no extra client-side filtering
  /// logic needed beyond trusting the API response").
  ///
  /// [pageUrl], when non-null, is the exact `next`/`previous` cursor
  /// URL from a prior [PaginatedResponse] — passed to Dio verbatim,
  /// never parsed/rebuilt, same convention `PaginatedResponse`'s own
  /// docstring establishes. When null, fetches the first page for
  /// (`contentType`, `objectId`).
  Future<PaginatedResponse<CommentEntity>> listComments({
    required String contentType,
    required int objectId,
    String? pageUrl,
  });

  // ---- Share (P-056) — DELIBERATELY NON-IDEMPOTENT, see impl ----

  /// `POST /api/v1/shares/` with `{content_type, object_id}`. Every
  /// successful call is a genuine new event — the caller (Step 3's
  /// provider) must NOT dedupe/debounce this on the assumption the
  /// server deduplicates; it does not, by design (P-056). Returns
  /// nothing meaningful beyond success (`201 {"shared": true}`); the
  /// caller increments its own local `sharesCount` optimistically
  /// since the backend does not return a canonical count to reconcile
  /// against (`shares_count` is not exposed by any serializer yet).
  Future<void> shareContent({
    required String contentType,
    required int objectId,
  });

  // ---- Report (P-057) — its own closed whitelist, see report_reason.dart ----

  /// `POST /api/v1/reports/` with
  /// `{content_type, object_id, reason, details?}`. Idempotent per
  /// (reporter, target) — both a fresh report (`201`) and a repeat
  /// report by the same user on the same target (`200`) mean
  /// "reported"; neither is an error the caller should surface
  /// differently. `details` is optional for every [reason], not just
  /// `other`.
  Future<void> reportTarget({
    required String contentType,
    required int objectId,
    required ReportReason reason,
    String? details,
  });
}