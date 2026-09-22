/// Part P-044 scope: `ownContentProvider` — the single source of truth
/// for "what does the signed-in Business account's own Post/Reel list
/// look like right now," combining `PostRepository.fetchOwnPosts()`
/// and `ReelRepository.fetchOwnReels()` (STEP 2/3 of this part) into
/// one unified, type-tagged list. Plain, non-code-gen Riverpod
/// (`AsyncNotifier`), same convention as `OwnProductsNotifier` (Part
/// P-033) and `ModerationQueueNotifier` (Part P-040).
///
/// State is `AsyncValue<List<ContentItem>>`, sorted newest-first (see
/// [sortContentItems]) — an empty list is a valid, expected state (a
/// business with no Posts/Reels yet), never an error.
///
/// ### Why both fetches run concurrently, and why either failing fails
/// the whole build
///
/// Both repository calls are started concurrently (see [_fetchMerged])
/// — they hit two independent endpoints (`/api/v1/posts/`,
/// `/api/v1/reels/`), so there is no reason to wait for one before
/// starting the other. If EITHER call fails, [build] rethrows and the
/// whole screen shows `AsyncError` (no partial "Posts loaded, Reels
/// silently missing" state) — the same "don't silently swallow a
/// failure" principle `ProductListScreen`'s own docstring (Part P-033)
/// already established for this project.
///
/// ### `Future.wait`, not two separately-awaited locals (fixed after
/// a real `flutter test` failure — not a hypothetical)
///
/// An earlier version of [_fetchMerged] started both futures, assigned
/// them to two local variables, and awaited them ONE AT A TIME
/// (`final postsPage = await postsFuture;` then
/// `final reelsPage = await reelsFuture;`). That pattern is
/// functionally correct — the second future's rejection IS eventually
/// caught by its own `await` — but it produces a genuine Dart Zone
/// "Unhandled exception in Future" report whenever the SECOND-awaited
/// future is also the one that rejects: between the moment it settles
/// (rejects) and the moment the code actually reaches its `await`,
/// Dart's zone error handler sees a rejected future with no listener
/// yet attached, and reports it as unhandled — even though the code
/// goes on to handle it two lines later. This showed up as a real,
/// reproducible `flutter test` failure on the "when the Reel fetch
/// fails, the whole merge fails" test (the Post fetch — awaited FIRST
/// — never triggered it; only whichever future was awaited SECOND
/// could).
///
/// `Future.wait` fixes this at the root: it attaches a listener to
/// every future in its list synchronously, at the moment it's called,
/// so neither future is ever left unobserved regardless of which one
/// settles first or which one fails. Concurrency and the
/// eager-fail-on-any-error contract are both unchanged — only the
/// waiting mechanism changed.
///
/// ### Why mutations refresh the whole list, not just their own half
///
/// Unlike `OwnProductsNotifier` (single content type), a successful
/// [createPost]/[createReel] here calls [refresh] — a full re-fetch of
/// BOTH endpoints — rather than splicing just the new item into
/// [state] locally. This keeps this notifier a thin, obviously-correct
/// merge of two lists instead of hand-maintaining two independently
/// mutable sub-lists. The extra round trip is for ONE endpoint (the
/// one that didn't just change) and is judged acceptable for this
/// part's scope — creating a Post/Reel is not a frequent, back-to-back
/// action the way moderator approve/reject is (see
/// `ModerationQueueNotifier`'s own docstring for why THAT notifier
/// avoids a refetch instead).
///
/// On failure, [createPost]/[createReel] leave [state] completely
/// untouched and rethrow the original exception (a `DioException`
/// whose `.error` is a typed `ApiFailure`) to the caller — same
/// failure contract as `OwnProductsNotifier.createProduct`.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post_repository_impl.dart';
import '../data/reel_repository_impl.dart';
import '../domain/content_item_entity.dart';
import '../domain/post_entity.dart';
import '../domain/post_repository.dart';
import '../domain/reel_entity.dart';
import '../domain/reel_repository.dart';
import '../../../core/network/paginated_response.dart';

/// Sorts a mixed Post/Reel list newest-first by `createdAt`. An item
/// with a `null` createdAt (should not normally happen — every real
/// backend response includes it) sorts last, never crashes a
/// comparison. Returns a NEW list; [items] is not mutated — same
/// convention as `sortModerationQueue` (Part P-040).
List<ContentItem> sortContentItems(Iterable<ContentItem> items) {
  final sorted = items.toList();
  sorted.sort((a, b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });
  return sorted;
}

class OwnContentNotifier extends AsyncNotifier<List<ContentItem>> {
  @override
  Future<List<ContentItem>> build() async {
    final postRepo = ref.watch(postRepositoryProvider);
    final reelRepo = ref.watch(reelRepositoryProvider);
    return _fetchMerged(postRepo, reelRepo);
  }

  /// Runs both fetches concurrently via [Future.wait] — see this
  /// file's module docstring ("`Future.wait`, not two
  /// separately-awaited locals") for why this specific mechanism is
  /// required, not just a style preference.
  Future<List<ContentItem>> _fetchMerged(
    PostRepository postRepo,
    ReelRepository reelRepo,
  ) async {
    PaginatedResponse<Post>? postsPage;
    PaginatedResponse<Reel>? reelsPage;

    await Future.wait<void>([
      postRepo.fetchOwnPosts().then((value) => postsPage = value),
      reelRepo.fetchOwnReels().then((value) => reelsPage = value),
    ]);

    final merged = <ContentItem>[
      ...postsPage!.results.map(PostContentItem.new),
      ...reelsPage!.results.map(ReelContentItem.new),
    ];
    return sortContentItems(merged);
  }

  /// Calls `PostRepository.createPost` (`POST /api/v1/posts/`, Part
  /// P-041) and, only once that call has actually succeeded, calls
  /// [refresh]. See the class docstring for the failure contract.
  Future<void> createPost({required String caption, File? imageFile}) async {
    await ref
        .read(postRepositoryProvider)
        .createPost(caption: caption, imageFile: imageFile);
    await refresh();
  }

  /// Calls `ReelRepository.createReel` (`POST /api/v1/reels/`, Part
  /// P-042) and, only once that call has actually succeeded, calls
  /// [refresh]. The created [Reel] starts at `processing_status:
  /// "uploaded"` — [ContentListScreen]'s own polling (a later step)
  /// is what eventually observes it reach `"ready"`. See the class
  /// docstring for the failure contract.
  Future<void> createReel({
    required String caption,
    required File videoFile,
  }) async {
    await ref
        .read(reelRepositoryProvider)
        .createReel(caption: caption, videoFile: videoFile);
    await refresh();
  }

  /// Re-runs [_fetchMerged] and assigns the result to [state], without
  /// disposing/rebuilding this notifier — the pull-to-refresh action,
  /// the processing-status poll, and the shared "reload after a
  /// successful mutation" step [createPost]/[createReel] both end
  /// with.
  ///
  /// Uses [AsyncValue.guard], exactly like
  /// `OwnProductsNotifier.refreshProducts` — a failed refresh settles
  /// into [AsyncError] without rethrowing, since it's a
  /// non-destructive, retryable read, distinct from
  /// [createPost]/[createReel]'s own "rethrow to the caller" contract
  /// for the mutation itself.
  Future<void> refresh() async {
    state = const AsyncValue<List<ContentItem>>.loading();
    state = await AsyncValue.guard<List<ContentItem>>(() async {
      final postRepo = ref.read(postRepositoryProvider);
      final reelRepo = ref.read(reelRepositoryProvider);
      return _fetchMerged(postRepo, reelRepo);
    });
  }
}

/// Exposes [OwnContentNotifier] to the rest of the app, per this
/// project's established Riverpod pattern. NOT `.autoDispose`, matching
/// `ownProductsProvider`'s own choice for the same reason: a signed-in
/// Business account's own content list is meant to live for the
/// session, not be silently disposed and re-fetched on every
/// navigation.
final ownContentProvider =
    AsyncNotifierProvider<OwnContentNotifier, List<ContentItem>>(
      OwnContentNotifier.new,
    );