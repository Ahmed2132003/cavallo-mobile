import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/route_names.dart';
import '../domain/own_story_entity.dart';
import 'own_stories_provider.dart';

/// Part P-083 scope: the Stories tab of the Business Console -- the
/// signed-in Business account's own Stories (current and recent, all
/// statuses), backed by `ownStoriesProvider`. Mirrors
/// `ProductListScreen`'s (Part P-033) `switch (asyncValue)` pattern and
/// its shared `ErrorStateWidget`/`EmptyStateWidget`/`LoadingIndicator`.
///
/// Owns its own `AppBar` (D1: the shell has none) and a "Create Story"
/// action that opens P-051's creation flow (`RouteNames.storyForm`)
/// untouched.
///
/// ### Status chip
///
/// Pending / Published / Rejected / Expired (/ Unknown for a wire value
/// this app version does not know). The backend has no `approved` or
/// `expired` status: see `own_story_entity.dart` for how the displayed
/// status is derived. Only a still-live `published` story shows a
/// remaining-time label. That label is computed at build time and is not
/// ticking; a pull-to-refresh or any rebuild updates it.
///
/// ### Rejection reason
///
/// The deck says a rejected item always shows its rejection reason. The
/// Story backend does not return one today (documented gap), so the
/// reason line is shown only when `OwnStory.rejectionReason` is non-null
/// and nothing is invented otherwise.
class StoryListScreen extends ConsumerWidget {
  const StoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(ownStoriesProvider);
    final now = ref.watch(storyListClockProvider)();

    return Scaffold(
      appBar: AppBar(title: const Text('Stories')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('story-list-create-button'),
        onPressed: () {
          context.pushNamed(RouteNames.storyForm);
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Story'),
      ),
      body: switch (storiesAsync) {
        AsyncData(value: final stories) when stories.isEmpty =>
          const _EmptyView(),
        AsyncData(value: final stories) => _StoryListView(
          stories: stories,
          now: now,
        ),
        AsyncError(:final error) => _LoadErrorView(error: error),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// The clock `StoryListScreen` uses to derive "Expired" and the remaining
/// time. A provider only so tests can pin it; production always gets the
/// real [DateTime.now].
final storyListClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Same two failure shapes as `ProductListScreen`: a `DioException` whose
/// `.error` is the typed [ApiFailure] (production, `ErrorInterceptor`),
/// or a bare [ApiFailure].
String _apiFailureMessage(Object error, {required String fallback}) {
  return switch (error) {
    DioException(error: final ApiFailure failure) => failure.message,
    ApiFailure(:final message) => message,
    _ => fallback,
  };
}

class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      key: const Key('story-list-error'),
      message: _apiFailureMessage(
        error,
        fallback: 'Could not load your stories.',
      ),
      onRetry: () => ref.read(ownStoriesProvider.notifier).refresh(),
    );
  }
}

/// A business that never posted a Story: a valid, expected state. Still
/// pull-to-refreshable, which is why it lives inside a scrollable.
class _EmptyView extends ConsumerWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(ownStoriesProvider.notifier).refresh(),
      child: LayoutBuilder(
        builder:
            (context, constraints) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  child: const EmptyStateWidget(
                    key: Key('story-list-empty'),
                    message:
                        'No stories yet.\nTap "Create Story" to share your first '
                        'one.',
                    icon: Icons.auto_stories_outlined,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _StoryListView extends ConsumerWidget {
  const _StoryListView({required this.stories, required this.now});

  final List<OwnStory> stories;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(ownStoriesProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        // Bottom padding keeps the last row clear of the extended FAB.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: stories.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder:
            (context, index) => _StoryListItem(story: stories[index], now: now),
      ),
    );
  }
}

class _StoryListItem extends StatelessWidget {
  const _StoryListItem({required this.story, required this.now});

  final OwnStory story;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayStatus = story.displayStatus(now);
    final remaining = story.remaining(now);
    final reason = story.rejectionReason;

    return Card(
      key: Key('story-list-item-${story.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _StoryThumbnail(mediaUrl: story.mediaUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Story #${story.id}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  _StatusChip(
                    key: Key('story-status-${story.id}'),
                    status: displayStatus,
                  ),
                  if (remaining != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatRemaining(remaining),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (displayStatus == OwnStoryDisplayStatus.rejected &&
                      reason != null) ...[
                    const SizedBox(height: 6),
                    Text('Reason: $reason', style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRemaining(Duration remaining) {
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  if (hours >= 1) return '${hours}h ${minutes}m left';
  if (minutes >= 1) return '${minutes}m left';
  return 'Less than 1m left';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({super.key, required this.status});

  final OwnStoryDisplayStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, background, foreground) = switch (status) {
      OwnStoryDisplayStatus.published => (
        'Published',
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      OwnStoryDisplayStatus.pending => (
        'Pending',
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      OwnStoryDisplayStatus.rejected => (
        'Rejected',
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      OwnStoryDisplayStatus.expired => (
        'Expired',
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      OwnStoryDisplayStatus.unknown => (
        'Unknown',
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: foreground),
      backgroundColor: background,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

bool _isVideoUrl(String url) {
  final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
  return path.endsWith('.mp4') ||
      path.endsWith('.mov') ||
      path.endsWith('.webm');
}

/// A Story's media: the real network image for photos, a video icon for
/// videos (the backend generates no video thumbnail).
class _StoryThumbnail extends StatelessWidget {
  const _StoryThumbnail({required this.mediaUrl});

  final String mediaUrl;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    final placeholderColor =
        Theme.of(context).colorScheme.surfaceContainerHighest;

    if (_isVideoUrl(mediaUrl)) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: placeholderColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.videocam_outlined),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        mediaUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) => Container(
              width: size,
              height: size,
              color: placeholderColor,
              child: const Icon(Icons.broken_image_outlined),
            ),
      ),
    );
  }
}
