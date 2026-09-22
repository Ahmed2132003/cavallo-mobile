/// Part P-044 scope: the domain-facing contract for Reel — same split
/// as `PostRepository` above. Calls `/api/v1/reels/`
/// (`content.views.ReelListCreateView`, Part P-042).
///
/// **Scope note:** create + own-list ONLY — same deliberate scope
/// decision as `PostRepository` (see that file's own docstring).
///
/// **Video upload note:** unlike Post's optional `image`,
/// `content.models.Reel.video` is REQUIRED — every `createReel` call
/// is necessarily multipart; there is no plain-JSON path (see
/// `ReelRepositoryImpl`'s own docstring).
library;

import 'dart:io';

import '../../../core/network/paginated_response.dart';
import 'reel_entity.dart';

abstract class ReelRepository {
  /// Calls `GET /api/v1/reels/` — lists only the signed-in Business
  /// account's own reels. Cursor-paginated, first page only, same as
  /// `PostRepository.fetchOwnPosts`.
  Future<PaginatedResponse<Reel>> fetchOwnReels();

  /// Calls `POST /api/v1/reels/` (always multipart — see this file's
  /// own module docstring). The backend dispatches
  /// `content.tasks.transcode_reel` asynchronously on success
  /// (`processing_status` starts at `"uploaded"`); this call returns
  /// as soon as the raw upload is accepted, NOT once transcoding
  /// finishes — a later step's `ownContentProvider`/`ContentListScreen`
  /// is responsible for refreshing to observe the status progress to
  /// `"ready"`.
  Future<Reel> createReel({required String caption, required File videoFile});
}