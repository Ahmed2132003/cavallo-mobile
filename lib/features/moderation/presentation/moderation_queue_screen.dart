import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../domain/queue_item_entity.dart';
import 'moderation_provider.dart';
import 'moderation_widgets.dart';

/// Part P-040 scope: the moderator's queue list. A dense, scannable list
/// rather than a decorative one — a moderator clearing many items quickly
/// benefits more from information density than from polish (per the
/// part's own design note).
///
/// Each row shows: a preview thumbnail, the preview text, the content
/// type (and submitting business when the backend knows it), a priority
/// badge (`fast_path` visually distinct) and an age chip that escalates
/// green → amber → red against the same per-priority SLA the backend's
/// P-039 job tracks (see `ModerationSla`). Order comes from
/// `moderationQueueProvider` (fast_path first, then oldest first).
///
/// Navigation is injected ([onOpenItem]) rather than hard-wired to
/// `GoRouter`, exactly like `ProductListScreen.onEditProduct` — the
/// router (a later step) supplies the real navigation, and this screen
/// stays testable with a plain `MaterialApp`.
///
/// State handling: while a refresh is in flight the previous list stays
/// on screen (the notifier refreshes through `invalidateSelf`), so
/// pull-to-refresh never blanks the queue.
class ModerationQueueScreen extends ConsumerWidget {
  const ModerationQueueScreen({super.key, required this.onOpenItem});

  /// Called when a row is tapped, with the tapped [QueueItem].
  final void Function(QueueItem item) onOpenItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(moderationQueueProvider);
    final items = queueAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation queue'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(moderationQueueProvider.notifier).refresh(),
          ),
        ],
      ),
      body: _buildBody(ref, queueAsync, items),
    );
  }

  Widget _buildBody(
    WidgetRef ref,
    AsyncValue<List<QueueItem>> queueAsync,
    List<QueueItem>? items,
  ) {
    // A failure wins over any stale list, so a moderator is never
    // looking at data that a failed refresh could not confirm — but only
    // once the retry has finished; while it runs, fall through to the
    // loading indicator so pressing Retry visibly does something.
    if (queueAsync.hasError && !queueAsync.isLoading) {
      return ErrorStateWidget(
        message: _loadErrorMessage(queueAsync.error),
        onRetry: () => ref.read(moderationQueueProvider.notifier).refresh(),
      );
    }
    if (items == null) {
      return const LoadingIndicator();
    }
    if (items.isEmpty) {
      return const EmptyStateWidget(
        message: 'The queue is clear.\nNothing is waiting for review.',
        icon: Icons.task_alt,
      );
    }
    return _QueueListView(items: items, onOpenItem: onOpenItem);
  }
}

/// Maps a load failure to what the moderator should read. A 403 gets a
/// dedicated message because it has a specific, actionable cause in this
/// project: the app gates the route on the `is_moderator`/`is_staff`
/// flags, but the API requires the `can_moderate_content` permission,
/// which comes from Group membership — an account with the flag but not
/// the Group lands here (see the P-040 gap note in PROJECT_PROGRESS.md).
String _loadErrorMessage(Object? error) {
  return switch (error) {
    DioException(error: AuthFailure()) =>
      'Your account is not allowed to review content. If it should be, '
          'ask an admin to add it to the Moderator group.',
    DioException(error: final ApiFailure failure) => failure.message,
    _ => 'Could not load the moderation queue.',
  };
}

class _QueueListView extends ConsumerWidget {
  const _QueueListView({required this.items, required this.onOpenItem});

  final List<QueueItem> items;
  final void Function(QueueItem item) onOpenItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _SummaryBar(items: items),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(moderationQueueProvider.notifier).refresh(),
            child: ListView.separated(
              // Always scrollable so pull-to-refresh works even when the
              // list is shorter than the screen.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return _QueueRow(item: item, onTap: () => onOpenItem(item));
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.items});

  final List<QueueItem> items;

  @override
  Widget build(BuildContext context) {
    final fastPathCount = items.where((item) => item.isFastPath).length;
    final text = fastPathCount == 0
        ? '${items.length} pending'
        : '${items.length} pending · $fastPathCount fast path';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          key: const ValueKey('queue-summary'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.item, required this.onTap});

  final QueueItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final previewText = item.previewText;
    final submitter = item.submitterBusinessName;
    final typeLine = submitter == null
        ? contentTypeLabel(item.contentType)
        : '${contentTypeLabel(item.contentType)} · $submitter';

    return Card(
      key: ValueKey('queue-row-${item.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QueuePreviewThumbnail(imageUrl: item.previewImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      previewText == null || previewText.isEmpty
                          ? 'No preview available'
                          : previewText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontStyle: previewText == null || previewText.isEmpty
                            ? FontStyle.italic
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(typeLine, style: textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        PriorityBadge(priority: item.priority),
                        QueueAgeChip(
                          priority: item.priority,
                          age: item.ageDuration,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}