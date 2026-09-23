import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../data/story_creation_repository.dart';

/// Part P-051 scope: the background retry queue architecture Section 27
/// requires for Story uploads. See `story_creation_repository.dart`'s
/// own class doc for why this feature has no separate domain interface
/// — the same reasoning applies here (`StoryUploadQueueNotifier` is the
/// sole caller of `StoryCreationRepository`).
///
/// ### FLAGGED SCOPE DECISION 1 — plain `Notifier`, not `AsyncNotifier`
///
/// Every other list-holding Notifier in this codebase
/// (`OwnProductsNotifier`, `BusinessProfileNotifier`...) is an
/// `AsyncNotifier`, because their `build()` makes a real network call.
/// This one's `build()` has nothing to fetch — an upload queue starts
/// empty, full stop — so it's a plain `Notifier<List<UploadTask>>`
/// instead. First plain `Notifier` in the codebase; if that's wrong for
/// a reason not visible from this part's own scope, that's a call for
/// Ahmed, not silently reverted here.
///
/// ### FLAGGED SCOPE DECISION 2 — backoff delay is injectable
///
/// Real schedule: attempt 1 fires immediately (no delay). On failure,
/// wait `_delays[attempt - 1]` before the next attempt — 2s/4s/8s/16s
/// before attempts 2/3/4/5. The 32s entry in `_delays` is unreachable
/// at `_maxAttempts = 5`; kept so raising the cap later needs no change
/// here. (The master plan's own prose — "2s, 4s, 8s, 16s, 32s for
/// attempts 1 through 5" — doesn't cleanly map onto a 5-attempt cap;
/// this is the reading chosen, spelled out rather than silently
/// guessed.) Waiting through 2+4+8+16 = 30 real seconds per
/// exhausted-retries test isn't acceptable for a unit test suite, so
/// the constructor takes an optional `backoffDelayForAttempt`,
/// defaulting to the real schedule. Production code (STEP 4's screen)
/// never passes it, so it always gets the real schedule.
///
/// ### FLAGGED SCOPE DECISION 3 — no "reflect in own content list" here
///
/// This part's EXECUTION PROMPT says a successful upload should
/// "reflect the new Story in the business's own content list." No
/// own-stories-list provider exists anywhere in this codebase yet
/// (confirmed — no counterpart to `OwnProductsNotifier` for stories).
/// Inventing one is out of scope for a part whose Files Expected list
/// names exactly three files, none of them that provider. On success
/// this notifier only removes the task from ITS OWN queue — wiring a
/// real own-stories list to refresh afterward is for whichever future
/// part actually builds that list.
class UploadTask {
  UploadTask({
    required this.id,
    required this.mediaFile,
    required this.attempt,
    required this.status,
    required this.cancelToken,
    this.errorMessage,
  });

  final String id;
  final File mediaFile;
  final int attempt;
  final UploadTaskStatus status;
  final CancelToken cancelToken;

  /// Only meaningful when [status] is [UploadTaskStatus.failed] — the
  /// human-readable reason shown next to the manual "try again"
  /// affordance (STEP 4).
  final String? errorMessage;

  UploadTask copyWith({
    int? attempt,
    UploadTaskStatus? status,
    CancelToken? cancelToken,
    String? errorMessage,
  }) {
    return UploadTask(
      id: id,
      mediaFile: mediaFile,
      attempt: attempt ?? this.attempt,
      status: status ?? this.status,
      cancelToken: cancelToken ?? this.cancelToken,
      errorMessage: errorMessage,
    );
  }
}

enum UploadTaskStatus {
  /// A request is genuinely in flight right now — the initial attempt,
  /// or a manually-triggered retry after [UploadTaskStatus.failed].
  uploading,

  /// A retryable failure happened and this task is waiting out its
  /// backoff delay before the next automatic attempt.
  retrying,

  /// Either the attempt cap (5) was exhausted, or the very first
  /// attempt failed with a [ValidationFailure] (never retried — see
  /// [StoryUploadQueueNotifier._isRetryable]). Terminal until the user
  /// manually retries or discards it (STEP 4).
  failed,
}

/// Signature for [StoryUploadQueueNotifier]'s injectable backoff
/// function — see FLAGGED SCOPE DECISION 2 above.
typedef BackoffDelayForAttempt = Duration Function(int failedAttempt);

class StoryUploadQueueNotifier extends Notifier<List<UploadTask>> {
  StoryUploadQueueNotifier({BackoffDelayForAttempt? backoffDelayForAttempt})
    : _backoffDelayForAttempt =
          backoffDelayForAttempt ?? _defaultBackoffDelayForAttempt;

  final BackoffDelayForAttempt _backoffDelayForAttempt;

  static const _maxAttempts = 5;
  var _nextTaskId = 0;

  static const _delays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 32),
  ];

  static Duration _defaultBackoffDelayForAttempt(int failedAttempt) =>
      _delays[failedAttempt - 1];

  final Map<String, Timer> _pendingTimers = {};

  @override
  List<UploadTask> build() => const [];

  /// Adds [mediaFile] to the queue and fires the first attempt
  /// immediately. Returns the new task's id so a caller (STEP 4's
  /// screen) can reference/cancel it.
  String enqueueUpload(File mediaFile) {
    final id = 'upload_${_nextTaskId++}';
    final task = UploadTask(
      id: id,
      mediaFile: mediaFile,
      attempt: 1,
      status: UploadTaskStatus.uploading,
      cancelToken: CancelToken(),
    );
    state = [...state, task];
    unawaited(_attempt(id));
    return id;
  }

  /// Cancels [taskId] mid-flight or mid-backoff-wait, per this part's
  /// own spec ("allow a user-initiated cancel if they change their
  /// mind mid-retry-cycle"). Cancels any pending backoff [Timer],
  /// cancels the [CancelToken] (a no-op if nothing is actually in
  /// flight), and removes the task from [state] unconditionally.
  void cancel(String taskId) {
    _pendingTimers.remove(taskId)?.cancel();
    final task = _findTask(taskId);
    task?.cancelToken.cancel('Cancelled by user.');
    state = state.where((t) => t.id != taskId).toList();
  }

  /// Discards a terminal [UploadTaskStatus.failed] task without
  /// retrying — the "discard it" half of this part's spec for the
  /// post-cap-exhaustion manual affordance.
  void discard(String taskId) {
    state = state.where((t) => t.id != taskId).toList();
  }

  /// Manually retries a terminal [UploadTaskStatus.failed] task,
  /// resetting its attempt counter back to 1, per this part's spec
  /// ("the ability for the user to manually trigger one more explicit
  /// retry, resetting the attempt counter"). Issues a fresh
  /// [CancelToken] — the old one may already be cancelled/used.
  void retryFailedTask(String taskId) {
    final task = _findTask(taskId);
    if (task == null || task.status != UploadTaskStatus.failed) return;
    _updateTask(
      taskId,
      (t) => t.copyWith(
        attempt: 1,
        status: UploadTaskStatus.uploading,
        cancelToken: CancelToken(),
        errorMessage: null,
      ),
    );
    unawaited(_attempt(taskId));
  }

  Future<void> _attempt(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) return; // Cancelled/discarded before this ran.

    try {
      await ref
          .read(storyCreationRepositoryProvider)
          .uploadStoryMedia(
            mediaFile: task.mediaFile,
            cancelToken: task.cancelToken,
          );
      // Success — remove from the queue. See FLAGGED SCOPE DECISION 3
      // above for why nothing else happens here.
      state = state.where((t) => t.id != taskId).toList();
    } on DioException catch (e) {
      _handleFailure(taskId, task, e);
    }
  }

  void _handleFailure(String taskId, UploadTask task, DioException e) {
    // Task may have been cancelled/discarded while the request was in
    // flight — re-check before touching state.
    if (_findTask(taskId) == null) return;

    final message = e.error is ApiFailure
        ? (e.error as ApiFailure).message
        : 'Upload failed.';

    if (!_isRetryable(e)) {
      _updateTask(
        taskId,
        (t) => t.copyWith(status: UploadTaskStatus.failed, errorMessage: message),
      );
      return;
    }

    if (task.attempt >= _maxAttempts) {
      _updateTask(
        taskId,
        (t) => t.copyWith(status: UploadTaskStatus.failed, errorMessage: message),
      );
      return;
    }

    final delay = _backoffDelayForAttempt(task.attempt);
    _updateTask(taskId, (t) => t.copyWith(status: UploadTaskStatus.retrying));
    _pendingTimers[taskId] = Timer(delay, () {
      _pendingTimers.remove(taskId);
      final stillPending = _findTask(taskId);
      if (stillPending == null) return; // Cancelled during the wait.
      _updateTask(
        taskId,
        (t) => t.copyWith(attempt: t.attempt + 1, status: UploadTaskStatus.uploading),
      );
      unawaited(_attempt(taskId));
    });
  }

  /// A [ValidationFailure] (HTTP 400 — e.g. an unsupported file type)
  /// is never retried, per this part's spec: "NOT a validation error
  /// like an invalid file type, which should fail immediately without
  /// retrying since retrying won't fix a genuinely invalid file."
  /// Every other [ApiFailure] variant (Network/Server/Auth/Unknown) IS
  /// retried — the spec names only validation errors as the exclusion.
  bool _isRetryable(DioException e) => e.error is! ValidationFailure;

  UploadTask? _findTask(String taskId) {
    for (final t in state) {
      if (t.id == taskId) return t;
    }
    return null;
  }

  void _updateTask(String taskId, UploadTask Function(UploadTask) update) {
    state = [
      for (final t in state)
        if (t.id == taskId) update(t) else t,
    ];
  }
}

final storyUploadQueueProvider =
    NotifierProvider<StoryUploadQueueNotifier, List<UploadTask>>(
      StoryUploadQueueNotifier.new,
    );