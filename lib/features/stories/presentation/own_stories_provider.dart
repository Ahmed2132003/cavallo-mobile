import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/own_stories_repository.dart';
import '../domain/own_story_entity.dart';
import 'story_upload_queue_provider.dart';

/// Part P-083 scope: `ownStoriesProvider` -- the signed-in Business
/// account's own Stories (all statuses), first page only (20 items, same
/// scope decision as `ownProductsProvider`: no "load more" UI). Plain,
/// non-code-gen Riverpod, like every other notifier in this project.
///
/// State is `AsyncValue<List<OwnStory>>`:
/// * `AsyncData([...])` -- newest first, as the backend returns them. An
///   empty list is a valid state (a business that never posted a Story).
/// * `AsyncError` -- a genuine failure (typed `ApiFailure` inside the
///   `DioException`, Part P-004).
///
/// ### autoDispose, and why
///
/// Unlike `ownProductsProvider`, this provider is `.autoDispose`: it
/// holds one account's private data, and `SessionNotifier.logout()` only
/// force-invalidates a few specific providers. Disposing when nothing
/// watches it guarantees the next account never sees the previous
/// account's Stories. Inside the Business Console shell the Stories tab
/// stays mounted (`StatefulShellRoute.indexedStack`), so in practice it
/// lives as long as the console does. Retry is disabled (`retry` returns
/// null) like `notificationListProvider`: the screen offers an explicit
/// Retry button instead of Riverpod 3's silent automatic retries.
///
/// ### Refreshing after an upload (read-only coupling to P-051)
///
/// `StoryUploadQueueNotifier` (P-051) deliberately never touched any
/// "own stories" list (its Flagged Decision 3: no such list existed).
/// This notifier closes that gap from the OTHER side: it only LISTENS to
/// `storyUploadQueueProvider` and refreshes when a task that was still
/// `uploading`/`retrying` leaves the queue. The queue removes a task on
/// success, so that is the "story just got created" signal. It also
/// removes a task on user cancel; a refresh then is redundant but
/// harmless. A task removed while `failed` (the user discarded it) never
/// produced a Story, so it does not refresh. No `story_upload_*` file is
/// modified.
class OwnStoriesNotifier extends AsyncNotifier<List<OwnStory>> {
  @override
  Future<List<OwnStory>> build() async {
    ref.listen<List<UploadTask>>(storyUploadQueueProvider, (previous, next) {
      if (previous == null) return;
      if (_anyActiveTaskLeft(previous, next)) {
        unawaited(refresh());
      }
    });

    final page = await ref.watch(ownStoriesRepositoryProvider).listOwnStories();
    return page.results;
  }

  /// Re-runs the same `GET /api/v1/stories/` call [build] makes and
  /// assigns the result to [state], without disposing the notifier -- the
  /// pull-to-refresh action, the Retry button, and the post-upload reload.
  ///
  /// While data is already on screen, [state] is NOT reset to loading, so
  /// the list never flashes away during a refresh. A failed refresh
  /// settles into [AsyncError] without rethrowing (same contract as
  /// `OwnProductsNotifier.refreshProducts`), so the screen can show its
  /// error state with Retry.
  Future<void> refresh() async {
    if (!state.hasValue) {
      state = const AsyncValue<List<OwnStory>>.loading();
    }
    final result = await AsyncValue.guard<List<OwnStory>>(() async {
      final page =
          await ref.read(ownStoriesRepositoryProvider).listOwnStories();
      return page.results;
    });
    if (!ref.mounted) return;
    state = result;
  }

  static bool _anyActiveTaskLeft(
    List<UploadTask> previous,
    List<UploadTask> next,
  ) {
    final nextIds = {for (final t in next) t.id};
    for (final task in previous) {
      final wasActive =
          task.status == UploadTaskStatus.uploading ||
          task.status == UploadTaskStatus.retrying;
      if (wasActive && !nextIds.contains(task.id)) return true;
    }
    return false;
  }
}

final ownStoriesProvider =
    AsyncNotifierProvider.autoDispose<OwnStoriesNotifier, List<OwnStory>>(
      OwnStoriesNotifier.new,
      retry: (retryCount, error) => null,
    );
