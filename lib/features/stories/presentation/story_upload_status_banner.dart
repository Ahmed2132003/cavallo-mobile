import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'story_upload_queue_provider.dart';

/// Part P-051 STEP 5 scope: `lib/features/stories/presentation/
/// story_upload_status_banner.dart` — the "small persistent
/// banner/snackbar-style indicator" the master plan asks for, so a
/// business never loses track of a Story upload silently failing
/// mid-retry (Section 27's explicit requirement).
///
/// A plain `ConsumerWidget`, not a `StatefulWidget` — it holds no state
/// of its own, only renders whatever [storyUploadQueueProvider]
/// currently says. One row per [UploadTask], so more than one
/// concurrent Story upload (rare, but not disallowed by the queue
/// provider) is shown honestly rather than collapsed into a single
/// "something is uploading" line.
///
/// ### FLAGGED SCOPE DECISION 6 — two homes, not one app-wide overlay
///
/// The execution prompt says this indicator "should remain
/// visible/accessible even if the user navigates away from this
/// specific screen" and suggests "a small persistent banner ...
/// reachable from elsewhere in the business console area." A single,
/// truly app-wide persistent overlay would need a root-level shell
/// (e.g. a `StatefulShellRoute` wrapping every screen) — that doesn't
/// exist yet; the master plan's own Phase 14 is where the real
/// Business Console shell (tabs/drawer) gets built. Building one now,
/// just for this part, would be exactly the kind of premature
/// infrastructure this project's parts consistently avoid (see e.g.
/// `content_list_screen.dart`'s own "no WebSocket channel yet" note for
/// the same pattern). Instead this same stateless widget is placed in
/// TWO screens: `StoryCreationScreen` itself (STEP 4) and
/// `BusinessConsoleScreen` (STEP 5) — the console screen is the one
/// screen every business-console navigation flow passes back through,
/// so returning to it after navigating away from the creation screen
/// still surfaces the same live queue state. Documented here per the
/// prompt's own "document your choice" instruction.
class StoryUploadStatusBanner extends ConsumerWidget {
  const StoryUploadStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(storyUploadQueueProvider);
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('storyUploadStatusBanner'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final task in tasks) _StoryUploadTaskRow(task: task),
      ],
    );
  }
}

class _StoryUploadTaskRow extends ConsumerWidget {
  const _StoryUploadTaskRow({required this.task});

  final UploadTask task;

  String get _statusLabel => switch (task.status) {
    UploadTaskStatus.uploading =>
      'Uploading story... (attempt ${task.attempt} of 5)',
    UploadTaskStatus.retrying =>
      'Connection lost — retrying story upload... '
          '(attempt ${task.attempt} of 5)',
    UploadTaskStatus.failed => task.errorMessage == null
        ? 'Story upload failed.'
        : 'Story upload failed: ${task.errorMessage}',
  };

  IconData get _statusIcon => switch (task.status) {
    UploadTaskStatus.uploading => Icons.cloud_upload_outlined,
    UploadTaskStatus.retrying => Icons.sync_problem,
    UploadTaskStatus.failed => Icons.error_outline,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(storyUploadQueueProvider.notifier);
    final isFailed = task.status == UploadTaskStatus.failed;
    final theme = Theme.of(context);

    return Container(
      key: Key('storyUploadStatusBanner_row_${task.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isFailed
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _statusIcon,
            color: isFailed ? theme.colorScheme.error : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusLabel,
              key: Key('storyUploadStatusBanner_label_${task.id}'),
            ),
          ),
          if (isFailed) ...[
            TextButton(
              key: Key('storyUploadStatusBanner_retry_${task.id}'),
              onPressed: () => notifier.retryFailedTask(task.id),
              child: const Text('Retry'),
            ),
            IconButton(
              key: Key('storyUploadStatusBanner_discard_${task.id}'),
              tooltip: 'Discard',
              icon: const Icon(Icons.close),
              onPressed: () => notifier.discard(task.id),
            ),
          ] else
            IconButton(
              key: Key('storyUploadStatusBanner_cancel_${task.id}'),
              tooltip: 'Cancel',
              icon: const Icon(Icons.close),
              onPressed: () => notifier.cancel(task.id),
            ),
        ],
      ),
    );
  }
}