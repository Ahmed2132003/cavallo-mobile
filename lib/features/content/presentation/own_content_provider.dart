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
/// Both repository calls are STARTED before either is awaited (see
/// [_fetchMerged]) — they hit two independent endpoints
/// (`/api/v1/posts/`, `/api/v1/reels/`), so there is no reason to wait
/// for one before starting the other. `Future.wait` was deliberately
/// NOT used: it requires a single `Future<T>` type, and
/// `PaginatedResponse<Post>`/`PaginatedResponse<Reel>` are different
/// `T`s. If EITHER call fails, [build] rethrows and the whole screen
/// shows `AsyncError` (no partial "Posts loaded, Reels silently
/// missing" state) — the same "don't silently swallow a failure"
/// principle `ProductListScreen`'s own docstring (Part P-033) already
/// established for this project.
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
import '../domain/post_repository.dart';
import '../domain/reel_repository.dart';

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

  Future<List<ContentItem>> _fetchMerged(
    PostRepository postRepo,
    ReelRepository reelRepo,
  ) async {
    // Both started before either is awaited — concurrent, not
    // sequential. See this file's module docstring.
    final postsFuture = postRepo.fetchOwnPosts();
    final reelsFuture = reelRepo.fetchOwnReels();

    final postsPage = await postsFuture;
    final reelsPage = await reelsFuture;

    final merged = <ContentItem>[
      ...postsPage.results.map(PostContentItem.new),
      ...reelsPage.results.map(ReelContentItem.new),
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